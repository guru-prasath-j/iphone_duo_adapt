import 'package:flutter/material.dart';

import 'device_spec.dart';
import 'duo_adapt_widget.dart';
import 'layout_info.dart';

/// Runs your app inside a simulated iPhone Duo so you can flip between the
/// four postures and the hinge states on any machine: desktop, web, an
/// Android emulator, or an older iPhone simulator.
///
/// ```dart
/// void main() => runApp(DuoPreview(child: const MyApp()));
/// ```
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
    this.spec = DuoDeviceSpec.iPhoneDuo,
    this.initialPosture = DuoPosture.openWide,
    this.initialHinge = DuoHingeState.halfOpened,
    this.showFoldOverlay = true,
  });

  /// The app to preview.
  final Widget child;

  /// When `false`, [child] is returned as is. Pass `kDebugMode` to keep the
  /// preview out of release builds.
  final bool enabled;

  /// Device geometry.
  final DuoDeviceSpec spec;

  /// Posture shown first.
  final DuoPosture initialPosture;

  /// Hinge state shown first for open postures.
  final DuoHingeState initialHinge;

  /// Draw the fold on top of the app.
  final bool showFoldOverlay;

  @override
  State<DuoPreview> createState() => _DuoPreviewState();
}

class _DuoPreviewState extends State<DuoPreview> {
  late DuoPosture _posture = widget.initialPosture;
  late DuoHingeState _hinge = widget.initialHinge;

  // Keeps the previewed app's state across posture switches.
  final GlobalKey _appKey = GlobalKey();

  bool get _open =>
      _posture == DuoPosture.openWide || _posture == DuoPosture.openTall;

  static const Map<DuoPosture, String> _postureLabels = <DuoPosture, String>{
    DuoPosture.closedPortrait: 'Closed',
    DuoPosture.closedLandscape: 'Closed, sideways',
    DuoPosture.openTall: 'Open, tall',
    DuoPosture.openWide: 'Open, wide',
  };

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
    final hinge = _open ? _hinge : DuoHingeState.closed;
    final base = MediaQuery.of(context);
    final data = widget.spec.mediaQueryFor(base, _posture, hinge);
    return Scaffold(
      backgroundColor: const Color(0xFF1E1F22),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _controls(context),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: FittedBox(
                    child: _device(data),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${widget.spec.name} · ${data.size.width.toInt()}×'
                '${data.size.height.toInt()} pt · '
                '${DuoLayoutInfo.fromMediaQuery(data)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: <Widget>[
          for (final p in DuoPosture.values)
            ChoiceChip(
              label: Text(_postureLabels[p]!),
              selected: _posture == p,
              onSelected: (_) => setState(() => _posture = p),
            ),
          const SizedBox(width: 16),
          for (final h in <DuoHingeState>[
            DuoHingeState.halfOpened,
            DuoHingeState.flat,
          ])
            ChoiceChip(
              label: Text(h == DuoHingeState.halfOpened ? 'Bent' : 'Flat'),
              selected: _open && _hinge == h,
              onSelected: _open ? (_) => setState(() => _hinge = h) : null,
            ),
        ],
      ),
    );
  }

  Widget _device(MediaQueryData data) {
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
              child: DuoScreenRoot(
                child: Stack(
                  textDirection: TextDirection.ltr,
                  children: <Widget>[
                    Positioned.fill(
                      child: KeyedSubtree(key: _appKey, child: widget.child),
                    ),
                    if (widget.showFoldOverlay)
                      const Positioned.fill(
                        child: IgnorePointer(child: DuoFoldOverlay()),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
