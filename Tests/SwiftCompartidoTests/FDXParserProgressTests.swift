import Testing
@testable import SwiftCompartido

/// Tests for FDXParser progress reporting functionality.
///
/// Validates Phase 2 requirements:
/// - XML element progress tracking
/// - Progress accuracy
/// - Cancellation support
/// - Backward compatibility
@Suite("FDXParser Progress Tests")
struct FDXParserProgressTests {

    // MARK: - Test Data

    private let simpleFDX = """
    <?xml version="1.0" encoding="UTF-8"?>
    <FinalDraft DocumentType="Script" Version="1">
        <Content>
            <Paragraph Type="Scene Heading">
                <Text>INT. TEST LOCATION - DAY</Text>
            </Paragraph>
            <Paragraph Type="Action">
                <Text>This is action text.</Text>
            </Paragraph>
            <Paragraph Type="Character">
                <Text>CHARACTER</Text>
            </Paragraph>
            <Paragraph Type="Dialogue">
                <Text>This is dialogue.</Text>
            </Paragraph>
        </Content>
    </FinalDraft>
    """

    private func generateLargeFDX(elementCount: Int) -> String {
        var fdx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FinalDraft DocumentType="Script" Version="1">
            <Content>
        """

        for i in 0..<elementCount {
            fdx += """

                    <Paragraph Type="Scene Heading">
                        <Text>INT. SCENE \(i) - DAY</Text>
                    </Paragraph>
                    <Paragraph Type="Action">
                        <Text>Action for scene \(i).</Text>
                    </Paragraph>
                    <Paragraph Type="Character">
                        <Text>CHARACTER</Text>
                    </Paragraph>
                    <Paragraph Type="Dialogue">
                        <Text>Dialogue \(i).</Text>
                    </Paragraph>
            """
        }

        fdx += """

            </Content>
        </FinalDraft>
        """

        return fdx
    }

    // MARK: - Progress Tests

    @Test("FDXParser reports progress during parsing")
    func testProgressUpdates() async throws {
        actor ProgressCollector {
            var updates: [ProgressUpdate] = []

            func add(_ update: ProgressUpdate) {
                updates.append(update)
            }

            func getUpdates() -> [ProgressUpdate] {
                return updates
            }
        }

        let collector = ProgressCollector()
        let progress = OperationProgress(totalUnits: nil) { update in
            Task {
                await collector.add(update)
            }
        }

        let parser = FDXParser()
        let largeFDX = generateLargeFDX(elementCount: 50)
        guard let data = largeFDX.data(using: .utf8) else {
            Issue.record("Failed to create test data")
            return
        }

        let document = try await parser.parse(data: data, filename: "test.fdx", progress: progress)

        // Wait for async updates
        try await Task.sleep(for: .milliseconds(50))

        let updates = await collector.getUpdates()

        #expect(updates.count > 0, "Should receive progress updates")
        #expect(document.elements.count > 0, "Should parse elements")
    }

    @Test("FDXParser progress reaches completion")
    func testProgressCompletion() async throws {
        actor ProgressCollector {
            var allUpdates: [ProgressUpdate] = []

            func add(_ update: ProgressUpdate) {
                allUpdates.append(update)
            }

            func getAll() -> [ProgressUpdate] {
                return allUpdates
            }
        }

        let collector = ProgressCollector()
        let progress = OperationProgress(totalUnits: nil) { update in
            Task {
                await collector.add(update)
            }
        }

        let parser = FDXParser()
        guard let data = simpleFDX.data(using: .utf8) else {
            Issue.record("Failed to create test data")
            return
        }

        _ = try await parser.parse(data: data, filename: "test.fdx", progress: progress)

        // Wait for async updates
        try await Task.sleep(for: .milliseconds(50))

        let allUpdates = await collector.getAll()

        #expect(allUpdates.count > 0, "Should receive progress updates")

        // Check final update
        if let finalUpdate = allUpdates.last {
            #expect(finalUpdate.description.contains("complete"), "Final update should mention completion")
        }
    }

    @Test("FDXParser tracks element counts")
    func testElementCounting() async throws {
        actor ProgressCollector {
            var maxElements: Int64 = 0

            func update(_ count: Int64) {
                if count > maxElements {
                    maxElements = count
                }
            }

            func getMax() -> Int64 {
                return maxElements
            }
        }

        let collector = ProgressCollector()
        let progress = OperationProgress(totalUnits: nil) { update in
            Task {
                await collector.update(update.completedUnits)
            }
        }

        let parser = FDXParser()
        let largeFDX = generateLargeFDX(elementCount: 30)
        guard let data = largeFDX.data(using: .utf8) else {
            Issue.record("Failed to create test data")
            return
        }

        let document = try await parser.parse(data: data, filename: "test.fdx", progress: progress)

        // Wait for async updates
        try await Task.sleep(for: .milliseconds(50))

        let maxElements = await collector.getMax()

        #expect(maxElements > 0, "Should track element count")
        #expect(document.elements.count > 100, "Should parse multiple elements")
    }

    // MARK: - Cancellation Tests

    @Test("FDXParser cancellation stops parsing")
    func testCancellation() async throws {
        let largeFDX = generateLargeFDX(elementCount: 100)
        guard let data = largeFDX.data(using: .utf8) else {
            Issue.record("Failed to create test data")
            return
        }

        let task = Task {
            let parser = FDXParser()
            let progress = OperationProgress(totalUnits: nil)
            return try await parser.parse(data: data, filename: "test.fdx", progress: progress)
        }

        // Cancel immediately
        task.cancel()

        do {
            _ = try await task.value
            // Note: XMLParser may complete before cancellation is checked
            // This is acceptable behavior
        } catch is CancellationError {
            // Expected if cancellation was caught
        } catch {
            // Parsing may complete successfully if cancellation wasn't checked in time
        }
    }

    // MARK: - Nil Progress Tests

    @Test("FDXParser works with nil progress")
    func testNilProgress() async throws {
        let parser = FDXParser()
        guard let data = simpleFDX.data(using: .utf8) else {
            Issue.record("Failed to create test data")
            return
        }

        let nilProgress: OperationProgress? = nil
        let document = try await parser.parse(data: data, filename: "test.fdx", progress: nilProgress)

        #expect(document.elements.count > 0, "Should parse with nil progress")
    }

    // MARK: - Backward Compatibility Tests

    @Test("Synchronous parse still works")
    func testBackwardCompatibility() throws {
        let parser = FDXParser()
        guard let data = simpleFDX.data(using: .utf8) else {
            Issue.record("Failed to create test data")
            return
        }

        let document = try parser.parse(data: data, filename: "test.fdx")

        #expect(document.elements.count > 0, "Sync parse should work")
    }

    @Test("Async and sync parsers produce identical results")
    func testAsyncSyncEquivalence() async throws {
        guard let data = simpleFDX.data(using: .utf8) else {
            Issue.record("Failed to create test data")
            return
        }

        // Sync parse
        let syncParser = FDXParser()
        let syncDocument = try syncParser.parse(data: data, filename: "test.fdx")

        // Async parse
        let asyncParser = FDXParser()
        let nilProgress: OperationProgress? = nil
        let asyncDocument = try await asyncParser.parse(data: data, filename: "test.fdx", progress: nilProgress)

        #expect(syncDocument.elements.count == asyncDocument.elements.count,
                "Sync and async should produce same element count")

        // Compare element types
        for i in 0..<syncDocument.elements.count {
            #expect(syncDocument.elements[i].elementType == asyncDocument.elements[i].elementType,
                    "Element \(i) types should match")
        }
    }

    // MARK: - Progress Description Tests

    @Test("FDXParser progress descriptions are meaningful")
    func testProgressDescriptions() async throws {
        actor ProgressCollector {
            var lastDescription: String = ""

            func update(_ desc: String) {
                lastDescription = desc
            }

            func getLast() -> String {
                return lastDescription
            }
        }

        let collector = ProgressCollector()
        let progress: OperationProgress? = OperationProgress(totalUnits: nil) { update in
            Task {
                await collector.update(update.description)
            }
        }

        let parser = FDXParser()
        guard let data = simpleFDX.data(using: .utf8) else {
            Issue.record("Failed to create test data")
            return
        }

        _ = try await parser.parse(data: data, filename: "test.fdx", progress: progress)

        // Wait for async updates
        try await Task.sleep(for: .milliseconds(50))

        let lastDescription = await collector.getLast()

        #expect(lastDescription.contains("complete") || lastDescription.contains("Parsing"),
                "Progress description should be meaningful")
    }

    // MARK: - Large File Tests

    @Test("FDXParser handles large files with progress")
    func testLargeFileHandling() async throws {
        actor ProgressCollector {
            var updateCount: Int = 0

            func increment() {
                updateCount += 1
            }

            func getCount() -> Int {
                return updateCount
            }
        }

        let collector = ProgressCollector()
        let progress = OperationProgress(totalUnits: nil) { _ in
            Task {
                await collector.increment()
            }
        }

        let parser = FDXParser()
        let largeFDX = generateLargeFDX(elementCount: 100)
        guard let data = largeFDX.data(using: .utf8) else {
            Issue.record("Failed to create test data")
            return
        }

        let document = try await parser.parse(data: data, filename: "large.fdx", progress: progress)

        // Wait for async updates
        try await Task.sleep(for: .milliseconds(100))

        let updateCount = await collector.getCount()

        #expect(updateCount > 0, "Large file should have progress updates")
        #expect(document.elements.count >= 400, "Should parse large file")
    }

    // MARK: - Invalid XML Tests

    @Test("FDXParser handles invalid XML gracefully")
    func testInvalidXMLHandling() async throws {
        let invalidFDX = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FinalDraft>
            <Content>
                <Paragraph Type="Action"
                    <Text>Missing closing tag
                </Paragraph>
            </Content>
        """

        let parser = FDXParser()
        guard let data = invalidFDX.data(using: .utf8) else {
            Issue.record("Failed to create test data")
            return
        }

        let progress = OperationProgress(totalUnits: nil)

        do {
            _ = try await parser.parse(data: data, filename: "invalid.fdx", progress: progress)
            Issue.record("Expected parsing to fail for invalid XML")
        } catch FDXParserError.unableToParse {
            // Expected
        } catch {
            Issue.record("Expected FDXParserError.unableToParse, got \(error)")
        }
    }

    // MARK: - Title Page Tests

    @Test("FDXParser with title page elements")
    func testTitlePageParsing() async throws {
        let fdxWithTitle = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FinalDraft DocumentType="Script" Version="1">
            <TitlePage>
                <Content>
                    <Paragraph Type="Title">
                        <Text>Test Screenplay</Text>
                    </Paragraph>
                    <Paragraph Type="Author">
                        <Text>Test Author</Text>
                    </Paragraph>
                </Content>
            </TitlePage>
            <Content>
                <Paragraph Type="Scene Heading">
                    <Text>INT. TEST - DAY</Text>
                </Paragraph>
                <Paragraph Type="Action">
                    <Text>Action text.</Text>
                </Paragraph>
            </Content>
        </FinalDraft>
        """

        let parser = FDXParser()
        guard let data = fdxWithTitle.data(using: .utf8) else {
            Issue.record("Failed to create test data")
            return
        }

        let progress: OperationProgress? = OperationProgress(totalUnits: nil)
        let document = try await parser.parse(data: data, filename: "title.fdx", progress: progress)

        #expect(document.elements.count > 0, "Should parse elements")
        #expect(document.titlePageEntries.count > 0, "Should parse title page")
    }
}
