#!/bin/bash
# Demo mode launcher for Ovlo (iOS and watchOS)
# Builds and runs the app in Simulator with selected demo mode

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Platform selection
echo "=== Ovlo Demo Mode Launcher ==="
echo ""
echo "Select platform:"
echo ""
echo "  1) iPhone (iOS)"
echo "  2) Apple Watch (watchOS)"
echo ""
read -p "Enter choice [1-2]: " platform_choice

case "$platform_choice" in
    1)
        PLATFORM="ios"
        SCHEME="OvloPhone"
        BUNDLE_ID="com.eddmann.Ovlo"
        SIMULATOR_NAME="iPhone 17 Pro"
        APP_NAME="OvloPhone.app"
        MODES=(
            "startView|Session selection screen"
            "breathingActive|Breathing session mid-inhale"
            "breathingAffirmation|Breathing with affirmation visible"
            "ambientActive|Ambient music session in progress"
            "guidedActive|Guided meditation session in progress"
        )
        ;;
    2)
        PLATFORM="watchos"
        SCHEME="OvloWatch"
        BUNDLE_ID="com.eddmann.Ovlo.watchkitapp"
        SIMULATOR_NAME="Apple Watch Series 11 (42mm)"
        APP_NAME="OvloWatch.app"
        MODES=(
            "startView|Session selection screen"
            "breathingActive|Breathing session mid-inhale"
        )
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "Select a demo mode:"
echo ""

for i in "${!MODES[@]}"; do
    mode="${MODES[$i]%%|*}"
    desc="${MODES[$i]#*|}"
    printf "  %d) %-22s - %s\n" $((i+1)) "$mode" "$desc"
done

echo ""
read -p "Enter choice [1-${#MODES[@]}]: " choice

if [[ ! "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt ${#MODES[@]} ]; then
    echo "Invalid choice"
    exit 1
fi

SELECTED="${MODES[$((choice-1))]}"
SELECTED_MODE="${SELECTED%%|*}"
echo ""
echo "Selected: $SELECTED_MODE"
echo ""

# Get simulator UDID
UDID=$(xcrun simctl list devices available | grep "$SIMULATOR_NAME" | grep -oE '[A-F0-9-]{36}' | head -1)

if [ -z "$UDID" ]; then
    echo "Error: Could not find simulator '$SIMULATOR_NAME'"
    exit 1
fi

echo "Using simulator: $SIMULATOR_NAME ($UDID)"

# Boot simulator if needed
echo "Booting simulator..."
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator

# Build the app
echo "Building $SCHEME..."
BUILD_DIR="$PROJECT_DIR/.build"
xcodebuild -project "$PROJECT_DIR/Ovlo.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "id=$UDID" \
    -derivedDataPath "$BUILD_DIR" \
    build | xcbeautify 2>/dev/null || \
xcodebuild -project "$PROJECT_DIR/Ovlo.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "id=$UDID" \
    -derivedDataPath "$BUILD_DIR" \
    build 2>&1 | tail -20

# Find the built app
APP_PATH=$(find "$BUILD_DIR/Build/Products" -name "$APP_NAME" -type d 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find built app in $BUILD_DIR/Build/Products"
    find "$BUILD_DIR" -name "*.app" -type d 2>/dev/null || echo "No .app bundles found"
    exit 1
fi

echo "Found app: $APP_PATH"

# Uninstall previous version and install fresh
echo "Installing app..."
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP_PATH"

# Launch with demo argument
echo "Launching with --demo $SELECTED_MODE..."
xcrun simctl launch "$UDID" "$BUNDLE_ID" --demo "$SELECTED_MODE"

echo ""
echo "Done! App launched with demo mode: $SELECTED_MODE"
