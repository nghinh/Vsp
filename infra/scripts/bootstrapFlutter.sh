#!/bin/bash
# bootstrapFlutter.sh — Flutter environment bootstrap
# Run from repository root: ./infra/scripts/bootstrapFlutter.sh
# Or from mobile dir: flutter pub get

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"
MOBILE_DIR="$REPO_ROOT/apps/mobile"

echo "=== Flutter Bootstrap ==="

# Check Flutter is installed
if ! command -v flutter &> /dev/null; then
  echo "❌ Flutter not found in PATH"
  echo "   Install Flutter SDK: https://docs.flutter.dev/get-started/install"
  exit 1
fi

FLUTTER_VERSION=$(flutter --version 2>/dev/null | head -n1 || echo "unknown")
echo "✓ Flutter: $FLUTTER_VERSION"

# Check SDK constraint
echo ""
echo "Checking Flutter SDK constraint in pubspec.yaml..."
if [[ -f "$MOBILE_DIR/pubspec.yaml" ]]; then
  SDK_CONSTRAINT=$(grep -E "^environment:" -A1 "$MOBILE_DIR/pubspec.yaml" | grep "sdk:" | tr -d ' ' || echo "")
  echo "  $SDK_CONSTRAINT"
else
  echo "  ⚠️  pubspec.yaml not found at $MOBILE_DIR"
fi

# Run flutter doctor
echo ""
echo "Running flutter doctor..."
if flutter doctor --verbose 2>&1 | tail -n5; then
  echo "✓ flutter doctor passed"
else
  echo "⚠️  flutter doctor reported issues — review above"
fi

# Install dependencies
echo ""
echo "Running flutter pub get in $MOBILE_DIR..."
cd "$MOBILE_DIR"
flutter pub get

echo ""
echo "=== Flutter Bootstrap Complete ==="
echo ""
echo "IDE Setup:"
echo "  - VS Code: install 'Flutter' extension, open $MOBILE_DIR"
echo "  - Android Studio / IntelliJ: install Flutter plugin, open $MOBILE_DIR"
echo "  - iOS (macOS): open $MOBILE_DIR/ios/Runner.xcworkspace in Xcode"
echo ""
echo "Run the app:"
echo "  cd $MOBILE_DIR && flutter run"
