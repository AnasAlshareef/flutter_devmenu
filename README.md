# flutter_devmenu

A tiny in-app dev menu for Flutter **debug builds**. Shake the device to open a
panel with three tabs:

- **Env** — switch API base URL (dev / staging / prod) at runtime.
- **Session** — see the current user, token, etc. with one-tap copy, and a
  force-logout button.
- **Logs** — recent log lines, with copy-all and clear.

Off in release builds by default, so it is safe to leave wired in.

## Install

```yaml
dependencies:
  flutter_devmenu:
    git: https://github.com/AnasAlshareef/flutter_devmenu.git
```

## Use

Wrap your app through `MaterialApp.builder`, and pass the **same**
`navigatorKey` to both `MaterialApp` and `DevMenu` so the panel has a Navigator:

```dart
import 'package:flutter_devmenu/flutter_devmenu.dart';

final navKey = GlobalKey<NavigatorState>();
final devMenuKey = GlobalKey<DevMenuState>();

MaterialApp(
  navigatorKey: navKey,
  builder: (context, child) => DevMenu(
    key: devMenuKey,
    navigatorKey: navKey,
    environments: const [
      DevEnv('dev', 'https://dev.api.example'),
      DevEnv('prod', 'https://api.example'),
    ],
    currentEnvName: currentEnv,                 // your persisted choice
    onEnvSelected: (env) => switchBaseUrl(env.baseUrl),
    session: () => {'user': userName, 'token': token},
    onLogout: logout,
    child: child!,
  ),
);
```

### Logs

Either push lines yourself:

```dart
DevMenuLog.instance.add('order $id created');
```

…or capture everything you already `debugPrint`, once at startup:

```dart
DevMenuLog.instance.captureDebugPrint();
```

### Opening on a simulator

A simulator has no accelerometer. Open the menu by:

- `devMenuKey.currentState?.open()` from a debug-only button, **or**
- a long-press on the thin strip at the top-center of the screen
  (`cornerHotspot`, on by default; set `cornerHotspot: false` to disable).

## Notes

- The app owns persistence — `onEnvSelected` is where you save the choice and
  swap your HTTP client's base URL. The menu only shows and selects.
- `session` is called each time the menu opens, so it always shows current
  values. Don't put anything there you wouldn't want on a dev's screen.
- Env switching changes the base URL for new requests; it does not re-run app
  startup. Re-fetch or restart if your app reads config only once.
