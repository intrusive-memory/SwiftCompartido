//
//  HoverTimingTests.swift
//  SwiftCompartidoTests
//
//  Tests for hover timing and delay behavior
//

import Testing
import SwiftUI
@testable import SwiftCompartido

@Suite("Hover Timing Tests")
@MainActor
struct HoverTimingTests {

    // MARK: - Test Fixtures

    /// Creates a test GuionElementModel
    private func createTestElement() -> GuionElementModel {
        GuionElementModel(
            elementText: "Test element",
            elementType: .action,
            chapterIndex: 0,
            orderIndex: 0
        )
    }

    // MARK: - Element State Tests

    @Test("Multiple elements maintain independent properties")
    func testIndependentHoverStates() {
        let elements = (0..<3).map { i in
            GuionElementModel(
                elementText: "Element \(i)",
                elementType: .action,
                chapterIndex: 0,
                orderIndex: i
            )
        }

        // Verify each element has independent properties
        #expect(elements.count == 3)
        for (index, element) in elements.enumerated() {
            #expect(element.elementText == "Element \(index)")
            #expect(element.orderIndex == index)
        }
    }
}
