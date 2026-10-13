#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <adb-device-id>" >&2
  exit 2
fi

# Flutter integration tests default to uninstalling the app at teardown.
# This project shares its application ID with the user's installed app.
# Always preserve the installation; take a learning-data backup beforehand.
flutter test integration_test/session_pacing_device_test.dart \
  -d "$1" --no-pub --no-uninstall
