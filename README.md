# MouseTouch

MouseTouch is a native macOS menu bar app that turns extra mouse-button drags into macOS `Control` + arrow-key shortcuts. It is intended for mouse users who want trackpad-like directional gestures for switching Spaces or triggering the Mission Control shortcuts configured on their Mac.

The app runs as an accessory menu bar item labeled `MG` and does not show a Dock icon.

## Features

- Menu bar controls for opening settings, starting or stopping monitoring, toggling launch at login, and quitting the app.
- Accessibility permission flow with a direct shortcut to macOS Privacy & Security settings.
- Global and local monitoring for extra mouse button press, drag, and release events.
- Configurable trigger mouse button, clamped to button numbers `2...31`.
- Configurable activation distance, clamped to `40...400` px.
- Direction detection for left, right, up, and down drags, with diagonal drags ignored.
- Space shortcut dispatch through System Events first, with a direct `CGEvent` keyboard fallback.
- Automatic startup options for monitoring on app launch and opening the app at login.
- Detailed settings mode with live drag status, last gesture, and an in-app test log.
- Persistent settings through `UserDefaults`.

## Default Behavior

- Trigger button: `2`
- Activation distance: `140` px
- Monitoring on launch: enabled
- Open at login: enabled
- Detailed settings: disabled

When a gesture is accepted, Mouse Gesture sends the matching shortcut:

| Drag direction | Shortcut sent |
| --- | --- |
| Left | `Control` + Left Arrow |
| Right | `Control` + Right Arrow |
| Up | `Control` + Up Arrow |
| Down | `Control` + Down Arrow |

macOS decides what those shortcuts do. For Space switching, make sure the relevant Mission Control shortcuts are enabled in System Settings.

## Requirements

- macOS with Accessibility permissions available.
- Xcode for building from source.
- The Xcode project is currently configured with a macOS `26.4` deployment target and Swift `5.0`.

## Setup

1. Open `mouseGesture/mouseGesture.xcodeproj` in Xcode.
2. Build and run the `mouseGesture` scheme.
3. Click the `MG` menu bar item and open `Settings`.
4. Grant Accessibility permission when prompted, or use `Open Settings` to open the macOS permission pane.
5. Enable monitoring from the settings window or menu bar item.

If gestures do not switch Spaces, check macOS keyboard shortcuts under System Settings and confirm that `Control` + arrow shortcuts are assigned to the actions you expect.

## Build From Terminal

```sh
xcodebuild -project mouseGesture/mouseGesture.xcodeproj -scheme mouseGesture -configuration Release build
```

The built app is produced under Xcode's build products directory. This repository also contains the Xcode project, Swift sources, and app asset catalog under `mouseGesture/`.

## Project Structure

```text
mouseGesture/
  mouseGesture.xcodeproj/       Xcode project
  mouseGesture/
    mouseGestureApp.swift       menu bar app entry point
    ContentView.swift           settings UI
    MouseGestureController.swift gesture monitoring, permissions, settings, login item
    MouseGestureSettings.swift  persisted settings and defaults
    SpaceSwitcher.swift         System Events and CGEvent shortcut dispatch
    Info.plist                  app metadata and privacy descriptions
```

## Permissions

Mouse Gesture needs Accessibility permission because it monitors mouse events and sends keyboard shortcuts. It may also use System Events to send the shortcuts; if that path fails, it falls back to posting keyboard events directly.

## License

Apache License 2.0. See `LICENSE` for details.
