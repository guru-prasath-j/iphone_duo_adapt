#import "./include/flutter_iphone_duo_adapt/IphoneDuoAdaptPlugin.h"

#import <UIKit/UIKit.h>

// The hinge and reserved-region APIs are declared by the iOS 27.1 SDK. Code
// inside IDA_HAS_HINGE_SDK is only compiled when building against that SDK or
// newer, so the plugin still builds with older Xcode versions. The same guard
// is used by the Flutter engine's own implementation (flutter/flutter#193025).
#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 270100
#define IDA_HAS_HINGE_SDK 1
#else
#define IDA_HAS_HINGE_SDK 0
#endif

// Raw values of UIHingeStatus, so the mapping compiles without the new SDK.
typedef NS_ENUM(NSInteger, IDAHingeStatus) {
  IDAHingeStatusUnknown = 0,
  IDAHingeStatusClosed = 1,
  IDAHingeStatusPartiallyOpen = 2,
  IDAHingeStatusFullyOpen = 3,
};

static BOOL IDASupported(void) {
#if IDA_HAS_HINGE_SDK
  if (@available(iOS 27.1, *)) {
    return YES;
  }
#endif
  return NO;
}

static NSString* IDAStatusName(IDAHingeStatus status) {
  switch (status) {
    case IDAHingeStatusClosed:
      return @"closed";
    case IDAHingeStatusPartiallyOpen:
      return @"partiallyOpen";
    case IDAHingeStatusFullyOpen:
      return @"fullyOpen";
    default:
      return @"unknown";
  }
}

static NSArray<NSNumber*>* IDARect(CGRect r) {
  return @[ @(CGRectGetMinX(r)), @(CGRectGetMinY(r)), @(CGRectGetMaxX(r)), @(CGRectGetMaxY(r)) ];
}

/// Invisible view laid over the Flutter view. It hosts the hinge interaction
/// and re-reads reserved regions during its own layout pass: UIKit has no
/// notification for reserved regions, but it re-runs layout for a view that
/// read them during layout when they change.
@interface IDAObserverView : UIView
@property(nonatomic, copy, nullable) void (^onLayout)(void);
@end

@implementation IDAObserverView

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.userInteractionEnabled = NO;
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.isAccessibilityElement = NO;
    self.accessibilityElementsHidden = YES;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  }
  return self;
}

- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
  return nil;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  void (^onLayout)(void) = self.onLayout;
  if (onLayout) {
    onLayout();
  }
}

@end

@interface IphoneDuoAdaptPlugin () <FlutterStreamHandler>
@property(nonatomic, weak) NSObject<FlutterPluginRegistrar>* registrar;
@property(nonatomic, copy, nullable) FlutterEventSink sink;
@property(nonatomic, strong, nullable) IDAObserverView* observer;
@property(nonatomic, strong, nullable) id hingeInteraction;
@property(nonatomic, assign) IDAHingeStatus status;
@property(nonatomic, assign) BOOL hasHinge;
@property(nonatomic, assign) double angle;
@property(nonatomic, copy, nullable) NSDictionary* lastPayload;
@property(nonatomic, assign) NSInteger attachAttempts;
@end

@implementation IphoneDuoAdaptPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  IphoneDuoAdaptPlugin* instance = [[IphoneDuoAdaptPlugin alloc] init];
  instance.registrar = registrar;
  FlutterMethodChannel* methods =
      [FlutterMethodChannel methodChannelWithName:@"iphone_duo_adapt"
                                  binaryMessenger:[registrar messenger]];
  [registrar addMethodCallDelegate:instance channel:methods];
  FlutterEventChannel* events =
      [FlutterEventChannel eventChannelWithName:@"iphone_duo_adapt/events"
                                binaryMessenger:[registrar messenger]];
  [events setStreamHandler:instance];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
  if ([call.method isEqualToString:@"getCapabilities"]) {
    result(@{
      @"supported" : @(IDASupported()),
      @"sdkHasHingeApis" : @(IDA_HAS_HINGE_SDK == 1),
    });
  } else if ([call.method isEqualToString:@"getState"]) {
    result(self.lastPayload ?: [self payload]);
  } else {
    result(FlutterMethodNotImplemented);
  }
}

#pragma mark - FlutterStreamHandler

- (FlutterError* _Nullable)onListenWithArguments:(id _Nullable)arguments
                                       eventSink:(FlutterEventSink)events {
  self.sink = events;
  self.attachAttempts = 0;
  [self attach];
  [self send];
  return nil;
}

- (FlutterError* _Nullable)onCancelWithArguments:(id _Nullable)arguments {
  self.sink = nil;
  [self detach];
  return nil;
}

#pragma mark - Observation

- (nullable UIView*)hostView {
  UIViewController* controller = self.registrar.viewController;
  if (controller.isViewLoaded && controller.view.window) {
    return controller.view;
  }
  for (UIScene* scene in UIApplication.sharedApplication.connectedScenes) {
    if (![scene isKindOfClass:[UIWindowScene class]]) {
      continue;
    }
    for (UIWindow* window in ((UIWindowScene*)scene).windows) {
      if (window.isKeyWindow && window.rootViewController.view) {
        return window.rootViewController.view;
      }
    }
  }
  return nil;
}

- (void)attach {
  if (self.observer || !IDASupported()) {
    return;
  }
  UIView* host = [self hostView];
  if (!host) {
    // The Flutter view may not be in a window yet; try again shortly.
    if (self.attachAttempts++ < 20) {
      __weak IphoneDuoAdaptPlugin* weakSelf = self;
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                     dispatch_get_main_queue(), ^{
                       [weakSelf attach];
                     });
    }
    return;
  }

  IDAObserverView* observer = [[IDAObserverView alloc] initWithFrame:host.bounds];
  __weak IphoneDuoAdaptPlugin* weakSelf = self;
  observer.onLayout = ^{
    [weakSelf send];
  };
  [host addSubview:observer];
  self.observer = observer;

#if IDA_HAS_HINGE_SDK
  if (@available(iOS 27.1, *)) {
    UIHingeInteraction* interaction = [[UIHingeInteraction alloc]
        initWithUpdateHandler:^(UIHingeInteraction* _Nonnull i, UIHingeInteractionUpdate* update) {
          IphoneDuoAdaptPlugin* strongSelf = weakSelf;
          if (!strongSelf) {
            return;
          }
          // A nil hinge means this device has none.
          UIHinge* hinge = update.hinge;
          strongSelf.hasHinge = hinge != nil;
          strongSelf.status = hinge ? (IDAHingeStatus)hinge.status : IDAHingeStatusUnknown;
          strongSelf.angle = hinge ? (double)hinge.angle : 0;
          [strongSelf send];
          // Regions lag the hinge; ask for a layout pass that re-reads them.
          [strongSelf.observer setNeedsLayout];
        }];
    [observer addInteraction:interaction];
    self.hingeInteraction = interaction;
  }
#endif
}

- (void)detach {
#if IDA_HAS_HINGE_SDK
  if (@available(iOS 27.1, *)) {
    if (self.hingeInteraction) {
      [self.observer removeInteraction:(UIHingeInteraction*)self.hingeInteraction];
    }
  }
#endif
  self.hingeInteraction = nil;
  [self.observer removeFromSuperview];
  self.observer = nil;
  self.lastPayload = nil;
}

- (NSDictionary*)payload {
  NSMutableArray* folds = [NSMutableArray array];
  NSMutableArray* occlusions = [NSMutableArray array];
#if IDA_HAS_HINGE_SDK
  if (@available(iOS 27.1, *)) {
    UIView* view = self.observer;
    if (view) {
      // Rules mirror flutter/flutter#193025: a division counts only while
      // the hinge reads partially open (isActive lags the hinge), and
      // zero-size regions are dropped.
      for (UIViewReservedRegion* region in
           [view reservedRegionsOfKind:[UIViewReservedRegionKind divisionRegionKind]
                               options:UIViewReservedRegionQueryOptionsIncludeInactive]) {
        CGRect f = region.frame;
        if (!region.isActive || self.status != IDAHingeStatusPartiallyOpen ||
            CGRectGetWidth(f) <= 0 || CGRectGetHeight(f) <= 0) {
          continue;
        }
        [folds addObject:IDARect(f)];
      }
      for (UIViewReservedRegion* region in
           [view reservedRegionsOfKind:[UIViewReservedRegionKind occlusionRegionKind]
                               options:UIViewReservedRegionQueryOptionsNone]) {
        CGRect f = region.frame;
        if (!region.isActive || CGRectGetWidth(f) <= 0 || CGRectGetHeight(f) <= 0) {
          continue;
        }
        [occlusions addObject:IDARect(f)];
      }
    }
  }
#endif
  return @{
    @"supported" : @(IDASupported()),
    @"hasHinge" : @(self.hasHinge),
    @"status" : self.hasHinge ? IDAStatusName(self.status) : [NSNull null],
    @"angle" : self.hasHinge ? @(self.angle) : [NSNull null],
    @"folds" : folds,
    @"occlusions" : occlusions,
  };
}

- (void)send {
  FlutterEventSink sink = self.sink;
  if (!sink) {
    return;
  }
  NSDictionary* payload = [self payload];
  if ([payload isEqualToDictionary:self.lastPayload ?: @{}]) {
    return;
  }
  self.lastPayload = payload;
  sink(payload);
}

@end
