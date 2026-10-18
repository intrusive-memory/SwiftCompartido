SCHEME = SwiftCompartido
DESTINATION = 'platform=macOS,arch=arm64'
IOS_DESTINATION = 'platform=iOS Simulator,name=iPhone 17,OS=26.1'

# ---------------------------------------------------------------------------
# CI test selection — the single source of truth. `.github/workflows/tests.yml`
# calls `make test-ci`; do not add -skip-testing flags to the workflow.
# ---------------------------------------------------------------------------

# The CI unit run covers this target only (SwiftCompartidoPDFTests needs
# Apple Intelligence / pandoc and SwiftCompartidoPerformanceTests is perf).
CI_TEST_TARGET = SwiftCompartidoTests

# Tests that need Apple Intelligence (Foundation Models). Headless runners
# have no on-device model, so they are run manually via Scripts/test-ai-features.sh.
# PDFScreenplayParserAIConversionTests is the only PDF test that touches the model:
# one page, skipped when the model is unavailable, bounded by Options.aiPageTimeout.
# ParsedFileServiceTests/testParsePDFFile() pins Options.heuristicOnly and runs in CI.
CI_SKIP_AI = \
  SwiftCompartidoTests/GuionDocumentSnapshotCastListTests \
  SwiftCompartidoTests/CastListGenerationIntegrationTests \
  SwiftCompartidoTests/PDFScreenplayParserAIConversionTests

# Schema migration suite, excluded from CI by the previous inline list.
CI_SKIP_OTHER = \
  SwiftCompartidoTests/MigrationTests

# Performance tests: XCTest measure{} blocks and wall-clock timing tests inside
# the unit target. They never run in CI; `make test-perf` runs them locally.
# Swift Testing identifiers carry the trailing "()" (quoted for the shell);
# XCTest identifiers do not.
PERF_TESTS = \
  SwiftCompartidoTests/GuionJSONSerializerTests/testPerformance_Encode120PageScreenplay \
  SwiftCompartidoTests/GuionJSONSerializerTests/testPerformance_Decode120PageScreenplay \
  SwiftCompartidoTests/GuionJSONSerializerTests/testPerformance_RoundTrip \
  'SwiftCompartidoTests/IntegrationTests/testPerformanceRegression()' \
  'SwiftCompartidoTests/SceneBrowserUITests/testLargeScriptPerformance()'

# The dedicated benchmark target (also run by performance-tests.yml on demand).
PERF_TARGET = SwiftCompartidoPerformanceTests

CI_SKIPS = $(addprefix -skip-testing:,$(CI_SKIP_AI) $(CI_SKIP_OTHER) $(PERF_TESTS) $(PERF_TARGET))
PERF_ONLY = $(addprefix -only-testing:,$(PERF_TARGET) $(PERF_TESTS))

.PHONY: build test test-ci test-perf test-one test-ios clean resolve lint help

build:
	xcodebuild build -scheme $(SCHEME) -destination $(DESTINATION)

test:
	xcodebuild test -scheme $(SCHEME) -destination $(DESTINATION)

test-ci:
	xcodebuild test -scheme $(SCHEME) -destination $(DESTINATION) \
	  -only-testing:$(CI_TEST_TARGET) \
	  $(CI_SKIPS)

test-perf:
	xcodebuild test -scheme $(SCHEME) -destination $(DESTINATION) \
	  $(PERF_ONLY)

# One suite or test, e.g. make test-one TEST='SwiftCompartidoTests/ParsedFileServiceTests/testParsePDFFile()'
test-one:
	@test -n "$(TEST)" || { echo "usage: make test-one TEST=Target/Suite[/test()]"; exit 2; }
	xcodebuild test -scheme $(SCHEME) -destination $(DESTINATION) \
	  -only-testing:'$(TEST)'

test-ios:
	xcodebuild test -scheme $(SCHEME) \
	  -destination $(IOS_DESTINATION) \
	  -skipPackagePluginValidation \
	  ONLY_ACTIVE_ARCH=YES \
	  COMPILER_INDEX_STORE_ENABLE=NO

clean:
	xcodebuild clean -scheme $(SCHEME) -destination $(DESTINATION)
	rm -rf .build

resolve:
	swift package resolve

lint:
	swift format -i -r .

help:
	@echo "Available targets:"
	@echo "  build      - Build the SwiftCompartido scheme for macOS"
	@echo "  test       - Run the full macOS suite (all test targets, incl. PDF/AI and performance)"
	@echo "  test-ci    - Run the CI unit suite: SwiftCompartidoTests minus AI, migration and performance tests"
	@echo "  test-perf  - Run the performance tests locally (never run in CI)"
	@echo "  test-one   - Run one suite or test: make test-one TEST=Target/Suite[/test()]"
	@echo "  test-ios   - Run iOS tests on iPhone 17 simulator"
	@echo "  clean      - Clean build artifacts"
	@echo "  resolve    - Resolve Swift package dependencies"
	@echo "  lint       - Format all Swift source files"
	@echo "  help       - Show this help message"
