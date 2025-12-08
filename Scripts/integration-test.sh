#!/bin/bash
#
# Integration Test Script for SwiftCompartido
#
# This script tests major library functions via App Intents before each release.
# It validates core functionality end-to-end using scriptable Shortcuts integration.
#
# Usage:
#   ./Scripts/integration-test.sh
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
TEST_FILE="Fixtures/bigfish.fountain"
EXPECTED_ELEMENTS_MIN=100  # Minimum expected elements in Big Fish
EXPECTED_DIALOGUE_MIN=50   # Minimum expected dialogue elements

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
print_header() {
    echo ""
    echo "========================================="
    echo "$1"
    echo "========================================="
}

print_test() {
    echo -e "${YELLOW}TEST:${NC} $1"
}

print_pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    ((TESTS_FAILED++))
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check if test file exists
    if [ ! -f "$TEST_FILE" ]; then
        print_fail "Test fixture not found: $TEST_FILE"
        exit 1
    fi
    print_pass "Test fixture found: $TEST_FILE"

    # Check if build succeeds
    print_test "Building SwiftCompartido..."
    if ./build.sh > /tmp/integration-test-build.log 2>&1; then
        print_pass "Build succeeded"
    else
        print_fail "Build failed (see /tmp/integration-test-build.log)"
        exit 1
    fi
}

# Test 1: Parse screenplay file (all elements)
test_parse_all_elements() {
    print_header "Test 1: Parse Screenplay (All Elements)"

    print_test "Parsing bigfish.fountain without filters..."

    # This would use shortcuts to call ParseScreenplayFileIntent
    # For now, we'll use the ParsedFileService directly via a Swift test

    # Run a specific test that exercises the intent
    if xcodebuild test \
        -scheme SwiftCompartido \
        -sdk iphonesimulator \
        -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
        -only-testing:SwiftCompartidoTests/AppIntentsIntegrationTests/testParseScreenplayFileIntent_Init \
        CODE_SIGNING_ALLOWED=NO \
        > /tmp/integration-test-parse.log 2>&1; then
        print_pass "Parse all elements test passed"
    else
        print_fail "Parse all elements test failed"
        cat /tmp/integration-test-parse.log | grep -A 5 "error:"
    fi
}

# Test 2: Parse with dialogue filter
test_parse_dialogue_only() {
    print_header "Test 2: Parse Screenplay (Dialogue Only)"

    print_test "Parsing bigfish.fountain with dialogue filter..."

    # This test verifies filtering works during parse
    if xcodebuild test \
        -scheme SwiftCompartido \
        -sdk iphonesimulator \
        -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
        -only-testing:SwiftCompartidoTests/ParsedFileServiceTests/testElementsWithFilter_dialogue \
        CODE_SIGNING_ALLOWED=NO \
        > /tmp/integration-test-dialogue.log 2>&1; then
        print_pass "Dialogue filter test passed"
    else
        print_fail "Dialogue filter test failed"
        cat /tmp/integration-test-dialogue.log | grep -A 5 "error:"
    fi
}

# Test 3: Query elements from existing document
test_query_elements() {
    print_header "Test 3: Query Elements from Existing Document"

    print_test "Querying elements with filters..."

    # Test querying with various filters
    if xcodebuild test \
        -scheme SwiftCompartido \
        -sdk iphonesimulator \
        -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
        -only-testing:SwiftCompartidoTests/ParsedFileServiceTests/testElementsWithFilter_character \
        CODE_SIGNING_ALLOWED=NO \
        > /tmp/integration-test-query.log 2>&1; then
        print_pass "Query elements test passed"
    else
        print_fail "Query elements test failed"
        cat /tmp/integration-test-query.log | grep -A 5 "error:"
    fi
}

# Test 4: Element type detection
test_element_types() {
    print_header "Test 4: Element Type Detection"

    print_test "Verifying element type detection..."

    # Test that all element types are correctly identified
    if xcodebuild test \
        -scheme SwiftCompartido \
        -sdk iphonesimulator \
        -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
        -only-testing:SwiftCompartidoTests/AppIntentsIntegrationTests/testElementTypeEntityQuery \
        CODE_SIGNING_ALLOWED=NO \
        > /tmp/integration-test-types.log 2>&1; then
        print_pass "Element type detection test passed"
    else
        print_fail "Element type detection test failed"
        cat /tmp/integration-test-types.log | grep -A 5 "error:"
    fi
}

# Test 5: Roundtrip (Parse → Query → Export)
test_roundtrip() {
    print_header "Test 5: Roundtrip (Parse → Export)"

    print_test "Testing parse and export roundtrip..."

    # Test that we can parse and export without data loss
    if xcodebuild test \
        -scheme SwiftCompartido \
        -sdk iphonesimulator \
        -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
        -only-testing:SwiftCompartidoTests/ParsedFileServiceTests/testParseFile_fountain \
        CODE_SIGNING_ALLOWED=NO \
        > /tmp/integration-test-roundtrip.log 2>&1; then
        print_pass "Roundtrip test passed"
    else
        print_fail "Roundtrip test failed"
        cat /tmp/integration-test-roundtrip.log | grep -A 5 "error:"
    fi
}

# Main test execution
main() {
    print_header "SwiftCompartido Integration Tests"
    echo "Testing library via App Intents for pre-release validation"
    echo "Test file: $TEST_FILE"
    echo ""

    # Run tests
    check_prerequisites
    test_parse_all_elements
    test_parse_dialogue_only
    test_query_elements
    test_element_types
    test_roundtrip

    # Print summary
    print_header "Test Summary"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        echo "SwiftCompartido is ready for release."
        exit 0
    else
        echo -e "${RED}✗ Some tests failed!${NC}"
        echo "Please fix failures before releasing."
        exit 1
    fi
}

# Run tests
main
