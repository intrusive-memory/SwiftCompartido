//
//  GuionTextElementMapper.swift
//  SwiftCompartido
//
//  Minimal text combiner - no formatting, just raw text display
//

import Foundation

/// Converts GuionElementModel array to a single string for display
/// Phase 1: Just combine text with spacing - no formatting yet
public class GuionTextElementMapper {

    /// Builds a simple string from all elements with basic spacing
    public static func buildText(from elements: [GuionElementModel]) -> String {
        var combined = ""

        for (index, element) in elements.enumerated() {
            // Just append the raw text
            combined += element.elementText

            // Add spacing based on element type (matches existing GuionElementsList)
            if shouldAddSpacing(element: element, nextElement: elements[safe: index + 1]) {
                combined += "\n\n"
            } else {
                combined += "\n"
            }
        }

        return combined
    }

    /// Determines spacing (matches GuionElementsList logic exactly)
    private static func shouldAddSpacing(element: GuionElementModel, nextElement: GuionElementModel?) -> Bool {
        // Action and synopsis always get spacing
        if element.elementType == .action || element.elementType == .synopsis {
            return true
        }

        // Dialogue group logic
        if element.elementType == .dialogue ||
           element.elementType == .parenthetical ||
           element.elementType == .lyrics {
            guard let next = nextElement else { return true }
            return next.elementType != .dialogue &&
                   next.elementType != .parenthetical &&
                   next.elementType != .lyrics
        }

        return false
    }
}

// Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
