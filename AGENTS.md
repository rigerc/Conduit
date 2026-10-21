# AGENTS.md

Conduit is a Flutter app (Android flavors `play` / `full`). Common tasks live in the `justfile` — run `just` to list them.

## Always send the debug APK after building one

Every time you build a debug APK, send it to the phone over KDE Connect in the same turn. This is part of "done", not an optional extra — do not wait to be asked.

- `just send-debug` (alias `just send`) — builds the `play` debug APK and shares it.
- `just share [path]` — shares an already-built APK; defaults to `build/app/outputs/flutter-apk/app-play-debug.apk`.
- `just build-debug-full` then `just share build/app/outputs/flutter-apk/app-full-debug.apk` for the `full` flavor.

Rules that follow from this:

1. Prefer `just send-debug` over `just build-debug` / `flutter build apk --debug`, so build and delivery cannot drift apart.
2. Targeted device: `just send-debug KDE_CONNECT_DEVICE="Pixel 9a"` (name or device id). Without it the first paired, reachable device is used.
3. Do not send when the build failed, when only release APKs were built, or when the user says not to send.
4. If sending fails (`kdeconnect-cli` missing, daemon down, no paired device), report the exact failure and the fix — do not silently drop the step.
5. Never hand-roll `kdeconnect-cli -d … --share …` invocations; the recipe handles daemon startup, discovery refresh, and device selection.

## Other conventions

- `just check` is the gate before calling work done: `flutter analyze` + `flutter test`.
- Do not run `just format` across the repo unless asked; the checked-in code predates the current `dart format` style and a blanket reformat touches unrelated files.
- `just build-release` requires `android/key.properties`; the file is absent in this checkout, so local release builds are unsigned.
- Do not commit build artifacts or `android/key.properties`.
