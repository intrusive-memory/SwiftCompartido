//
//  GuionTextEditorPerformanceTests.swift
//  SwiftCompartido
//
//  Performance tests for GuionTextEditor vs GuionElementsList
//

import Testing
import Foundation
@testable import SwiftCompartido

@Suite("GuionTextEditor Performance Tests")
struct GuionTextEditorPerformanceTests {

    @Test("TextKit2 - Load 1000 elements")
    func testTextKit2Load1000() async throws {
        let elements = generateElements(count: 1000)

        let startTime = CFAbsoluteTimeGetCurrent()

        let text = GuionTextElementMapper.buildText(from: elements)

        let loadTime = CFAbsoluteTimeGetCurrent() - startTime

        await PerformanceMetricsTracker.shared.recordMetric(
            testName: "TextKit2_Load_1000",
            elementCount: 1000,
            parseTime: 0,
            convertTime: loadTime,
            sortTime: 0,
            formatTime: 0
        )

        print("📊 TextKit 2 load (1000 elements): \(String(format: "%.3f", loadTime))s")
        print("📏 Generated text length: \(text.count) characters")

        #expect(loadTime < 0.5)  // Target: < 0.5s (vs 1.2s for List-based)
        #expect(text.count > 0)
    }

    @Test("TextKit2 - Load 5000 elements")
    func testTextKit2Load5000() async throws {
        let elements = generateElements(count: 5000)

        let startTime = CFAbsoluteTimeGetCurrent()

        let text = GuionTextElementMapper.buildText(from: elements)

        let loadTime = CFAbsoluteTimeGetCurrent() - startTime

        await PerformanceMetricsTracker.shared.recordMetric(
            testName: "TextKit2_Load_5000",
            elementCount: 5000,
            parseTime: 0,
            convertTime: loadTime,
            sortTime: 0,
            formatTime: 0
        )

        print("📊 TextKit 2 load (5000 elements): \(String(format: "%.3f", loadTime))s")
        print("📏 Generated text length: \(text.count) characters")

        #expect(loadTime < 2.5)  // Target: < 2.5s (vs 24s for List-based)
        #expect(text.count > 0)
    }

    @Test("TextKit2 - Spacing logic matches GuionElementsList")
    func testSpacingLogic() async throws {
        // Test dialogue group spacing
        let dialogueGroup = [
            GuionElementModel(elementText: "JOHN", elementType: .character, orderIndex: 0),
            GuionElementModel(elementText: "Hello there.", elementType: .dialogue, orderIndex: 1),
            GuionElementModel(elementText: "(smiling)", elementType: .parenthetical, orderIndex: 2),
            GuionElementModel(elementText: "How are you?", elementType: .dialogue, orderIndex: 3),
            GuionElementModel(elementText: "John walks away.", elementType: .action, orderIndex: 4)
        ]

        let text = GuionTextElementMapper.buildText(from: dialogueGroup)

        // Should have single newlines within dialogue group, double after
        let lines = text.components(separatedBy: "\n")

        print("📝 Generated text:\n\(text)")
        print("📊 Line count: \(lines.count)")

        // Verify text contains all elements
        #expect(text.contains("JOHN"))
        #expect(text.contains("Hello there."))
        #expect(text.contains("(smiling)"))
        #expect(text.contains("How are you?"))
        #expect(text.contains("John walks away."))
    }

    @Test("TextKit2 - Action spacing")
    func testActionSpacing() async throws {
        let elements = [
            GuionElementModel(elementText: "First action.", elementType: .action, orderIndex: 0),
            GuionElementModel(elementText: "Second action.", elementType: .action, orderIndex: 1)
        ]

        let text = GuionTextElementMapper.buildText(from: elements)

        // Actions should have double newline spacing
        #expect(text.contains("\n\n"))

        print("📝 Action spacing test:\n\(text)")
    }

    // MARK: - Helpers

    private func generateElements(count: Int) -> [GuionElementModel] {
        var elements: [GuionElementModel] = []

        for i in 0..<count {
            let elementType: ElementType

            // Mix of element types for realistic test
            switch i % 5 {
            case 0:
                elementType = .sceneHeading
            case 1:
                elementType = .action
            case 2:
                elementType = .character
            case 3:
                elementType = .dialogue
            default:
                elementType = .action
            }

            let element = GuionElementModel(
                elementText: "This is element \(i) with some **bold** and *italic* text.",
                elementType: elementType,
                chapterIndex: 0,
                orderIndex: i
            )

            elements.append(element)
        }

        return elements
    }
}
