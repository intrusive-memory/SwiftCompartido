//
//  GuionTextEditorPerformanceTests.swift
//  SwiftCompartido
//
//  Performance tests for GuionTextEditor vs GuionElementsList
//

import Testing
import Foundation
@testable import SwiftCompartido

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@Suite("GuionTextEditor Performance Tests")
struct GuionTextEditorPerformanceTests {

    @Test("TextKit2 - Load 1000 elements")
    func testTextKit2Load1000() async throws {
        let elements = generateElements(count: 1000)

        let attributedText = GuionTextElementMapper.buildAttributedText(from: elements)

        print("📊 TextKit 2 load (1000 elements)")
        print("📏 Generated text length: \(attributedText.length) characters")

        #expect(attributedText.length > 0)
    }

    @Test("TextKit2 - Load 5000 elements")
    func testTextKit2Load5000() async throws {
        let elements = generateElements(count: 5000)

        let attributedText = GuionTextElementMapper.buildAttributedText(from: elements)

        print("📊 TextKit 2 load (5000 elements)")
        print("📏 Generated text length: \(attributedText.length) characters")

        #expect(attributedText.length > 0)
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
