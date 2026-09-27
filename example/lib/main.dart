import 'package:iphone_duo_adapt/iphone_duo_adapt.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// A typical phone-only mail app, retrofitted with three small changes, each
// marked "iphone_duo_adapt". Remove them and it is the app you started with.

void main() {
  runApp(
    // iphone_duo_adapt (1/3): preview all four iPhone Duo postures on any
    // machine.
    // Disabled on real phones and in release builds.
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
      // iphone_duo_adapt (2/3): one line makes the whole app fold-aware.
      builder: DuoAdapt.builder(),
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
    // iphone_duo_adapt (3/3): wrap the existing Scaffold. The bottom bar becomes a
    // side rail when the phone is unfolded.
    return DuoAdaptiveScaffold(
      scaffold: Scaffold(
        appBar: AppBar(title: Text(_tab == 0 ? 'Inbox' : 'Settings')),
        body: _tab == 0 ? const Inbox() : const Center(child: Text('Settings')),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i),
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.inbox), label: 'Inbox'),
            BottomNavigationBarItem(
                icon: Icon(Icons.settings), label: 'Settings'),
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
      detailBuilder: (context, i) => ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text('Message ${i + 1}',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          const Text('This pane sits on the right half of the inner display. '
              'Bend the hinge in the preview to see it move clear of the '
              'fold.'),
        ],
      ),
    );
  }
}
