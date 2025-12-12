#!/bin/bash

# SwiftCompartido Build Script
# This script builds for iOS Simulator and Mac Catalyst (NOT macOS standalone)

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default values
TARGET="ios"
ACTION="build"
TESTPLAN=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --target)
      TARGET="$2"
      shift 2
      ;;
    --action)
      ACTION="$2"
      shift 2
      ;;
    --testplan)
      TESTPLAN="$2"
      shift 2
      ;;
    --help)
      echo "Usage: ./build.sh [options]"
      echo ""
      echo "Options:"
      echo "  --target <ios|catalyst-arm64|catalyst-x86>  Target platform (default: ios)"
      echo "  --action <build|test|clean>                 Action to perform (default: build)"
      echo "  --testplan <UnitTests|LongTests|UITests|PerformanceTests>  Test plan to run (optional)"
      echo "  --help                                      Show this help message"
      echo ""
      echo "Examples:"
      echo "  ./build.sh                                  Build for iOS Simulator"
      echo "  ./build.sh --action test                    Run all tests on iOS Simulator"
      echo "  ./build.sh --action test --testplan UnitTests  Run unit tests only"
      echo "  ./build.sh --target catalyst-arm64          Build for Mac Catalyst (arm64)"
      echo "  ./build.sh --action clean                   Clean build artifacts"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Clean action
if [ "$ACTION" == "clean" ]; then
  echo -e "${BLUE}🧹 Cleaning build artifacts...${NC}"
  rm -rf .build
  rm -rf .swiftpm
  echo -e "${GREEN}✅ Clean complete${NC}"
  exit 0
fi

# Build/Test based on target
case $TARGET in
  ios)
    echo -e "${BLUE}🔨 Building for iOS Simulator (arm64)${NC}"
    if [ "$ACTION" == "test" ]; then
      # Build test command with optional test plan
      TEST_CMD="xcodebuild test \
        -scheme SwiftCompartido \
        -sdk iphonesimulator \
        -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
        -enableCodeCoverage YES \
        -parallel-testing-enabled YES"

      # Add test plan if specified
      if [ -n "$TESTPLAN" ]; then
        TEST_CMD="$TEST_CMD -testPlan $TESTPLAN"
        echo -e "${BLUE}📋 Using test plan: $TESTPLAN${NC}"
      else
        echo -e "${BLUE}📋 Running all tests${NC}"
      fi

      TEST_CMD="$TEST_CMD CODE_SIGNING_ALLOWED=NO"

      # Execute the test command
      eval $TEST_CMD
    else
      xcodebuild build \
        -scheme SwiftCompartido \
        -sdk iphonesimulator \
        -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
        CODE_SIGNING_ALLOWED=NO
    fi
    ;;

  catalyst-arm64)
    echo -e "${BLUE}🔨 Building for Mac Catalyst (arm64)${NC}"
    xcodebuild build \
      -scheme SwiftCompartido \
      -destination 'generic/platform=macOS,variant=Mac Catalyst' \
      -arch arm64 \
      CODE_SIGNING_ALLOWED=NO
    ;;

  catalyst-x86)
    echo -e "${BLUE}🔨 Building for Mac Catalyst (x86_64)${NC}"
    xcodebuild build \
      -scheme SwiftCompartido \
      -destination 'generic/platform=macOS,variant=Mac Catalyst' \
      -arch x86_64 \
      CODE_SIGNING_ALLOWED=NO
    ;;

  *)
    echo -e "${RED}Unknown target: $TARGET${NC}"
    echo "Valid targets: ios, catalyst-arm64, catalyst-x86"
    exit 1
    ;;
esac

if [ $? -eq 0 ]; then
  # Capitalize first letter (bash 3 compatible)
  ACTION_CAPITALIZED="$(tr '[:lower:]' '[:upper:]' <<< ${ACTION:0:1})${ACTION:1}"
  echo -e "${GREEN}✅ ${ACTION_CAPITALIZED} succeeded for ${TARGET}${NC}"
else
  ACTION_CAPITALIZED="$(tr '[:lower:]' '[:upper:]' <<< ${ACTION:0:1})${ACTION:1}"
  echo -e "${RED}❌ ${ACTION_CAPITALIZED} failed for ${TARGET}${NC}"
  exit 1
fi
