//
//  InteractivePopoverTests.swift
//  SwiftCompartidoTests
//
//  Tests for interactive popover behavior (buttons, controls, extended hover area)
//

import Foundation
import Testing
import SwiftUI
@testable import SwiftCompartido

@Suite("Interactive Popover Tests")
@MainActor
struct InteractivePopoverTests {

    // MARK: - Element Property Tests

    @Test("Multiple elements maintain independent properties")
    func testMultipleInteractivePopovers() {
        let elements = (0..<10).map { i in
            GuionElementModel(
                elementText: "Element \(i)",
                elementType: .action,
                chapterIndex: 0,
                orderIndex: i
            )
        }

        #expect(elements.count == 10)
        for (index, element) in elements.enumerated() {
            #expect(element.elementText == "Element \(index)")
            #expect(element.orderIndex == index)
        }
    }
}
