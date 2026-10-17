#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

/// Sends iPhone Duo hinge status, hinge angle, fold regions and camera
/// occlusions to Dart over the `iphone_duo_adapt/events` event channel.
///
/// Uses `UIHingeInteraction` and `-[UIView reservedRegionsOfKind:options:]`,
/// which ship in the iOS 27.1 SDK. Built with an older SDK, or running on an
/// older iOS, the plugin reports `supported: false` and does nothing else.
@interface IphoneDuoAdaptPlugin : NSObject <FlutterPlugin>
@end

NS_ASSUME_NONNULL_END
