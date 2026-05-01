#!/bin/bash
# Launch a build with automatic failure recovery monitoring.
#
# Usage:
#   ./run-build-with-recovery.sh [target] [--fetchers N]
#
# Examples:
#   ./run-build-with-recovery.sh
#   ./run-build-with-recovery.sh oci/aurora.bst
#   ./run-build-with-recovery.sh kde-build-meta.bst:kde/plasma/plasma-workspace.bst --fetchers 32

set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="${BST_LOG:-/var/tmp/aurora-build.log}"
DASHBOARD_PORT="${BST_DASHBOARD_PORT:-8765}"
TARGET="${1:-oci/aurora.bst}"

# Shift if target was provided
if [[ "$1" != --* ]]; then
    shift
fi

# Remaining args to pass through to just bst-build
BUILD_ARGS="$@"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Aurora KDE Linux Build with Automatic Failure Recovery"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Configuration:"
echo "  Project:    $PROJECT_DIR"
echo "  Target:     $TARGET"
echo "  Log:        $LOG_FILE"
echo "  Dashboard:  http://localhost:$DASHBOARD_PORT"
echo "  Build args: $BUILD_ARGS"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "Cleaning up..."
    pkill -f "bst-failure-recovery.py" || true
    pkill -f "bst-dashboard.py" || true
    pkill -f "bst build" || true
    wait || true
    echo "Done."
}

trap cleanup EXIT INT TERM

# Start dashboard in background
echo "[1/3] Starting dashboard..."
python3 "$PROJECT_DIR/bst-dashboard.py" \
    --log "$LOG_FILE" \
    --port "$DASHBOARD_PORT" \
    --target "$TARGET" \
    --project "$PROJECT_DIR" \
    > /tmp/bst-dashboard.log 2>&1 &
DASHBOARD_PID=$!
echo "  Dashboard PID: $DASHBOARD_PID"
sleep 1

# Start failure recovery monitor in background
echo "[2/3] Starting failure recovery monitor..."
python3 "$PROJECT_DIR/bst-failure-recovery.py" \
    --log "$LOG_FILE" \
    --project "$PROJECT_DIR" \
    --dashboard-port "$DASHBOARD_PORT" \
    > /tmp/bst-failure-recovery.log 2>&1 &
RECOVERY_PID=$!
echo "  Recovery PID: $RECOVERY_PID"
sleep 1

# Start build (foreground)
echo "[3/3] Starting build..."
echo ""
echo "📊 Dashboard: http://localhost:$DASHBOARD_PORT"
echo "📋 Build log: $LOG_FILE"
echo "🔧 Recovery: PID $RECOVERY_PID (see /tmp/bst-failure-recovery.log)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Run the build with provided arguments
cd "$PROJECT_DIR"
just bst-build $BUILD_ARGS $TARGET

# Capture exit status
BUILD_STATUS=$?

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $BUILD_STATUS -eq 0 ]; then
    echo "✅ Build completed successfully!"
else
    echo "❌ Build failed with status $BUILD_STATUS"
    echo "   Recovery monitor may have already attempted automatic fixes."
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Wait for recovery to finish if it's still running
echo "Waiting for recovery monitor to finish..."
wait $RECOVERY_PID || true

exit $BUILD_STATUS
