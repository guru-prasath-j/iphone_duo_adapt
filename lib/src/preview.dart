import 'dart:convert';

import 'package:flutter/material.dart';

import 'config.dart';
import 'device_spec.dart';
import 'duo_adapt_widget.dart';
import 'layout_info.dart';

/// Runs your app inside a simulated iPhone Duo so you can try every state on
/// any machine: desktop, web, an Android emulator or an older iPhone
/// simulator.
///
/// ```dart
/// void main() => runApp(DuoPreview(enabled: kDebugMode, child: const MyApp()));
/// ```
///
/// Controls: the four postures, the hinge angle (the fold appears while the
/// device is bent), Split View (the app on half the inner display), text
/// size, fold overlay, and a panel showing the live `DuoLayoutInfo` as JSON.
///
/// Your app's own `MaterialApp` goes inside unchanged. Flutter's app widgets
/// read the screen from the nearest `MediaQuery`, which the preview
/// overrides with the simulated size, safe areas and fold.
class DuoPreview extends StatefulWidget {
  /// Creates the preview.
  const DuoPreview({
    super.key,
    required this.child,
    this.enabled = true,
    this.spec,
    this.config = const DuoAdaptConfig(useNativeBridge: false),
    this.initialPosture = DuoPosture.openWide,
    this.initialAngle = 110,
    this.showFoldOverlay = true,
    this.showInfo = false,
  });

  /// The app to preview.
  final Widget child;

  /// When `false`, [child] is returned as is. Pass `kDebugMode` to keep the
  /// preview out of release builds.
  final bool enabled;

  /// Device geometry. Defaults to `config.deviceSpec`.
  final DuoDeviceSpec? spec;

  /// Config shared with the previewed app.
  final DuoAdaptConfig config;

  /// Posture shown first.
  final DuoPosture initialPosture;

  /// Hinge angle (degrees) shown first for open postures.
  final double initialAngle;

  /// Draw the fold on top of the app.
  final bool showFoldOverlay;

  /// Show the layout info panel at start.
  final bool showInfo;

  @override
  State<DuoPreview> createState() => _DuoPreviewState();
}

class _DuoPreviewState extends State<DuoPreview> {
  late DuoPosture _posture = widget.initialPosture;
  late double _angle = widget.initialAngle;
  late bool _overlay = widget.showFoldOverlay;
  late bool _info = widget.showInfo;
  bool _splitView = false;
  double _textScale = 1;

  // Keeps the previewed app's state across posture switches.
  final GlobalKey _appKey = GlobalKey(debugLabel: 'DuoPreview.app');

  DuoDeviceSpec get _spec => widget.spec ?? widget.config.deviceSpec;

  bool get _open =>
      _posture == DuoPosture.openWide || _posture == DuoPosture.openTall;

  static const Map<DuoPosture, String> _labels = <DuoPosture, String>{
    DuoPosture.closedPortrait: 'Closed',
    DuoPosture.closedLandscape: 'Closed, sideways',
    DuoPosture.openTall: 'Open, tall',
    DuoPosture.openWide: 'Open, wide',
  };

  DuoHingeReading get _hinge => _open
      ? DuoHingeReading.fromAngle(_angle.clamp(10, 180))
      : const DuoHingeReading(state: DuoHingeState.closed, angleDegrees: 0);

  MediaQueryData _data(MediaQueryData base) {
    final hinge = _hinge;
    var data = _spec.mediaQueryFor(base, _posture, hinge.state!);
    if (_splitView && _open) {
      // The app gets the leading half of the inner display, beside another
      // app. No fold runs through it.
      final full = data.size;
      final half = _posture == DuoPosture.openWide
          ? Size(full.width / 2 - 4, full.height)
          : Size(full.width, full.height / 2 - 4);
      data = data.copyWith(
        size: half,
        displayFeatures: const [],
        padding: data.padding.copyWith(right: 0),
        viewPadding: data.viewPadding.copyWith(right: 0),
      );
    }
    return data.copyWith(textScaler: TextScaler.linear(_textScale));
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blueGrey),
      home: Builder(builder: _buildFrame),
    );
  }

  Widget _buildFrame(BuildContext context) {
    final data = _data(MediaQuery.of(context));
    final hinge = _hinge;
    final info = DuoLayoutInfo.fromMediaQuery(
      data,
      config: widget.config,
      hinge: hinge,
    );
    return Scaffold(
      backgroundColor: const Color(0xFF1E1F22),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _controls(),
            Expanded(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: FittedBox(child: _device(data, hinge)),
                      ),
                    ),
                  ),
                  if (_info)
                    SizedBox(
                      width: 300,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          const JsonEncoder.withIndent(
                            '  ',
                          ).convert(info.toJson()),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${_spec.name} · ${data.size.width.toInt()}×'
                '${data.size.height.toInt()} pt · ${info.posture.name} · '
                '${info.widthClass.name} width · ${info.foldPose.name}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls() {
    Widget chip(String label, bool selected, VoidCallback? onTap) => FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: onTap == null ? null : (_) => onTap(),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          for (final p in DuoPosture.values)
            ChoiceChip(
              label: Text(_labels[p]!),
              selected: _posture == p,
              onSelected: (_) => setState(() => _posture = p),
            ),
          SizedBox(
            width: 220,
            child: Row(
              children: <Widget>[
                const Text('Hinge', style: TextStyle(color: Colors.white70)),
                Expanded(
                  child: Slider(
                    value: _angle.clamp(10, 180),
                    min: 10,
                    max: 180,
                    label: '${_angle.round()}°',
                    divisions: 34,
                    onChanged: _open ? (v) => setState(() => _angle = v) : null,
                  ),
                ),
                Text(
                  '${_angle.round()}°',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          chip(
            'Flat',
            _open && _angle >= 170,
            _open ? () => setState(() => _angle = 180) : null,
          ),
          chip(
            'Bent',
            _open && _angle < 170,
            _open ? () => setState(() => _angle = 110) : null,
          ),
          chip(
            'Split View',
            _splitView && _open,
            _open ? () => setState(() => _splitView = !_splitView) : null,
          ),
          chip(
            'Text ${_textScale == 1 ? '1x' : '${_textScale}x'}',
            _textScale != 1,
            () {
              setState(
                () => _textScale = _textScale == 1
                    ? 1.3
                    : _textScale == 1.3
                        ? 2
                        : 1,
              );
            },
          ),
          chip(
            'Fold overlay',
            _overlay,
            () => setState(() => _overlay = !_overlay),
          ),
          chip('Info', _info, () => setState(() => _info = !_info)),
        ],
      ),
    );
  }

  Widget _device(MediaQueryData data, DuoHingeReading hinge) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: SizedBox.fromSize(
            size: data.size,
            child: MediaQuery(
              data: data,
              child: DuoAdapt(
                config: widget.config,
                hinge: hinge,
                showFoldOverlay: _overlay,
                child: KeyedSubtree(key: _appKey, child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
