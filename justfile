# Conduit — common Flutter/Android tasks.
#
#   just                  list recipes
#   just check            analyze + test (what CI gates on)
#   just send-debug       build debug APK and send it to your phone (KDE Connect)
#
# Override the KDE Connect target with KDE_CONNECT_DEVICE (name or id):
#   just send-debug KDE_CONNECT_DEVICE="Pixel 9a"
set shell := ["bash", "-uc"]

flavor      := "play"
apk_dir     := "build/app/outputs/flutter-apk"
debug_apk   := apk_dir / "app-" + flavor + "-debug.apk"
addon_debug := apk_dir / "app-full-debug.apk"
release_apk := apk_dir / "app-arm64-v8a-release.apk"

version := `sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -n 1`

# Default: list recipes.
default:
    @just --list

# ---------------------------------------------------------------- dependencies

# Resolve pub dependencies.
[group('setup')]
get:
    flutter pub get

# Report outdated dependencies.
[group('setup')]
outdated:
    flutter pub outdated

# Show Flutter toolchain status.
[group('setup')]
doctor:
    flutter doctor -v

# Delete build artifacts.
[group('setup')]
clean:
    flutter clean
    flutter pub get

# ------------------------------------------------------------ style & testing

# Format sources in place.
[group('lint')]
format:
    dart format lib test

# Fail if any source is not formatted (repo predates the dart 3.12 formatter).
[group('lint')]
format-check:
    dart format --output=none --set-exit-if-changed lib test

# Run the static analyzer.
[group('lint')]
analyze:
    flutter analyze

# Run all tests, or one file/test: `just test test/core` / `just test --plain-name foo`.
[group('test')]
test *args:
    flutter test {{args}}

# What CI gates on: analyze + test.
[group('test')]
check: analyze test

# --------------------------------------------------------------- run & build

# Run on a device: `just run` (first device) or `just run emulator-5554`.
[group('dev')]
run device="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -n "{{device}}" ]]; then
        exec flutter run -d "{{device}}"
    fi
    exec flutter run

# List connected devices.
[group('dev')]
devices:
    flutter devices

# Build the debug APK for the `play` flavor.
[group('build')]
build-debug: get
    flutter build apk --debug --flavor {{flavor}}
    @echo "APK: {{debug_apk}}"

# Build the debug APK for the `full` flavor (FULL_STORAGE_ACCESS build).
[group('build')]
build-debug-full: get
    flutter build apk --debug --flavor full
    @echo "APK: {{addon_debug}}"

# Build signed release APKs (needs android/key.properties).
[group('build')]
build-release: get
    flutter build apk --release --flavor full --split-per-abi
    @echo "APKs in {{apk_dir}}"

# Rebuild the bundled local-shell native payload (slow; needs NDK or Docker).
[group('build')]
native-binaries *args:
    tools/build-local-shell-binaries.sh {{args}}

# ------------------------------------------------------------------- deploy

# Install the debug APK over adb.
[group('deploy')]
install-debug apk=debug_apk:
    adb install -r -d "{{apk}}"

# Uninstall the debug build (applicationIdSuffix `.debug`).
[group('deploy')]
uninstall-debug:
    adb uninstall com.gwitko.conduit.debug || true

# Share an APK (default: play debug) to your phone over KDE Connect.
[group('deploy')]
share apk=debug_apk:
    #!/usr/bin/env bash
    set -euo pipefail

    apk="{{apk}}"
    [[ -f "$apk" ]] || { echo "APK not found: $apk (run: just build-debug)" >&2; exit 1; }
    apk="$(realpath "$apk")"

    command -v kdeconnect-cli >/dev/null 2>&1 || {
        echo "kdeconnect-cli not found (install kdeconnect)." >&2; exit 1
    }

    if ! pgrep -x kdeconnectd >/dev/null 2>&1; then
        echo "kdeconnectd not running; starting it…"
        nohup kdeconnectd >/dev/null 2>&1 &
        sleep 1
    fi

    available="$(kdeconnect-cli -a --id-only 2>/dev/null || true)"
    if [[ -z "$available" ]]; then
        echo "No paired & reachable device; refreshing discovery…"
        kdeconnect-cli --refresh >/dev/null 2>&1 || true
        sleep 3
        available="$(kdeconnect-cli -a --id-only 2>/dev/null || true)"
    fi
    if [[ -z "$available" ]]; then
        echo "No paired & reachable KDE Connect device." >&2
        echo "Open KDE Connect on the phone, same Wi-Fi, then: just kde-devices" >&2
        exit 1
    fi

    target="${KDE_CONNECT_DEVICE:-}"
    if [[ -z "$target" ]]; then
        # First available device.
        args=(-d "$(head -n1 <<<"$available")")
    elif [[ "$target" =~ ^[0-9a-fA-F]{8,}$ ]]; then
        args=(-d "$target")
    else
        args=(-n "$target")
    fi

    echo "Sending $(basename "$apk") ($(du -h "$apk" | cut -f1)) via KDE Connect…"
    kdeconnect-cli "${args[@]}" --share "$apk"

# Build the debug APK and send it to your phone over KDE Connect.
[group('deploy')]
send-debug: build-debug
    @just share "{{debug_apk}}"

# List KDE Connect devices; `just kde-devices --refresh` rescans the network.
[group('deploy')]
kde-devices *args:
    #!/usr/bin/env bash
    set -euo pipefail
    for arg in {{args}}; do
        [[ "$arg" == "--refresh" ]] && kdeconnect-cli --refresh >/dev/null 2>&1 || true
    done
    kdeconnect-cli -l

# Alias for send-debug.
alias send := send-debug

# ---------------------------------------------------------------------- misc

# Print the pubspec version (name+code).
[group('misc')]
version-info:
    @echo "{{version}}"

# Run the release workflow locally in Docker via act.
[group('misc')]
act *args:
    act -W .github/workflows/release.yml {{args}}
