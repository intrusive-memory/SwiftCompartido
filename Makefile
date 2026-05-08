SCHEME = SwiftCompartido
DESTINATION = 'platform=macOS,arch=arm64'
IOS_DESTINATION = 'platform=iOS Simulator,name=iPhone 17,OS=26.1'

.PHONY: build test test-ios clean resolve lint help

build:
	xcodebuild build -scheme $(SCHEME) -destination $(DESTINATION)

test:
	xcodebuild test -scheme $(SCHEME) -destination $(DESTINATION)

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
	@echo "  test       - Run macOS tests with architecture setting"
	@echo "  test-ios   - Run iOS tests on iPhone 17 simulator"
	@echo "  clean      - Clean build artifacts"
	@echo "  resolve    - Resolve Swift package dependencies"
	@echo "  lint       - Format all Swift source files"
	@echo "  help       - Show this help message"
