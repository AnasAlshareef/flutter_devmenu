import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'dev_env.dart';
import 'dev_log.dart';

/// Wraps your app and opens an in-app dev menu when the device is shaken.
///
/// Put it in `MaterialApp.builder`, and pass the same [navigatorKey] you give
/// `MaterialApp`, so the panel has a Navigator to open in:
///
/// ```dart
/// final navKey = GlobalKey<NavigatorState>();
/// final devMenuKey = GlobalKey<DevMenuState>();
///
/// MaterialApp(
///   navigatorKey: navKey,
///   builder: (context, child) => DevMenu(
///     key: devMenuKey,
///     navigatorKey: navKey,
///     environments: const [DevEnv('dev', 'https://dev.api'), DevEnv('prod', 'https://api')],
///     currentEnvName: 'dev',
///     onEnvSelected: (env) => switchApiBaseUrl(env.baseUrl),
///     session: () => {'user': currentUser, 'token': token},
///     onLogout: logout,
///     child: child!,
///   ),
/// );
/// ```
///
/// On a simulator (no accelerometer) open it with
/// `devMenuKey.currentState?.open()`, a debug-only button, or the corner
/// long-press (see [cornerHotspot]).
class DevMenu extends StatefulWidget {
  const DevMenu({
    super.key,
    required this.child,
    required this.navigatorKey,
    this.environments = const [],
    this.currentEnvName,
    this.onEnvSelected,
    this.session,
    this.onLogout,
    this.enabled = !kReleaseMode,
    this.shakeGForce = 2.7,
    this.cornerHotspot = true,
  });

  final Widget child;

  /// The same key passed to `MaterialApp.navigatorKey`. The menu opens in that
  /// Navigator's overlay, which sits below the Navigator so the sheet and the
  /// copy snackbar both resolve.
  final GlobalKey<NavigatorState> navigatorKey;

  final List<DevEnv> environments;
  final String? currentEnvName;
  final ValueChanged<DevEnv>? onEnvSelected;

  /// Called when the menu opens; return the session values to show (user,
  /// token, anything). Returning a fresh map each time keeps it current.
  final Map<String, String> Function()? session;
  final VoidCallback? onLogout;

  /// Off in release builds by default, so it is safe to leave wired in.
  final bool enabled;

  /// Shake sensitivity as a multiple of gravity; lower = easier to trigger.
  final double shakeGForce;

  /// A small invisible long-press target at top-center for simulators.
  final bool cornerHotspot;

  @override
  State<DevMenu> createState() => DevMenuState();
}

class DevMenuState extends State<DevMenu> {
  StreamSubscription<AccelerometerEvent>? _sub;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);
  bool _open = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      // Guard the sensor: unavailable on some platforms (e.g. web, desktop).
      try {
        _sub = accelerometerEventStream().listen(
          _onAccel,
          onError: (_) {},
        );
      } on Object {
        // No accelerometer — the hotspot / open() still work.
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onAccel(AccelerometerEvent e) {
    final gForce = sqrt(e.x * e.x + e.y * e.y + e.z * e.z) / 9.80665;
    if (gForce < widget.shakeGForce) return;
    final now = DateTime.now();
    // Debounce: one shake can fire many samples.
    if (now.difference(_lastShake) < const Duration(seconds: 1)) return;
    _lastShake = now;
    open();
  }

  /// Opens the dev menu. Safe to call from anywhere via a [GlobalKey].
  void open() {
    if (_open || !mounted) return;
    // The Navigator's own overlay is below the Navigator, so showModalBottomSheet
    // and ScaffoldMessenger both find their ancestors from here.
    final ctx = widget.navigatorKey.currentState?.overlay?.context;
    if (ctx == null) {
      assert(
        false,
        'DevMenu: navigatorKey has no Navigator yet — pass the same key you '
        'gave MaterialApp.navigatorKey.',
      );
      return;
    }
    _open = true;
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      builder: (_) => _DevPanel(config: widget),
    ).whenComplete(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    if (!widget.cornerHotspot) return widget.child;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Align(
            alignment: Alignment.topCenter,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPress: open,
              child: const SizedBox(width: 80, height: 24),
            ),
          ),
        ),
      ],
    );
  }
}

class _DevPanel extends StatelessWidget {
  const _DevPanel({required this.config});

  final DevMenu config;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const TabBar(
              tabs: [
                Tab(text: 'Env'),
                Tab(text: 'Session'),
                Tab(text: 'Logs'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _EnvTab(config: config),
                  _SessionTab(config: config),
                  const _LogsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnvTab extends StatelessWidget {
  const _EnvTab({required this.config});

  final DevMenu config;

  @override
  Widget build(BuildContext context) {
    if (config.environments.isEmpty) {
      return const _Empty('No environments passed to DevMenu.');
    }
    return RadioGroup<String>(
      groupValue: config.currentEnvName,
      onChanged: (name) {
        if (name == null) return;
        final env = config.environments.firstWhere((e) => e.name == name);
        config.onEnvSelected?.call(env);
        Navigator.of(context).pop();
      },
      child: ListView(
        children: [
          for (final env in config.environments)
            RadioListTile<String>(
              value: env.name,
              title: Text(env.name),
              subtitle: Text(env.baseUrl),
            ),
        ],
      ),
    );
  }
}

class _SessionTab extends StatelessWidget {
  const _SessionTab({required this.config});

  final DevMenu config;

  @override
  Widget build(BuildContext context) {
    final values = config.session?.call() ?? const {};
    return ListView(
      children: [
        if (values.isEmpty)
          const _Empty('No session data passed to DevMenu.')
        else
          for (final entry in values.entries)
            ListTile(
              title: Text(entry.key),
              subtitle: Text(entry.value),
              trailing: IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copy',
                onPressed: () => _copy(context, entry.value),
              ),
            ),
        if (config.onLogout != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.logout),
              label: const Text('Force logout'),
              onPressed: () {
                config.onLogout!();
                Navigator.of(context).pop();
              },
            ),
          ),
      ],
    );
  }
}

class _LogsTab extends StatelessWidget {
  const _LogsTab();

  @override
  Widget build(BuildContext context) {
    final log = DevMenuLog.instance;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.copy_all, size: 20),
              tooltip: 'Copy all',
              onPressed: () => _copy(
                context,
                log.entries.map((e) => e.message).join('\n'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: 'Clear',
              onPressed: log.clear,
            ),
          ],
        ),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: log.revision,
            builder: (context, _, __) {
              final entries = log.entries;
              if (entries.isEmpty) {
                return const _Empty('No logs captured yet.');
              }
              return ListView.builder(
                reverse: true,
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  // reverse: newest at the bottom-anchored top.
                  final e = entries[entries.length - 1 - i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Text(
                      e.message,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}

void _copy(BuildContext context, String value) {
  Clipboard.setData(ClipboardData(text: value));
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
  );
}
