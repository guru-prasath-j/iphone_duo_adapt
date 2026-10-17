import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iphone_duo_adapt/iphone_duo_adapt.dart';

// A typical phone-only mail app, retrofitted with small changes marked
// "iphone_duo_adapt". Remove them and it is the app you started with.
// `dart run iphone_duo_adapt:duo_migrate --apply` makes changes 2 and 3 for
// you.

void main() {
  runApp(
    // iphone_duo_adapt (1/3): preview every iPhone Duo state on a desktop.
    // Off on phones and in release builds.
    DuoPreview(
      enabled: kDebugMode &&
          defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.android,
      child: const MailApp(),
    ),
  );
}

class MailApp extends StatelessWidget {
  const MailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mail',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      // iphone_duo_adapt (2/3): one line makes the whole app fold-aware and
      // starts the native hinge bridge on iOS 27.1.
      builder: DuoAdapt.builder(
        config: const DuoAdaptConfig(
          moveAppBarActionsToRail: true,
          debugLog: kDebugMode,
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    // iphone_duo_adapt (3/3): wrap the existing Scaffold. The bottom bar
    // becomes a side rail when the phone is unfolded, and the search action
    // moves onto the rail.
    return DuoAdaptiveScaffold(
      scaffold: Scaffold(
        appBar: AppBar(
          title: Text(_tab == 0 ? 'Inbox' : 'Device'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search),
              onPressed: () {},
            ),
          ],
        ),
        body: _tab == 0 ? const Inbox() : const DeviceInfoPage(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.inbox), label: 'Inbox'),
            BottomNavigationBarItem(
              icon: Icon(Icons.devices_fold),
              label: 'Device',
            ),
          ],
        ),
      ),
    );
  }
}

class Inbox extends StatelessWidget {
  const Inbox({super.key});

  @override
  Widget build(BuildContext context) {
    // Pushes a detail page on the outer screen; shows list and message side
    // by side (either side of the fold) on the inner screen.
    return DuoListDetail<int>(
      emptyDetail: const Center(child: Text('Select a message')),
      listBuilder: (context, selected, onSelect) => ListView.builder(
        itemCount: 30,
        itemBuilder: (context, i) => ListTile(
          leading: CircleAvatar(child: Text('${i + 1}')),
          title: Text('Message ${i + 1}'),
          subtitle: const Text('Tap to read'),
          selected: selected == i,
          onTap: () => onSelect(i),
        ),
      ),
      detailBuilder: (context, i) => Stack(
        children: <Widget>[
          ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              Text(
                'Message ${i + 1}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              const Text(
                'On the inner display this pane sits beside the '
                'list. Bend the hinge and it moves clear of the fold.',
              ),
            ],
          ),
          // Keeps the reply button on one side of a bent fold.
          DuoFoldAvoid(
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FloatingActionButton.extended(
                  heroTag: 'reply-$i',
                  onPressed: () {},
                  icon: const Icon(Icons.reply),
                  label: const Text('Reply'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live readout of what the package sees. On a real iPhone Duo (iOS 27.1,
/// built with Xcode 27.1) the hinge angle and fold come from UIKit.
class DeviceInfoPage extends StatelessWidget {
  const DeviceInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DuoLayoutBuilder(
      builder: (context, info) => DuoHingeBuilder(
        builder: (context, hinge) => ValueListenableBuilder<DuoNativeState?>(
          valueListenable: DuoNativeBridge.instance.state,
          builder: (context, native, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              Text(
                '${info.posture.name} · ${info.widthClass.name} width',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Hinge: ${hinge?.state?.name ?? 'unknown'}'
                '${hinge?.angleDegrees == null ? '' : ' at ${hinge!.angleDegrees!.round()}°'}'
                ' (${hinge?.source.name ?? 'no source'})',
              ),
              Text(
                'Native bridge: ${native == null ? 'starting' : native.supported ? 'active' : 'not available here'}',
              ),
              const SizedBox(height: 16),
              SelectableText(
                const JsonEncoder.withIndent('  ').convert(info.toJson()),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
