#!/bin/bash
#
# Test Apple Intelligence Features
#
# This script runs tests that require Apple Intelligence (Foundation Models)
# to be enabled. These tests validate AI-powered PDF parsing when the API
# is available.
#
# Requirements:
# - iOS 26.2+ / macOS 26.2+ (currently shipping)
# - Apple Intelligence enabled in System Settings
# - M1+ Mac or A17 Pro+ device
#
# Usage:
#   ./scripts/test-ai-features.sh                  # Run on iOS Simulator
#   ./scripts/test-ai-features.sh --macos          # Run on macOS
#   ./scripts/test-ai-features.sh --device         # Run on physical device
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default platform
PLATFORM="iOS Simulator"
DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --macos)
            PLATFORM="macOS"
            DESTINATION="platform=macOS"
            shift
            ;;
        --device)
            PLATFORM="iOS Device"
            DESTINATION="platform=iOS"
            shift
            ;;
        --help)
            echo "Usage: $0 [--macos|--device|--help]"
            echo ""
            echo "Options:"
            echo "  --macos     Run tests on macOS"
            echo "  --device    Run tests on connected iOS device"
            echo "  --help      Show this help message"
            echo ""
            echo "Default: Runs on iOS Simulator (iPhone 17 Pro)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  🤖  Apple Intelligence Feature Tests                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}⚠️  Requirements:${NC}"
echo "  • Apple Intelligence enabled in System Settings"
echo "  • iOS 26.2+ / macOS 26.2+ (currently shipping)"
echo "  • M1+ Mac or A17 Pro+ device"
echo ""
echo -e "${BLUE}Platform:${NC} $PLATFORM"
echo -e "${BLUE}Destination:${NC} $DESTINATION"
echo ""

# Check if Foundation Models framework exists (basic check)
echo -e "${BLUE}→${NC} Checking Foundation Models availability..."

if xcodebuild -showBuildSettings \
    -scheme SwiftCompartido \
    -destination "$DESTINATION" 2>&1 | grep -q "SwiftCompartido"; then
    echo -e "${GREEN}✓${NC} Build settings accessible"
else
    echo -e "${RED}✗${NC} Cannot access build settings"
    echo -e "${YELLOW}⚠️${NC}  Make sure Xcode is properly configured"
    exit 1
fi

# Build the project first
echo ""
echo -e "${BLUE}→${NC} Building SwiftCompartido..."
xcodebuild build \
    -scheme SwiftCompartido \
    -destination "$DESTINATION" \
    -quiet \
    CODE_SIGNING_ALLOWED=NO || {
    echo -e "${RED}✗${NC} Build failed"
    exit 1
}
echo -e "${GREEN}✓${NC} Build succeeded"

# Run AI tests
echo ""
echo -e "${BLUE}→${NC} Running Apple Intelligence tests..."
echo ""

xcodebuild test \
    -scheme SwiftCompartido \
    -only-testing:SwiftCompartidoTests/PDFScreenplayParserAITests \
    -destination "$DESTINATION" \
    CODE_SIGNING_ALLOWED=NO

TEST_RESULT=$?

echo ""
if [ $TEST_RESULT -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅  Apple Intelligence Tests Passed                      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ❌  Apple Intelligence Tests Failed                      ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Common issues:${NC}"
    echo "  1. Foundation Models API not yet functional (iOS 26.2 is shipping, but API may not be ready)"
    echo "  2. Apple Intelligence not enabled in System Settings"
    echo "  3. Running on incompatible hardware (need M1+ or A17 Pro+)"
    echo "  4. Xcode SDK may need update to access Foundation Models types"
    echo ""
    echo -e "${BLUE}Note:${NC} Tests will skip gracefully if Apple Intelligence is unavailable."
    echo "      This is expected if the API isn't finalized yet."
    exit 1
fi
