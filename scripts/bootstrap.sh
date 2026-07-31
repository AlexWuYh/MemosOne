#!/usr/bin/env bash
# Bootstrap local dev once Flutter is installed.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK not found. Install from https://docs.flutter.dev/get-started/install"
  exit 1
fi

if [[ ! -d android && ! -d macos && ! -d windows ]]; then
  echo "Generating platform runners..."
  flutter create . --project-name memos_one --platforms=windows,macos,android
fi

flutter pub get
flutter analyze
flutter test
echo "Bootstrap OK."
