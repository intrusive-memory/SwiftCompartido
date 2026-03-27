//
//  GuionTextElementMapper.swift
//  SwiftCompartido
//
//  Converts GuionElementModel array to formatted NSAttributedString
//  with screenplay and markdown formatting
//

import Foundation
import SwiftUI

#if os(iOS)
  import UIKit
  typealias PlatformFont = UIFont
  typealias PlatformColor = UIColor
#elseif os(macOS)
  import AppKit
  typealias PlatformFont = NSFont
  typealias PlatformColor = NSColor
#endif

/// Converts GuionElementModel array to properly formatted NSAttributedString
/// Supports both screenplay formatting and GitHub-style markdown
public class GuionTextElementMapper {

  /// Standard screenplay formatting constants (based on 12pt Courier, 65 characters per line)
  private struct ScreenplayFormat {
    // Base measurements at 12pt
    static let baseCharacterWidth: CGFloat = 12 * ScreenplayPageFormat.courierCharacterAspectRatio  // 7.2pt

    // Margins as character counts (will scale with font size)
    static let dialogueLeftMarginChars: CGFloat = 16.25  // 25% of 65
    static let characterLeftMarginChars: CGFloat = 26  // 40% of 65
    static let parentheticalLeftMarginChars: CGFloat = 19.5  // 30% of 65
  }

  /// Builds a formatted NSAttributedString from all elements
  public static func buildAttributedText(
    from elements: [GuionElementModel],
    fontSize: CGFloat = 12
  ) -> NSAttributedString {
    let combined = NSMutableAttributedString()

    let baseFont =
      PlatformFont(name: "Courier New", size: fontSize)
      ?? PlatformFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    let charWidth = fontSize * ScreenplayPageFormat.courierCharacterAspectRatio

    for (index, element) in elements.enumerated() {
      let attrString = createFormattedElement(
        element: element,
        fontSize: fontSize,
        baseFont: baseFont,
        charWidth: charWidth
      )

      combined.append(attrString)

      // Add spacing based on element type
      if shouldAddSpacing(element: element, nextElement: elements[safe: index + 1]) {
        combined.append(NSAttributedString(string: "\n\n"))
      } else {
        combined.append(NSAttributedString(string: "\n"))
      }
    }

    return combined
  }

  /// Create formatted attributed string for a single element
  private static func createFormattedElement(
    element: GuionElementModel,
    fontSize: CGFloat,
    baseFont: PlatformFont,
    charWidth: CGFloat
  ) -> NSAttributedString {

    // Get text content (use pre-computed formattedText if available)
    var textContent: String
    var hasInlineFormatting = false

    if let formattedText = element.formattedText {
      // Use pre-computed formatted text
      let mutableText = NSMutableAttributedString(formattedText)
      applyElementFormatting(
        to: mutableText, element: element, fontSize: fontSize, charWidth: charWidth)
      return mutableText
    } else {
      // Use raw text and apply Fountain formatting
      textContent = element.elementText
    }

    // Prepend hashtag prefix for section headings
    var hashtagPrefixLength = 0
    if case .sectionHeading(let level) = element.elementType {
      let hashtagPrefix = String(repeating: "#", count: level) + " "
      textContent = hashtagPrefix + textContent
      hashtagPrefixLength = hashtagPrefix.count
    }

    // Create base attributed string
    let attrString = NSMutableAttributedString(string: textContent)

    // Apply inline formatting (bold, italic, underline from Fountain)
    // Skip inline formatting for certain element types that should display raw text
    let skipInlineFormatting: Bool = {
      switch element.elementType {
      case .comment, .boneyard, .pageBreak:
        return true
      default:
        return false
      }
    }()

    if !skipInlineFormatting {
      applyInlineFormatting(to: attrString, baseFont: baseFont, fontSize: fontSize)
    }

    // Apply element-level formatting (margins, indents, fonts)
    applyElementFormatting(
      to: attrString, element: element, fontSize: fontSize, charWidth: charWidth)

    // Gray out hashtag prefix for section headings
    if hashtagPrefixLength > 0 {
      let prefixRange = NSRange(location: 0, length: hashtagPrefixLength)
      #if os(iOS)
        attrString.addAttribute(
          .foregroundColor, value: PlatformColor.secondaryLabel.withAlphaComponent(0.5),
          range: prefixRange)
      #elseif os(macOS)
        attrString.addAttribute(
          .foregroundColor, value: PlatformColor.secondaryLabelColor.withAlphaComponent(0.5),
          range: prefixRange)
      #endif
    }

    return attrString
  }

  /// Apply inline Fountain formatting (bold, italic, underline)
  private static func applyInlineFormatting(
    to attrString: NSMutableAttributedString,
    baseFont: PlatformFont,
    fontSize: CGFloat
  ) {
    let text = attrString.string
    let fullRange = NSRange(location: 0, length: attrString.length)

    // Bold: **text**
    applyPattern(
      "\\*\\*([^*]+)\\*\\*", to: attrString, baseFont: baseFont, fontSize: fontSize, isBold: true,
      isItalic: false)

    // Italic: *text*
    applyPattern(
      "(?<!\\*)\\*([^*]+)\\*(?!\\*)", to: attrString, baseFont: baseFont, fontSize: fontSize,
      isBold: false, isItalic: true)

    // Underline: _text_
    applyUnderlinePattern("_([^_]+)_", to: attrString)
  }

  /// Apply regex pattern for bold/italic
  private static func applyPattern(
    _ pattern: String,
    to attrString: NSMutableAttributedString,
    baseFont: PlatformFont,
    fontSize: CGFloat,
    isBold: Bool,
    isItalic: Bool
  ) {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

    let text = attrString.string
    let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.count))

    // Process in reverse to maintain string positions
    for match in matches.reversed() {
      let fullRange = match.range
      let contentRange = match.range(at: 1)

      // Create formatted font
      var symbolicTraits: UInt32 = 0
      if isBold { symbolicTraits |= 2 }  // Bold trait
      if isItalic { symbolicTraits |= 1 }  // Italic trait

      #if os(iOS)
        let font: PlatformFont
        if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(
          UIFontDescriptor.SymbolicTraits(rawValue: symbolicTraits))
        {
          font = PlatformFont(descriptor: descriptor, size: fontSize)
        } else {
          font = baseFont
        }
      #elseif os(macOS)
        let font: PlatformFont
        let descriptor = baseFont.fontDescriptor.withSymbolicTraits(
          NSFontDescriptor.SymbolicTraits(rawValue: symbolicTraits))
        font = PlatformFont(descriptor: descriptor, size: fontSize) ?? baseFont
      #endif

      // Extract content without markers
      let content = (text as NSString).substring(with: contentRange)
      attrString.replaceCharacters(in: fullRange, with: content)

      // Apply font
      let newRange = NSRange(location: fullRange.location, length: content.count)
      attrString.addAttribute(.font, value: font, range: newRange)
    }
  }

  /// Apply underline pattern
  private static func applyUnderlinePattern(
    _ pattern: String, to attrString: NSMutableAttributedString
  ) {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return }

    let text = attrString.string
    let matches = regex.matches(in: text, range: NSRange(location: 0, length: text.count))

    // Process in reverse to maintain string positions
    for match in matches.reversed() {
      let fullRange = match.range
      let contentRange = match.range(at: 1)

      // Extract content without markers
      let content = (text as NSString).substring(with: contentRange)
      attrString.replaceCharacters(in: fullRange, with: content)

      // Apply underline
      let newRange = NSRange(location: fullRange.location, length: content.count)
      attrString.addAttribute(
        .underlineStyle, value: NSUnderlineStyle.single.rawValue, range: newRange)
    }
  }

  /// Apply element-level formatting (margins, fonts, colors)
  private static func applyElementFormatting(
    to attrString: NSMutableAttributedString,
    element: GuionElementModel,
    fontSize: CGFloat,
    charWidth: CGFloat
  ) {
    let fullRange = NSRange(location: 0, length: attrString.length)

    // Create paragraph style
    let paragraphStyle = createParagraphStyle(
      for: element.elementType, charWidth: charWidth, fontSize: fontSize)
    attrString.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)

    // Apply font and color based on element type
    let (font, color) = createFontAndColor(for: element.elementType, baseFontSize: fontSize)
    attrString.addAttribute(.font, value: font, range: fullRange)
    attrString.addAttribute(.foregroundColor, value: color, range: fullRange)
  }

  /// Create NSParagraphStyle with proper margins for element type
  private static func createParagraphStyle(
    for elementType: ElementType,
    charWidth: CGFloat,
    fontSize: CGFloat
  ) -> NSParagraphStyle {
    let style = NSMutableParagraphStyle()

    // Line spacing (1.5x for readability)
    style.lineSpacing = fontSize * (ScreenplayPageFormat.lineSpacingMultiplier - 1.0)
    style.lineHeightMultiple = 1.0

    switch elementType {
    case .sceneHeading:
      // Full width, bold
      style.firstLineHeadIndent = 0
      style.headIndent = 0
      style.alignment = .left

    case .action, .synopsis, .boneyard:
      // Full width
      style.firstLineHeadIndent = 0
      style.headIndent = 0
      style.alignment = .left

    case .character:
      // 40% left margin (26 characters)
      let leftMargin = charWidth * ScreenplayFormat.characterLeftMarginChars
      style.firstLineHeadIndent = leftMargin
      style.headIndent = leftMargin
      style.alignment = .left

    case .dialogue, .lyrics:
      // 25% left margin (16.25 characters)
      let leftMargin = charWidth * ScreenplayFormat.dialogueLeftMarginChars
      style.firstLineHeadIndent = leftMargin
      style.headIndent = leftMargin
      style.alignment = .left

    case .parenthetical:
      // 30% left margin (19.5 characters)
      let leftMargin = charWidth * ScreenplayFormat.parentheticalLeftMarginChars
      style.firstLineHeadIndent = leftMargin
      style.headIndent = leftMargin
      style.alignment = .left

    case .transition:
      // Right-aligned
      style.alignment = .right

    case .sectionHeading(let level):
      // Markdown-style section headings
      style.firstLineHeadIndent = 0
      style.headIndent = 0
      style.alignment = .left
      // Add spacing before section headings
      if level <= 2 {
        style.paragraphSpacingBefore = fontSize * 2
      } else {
        style.paragraphSpacingBefore = fontSize
      }

    case .unorderedListItem(let level):
      // Markdown-style bullet lists
      let indent = charWidth * CGFloat(level * 2)  // 2 chars per level
      style.firstLineHeadIndent = indent
      style.headIndent = indent + charWidth * 2  // Hang indent
      style.alignment = .left

    case .orderedListItem(let level):
      // Markdown-style numbered lists
      let indent = charWidth * CGFloat(level * 2)  // 2 chars per level
      style.firstLineHeadIndent = indent
      style.headIndent = indent + charWidth * 3  // Hang indent (wider for numbers)
      style.alignment = .left

    case .comment:
      // Comments: slightly indented, gray
      style.firstLineHeadIndent = charWidth * 2
      style.headIndent = charWidth * 2
      style.alignment = .left

    case .pageBreak:
      // Page breaks: centered
      style.alignment = .center

    default:
      // Default to full width
      style.firstLineHeadIndent = 0
      style.headIndent = 0
      style.alignment = .left
    }

    return style
  }

  /// Create font and color for element type
  private static func createFontAndColor(for elementType: ElementType, baseFontSize: CGFloat) -> (
    PlatformFont, PlatformColor
  ) {
    switch elementType {
    case .sceneHeading:
      // Bold, 1.5x size, uppercase
      let size = baseFontSize * 1.5
      let font =
        PlatformFont(name: "Courier New Bold", size: size)
        ?? PlatformFont.monospacedSystemFont(ofSize: size, weight: .bold)
      #if os(iOS)
        return (font, PlatformColor.label)
      #elseif os(macOS)
        return (font, PlatformColor.labelColor)
      #endif

    case .character:
      // Bold, 0.75x size, uppercase
      let size = baseFontSize * 0.75
      let font =
        PlatformFont(name: "Courier New Bold", size: size)
        ?? PlatformFont.monospacedSystemFont(ofSize: size, weight: .heavy)
      #if os(iOS)
        return (font, PlatformColor.label)
      #elseif os(macOS)
        return (font, PlatformColor.labelColor)
      #endif

    case .sectionHeading(let level):
      // GitHub-style markdown headings
      let size: CGFloat
      let weight: PlatformFont.Weight

      switch level {
      case 1:
        size = baseFontSize * 2.0
        weight = .bold
      case 2:
        size = baseFontSize * 1.5
        weight = .bold
      case 3:
        size = baseFontSize * 1.25
        weight = .bold
      case 4:
        size = baseFontSize * 1.1
        weight = .semibold
      case 5:
        size = baseFontSize
        weight = .semibold
      default:
        size = baseFontSize * 0.9
        weight = .medium
      }

      let font = PlatformFont.monospacedSystemFont(ofSize: size, weight: weight)
      #if os(iOS)
        return (font, PlatformColor.label)
      #elseif os(macOS)
        return (font, PlatformColor.labelColor)
      #endif

    case .comment:
      // Gray, italic
      let font =
        PlatformFont(name: "Courier New Italic", size: baseFontSize)
        ?? PlatformFont.monospacedSystemFont(ofSize: baseFontSize, weight: .regular)
      #if os(iOS)
        return (font, PlatformColor.secondaryLabel)
      #elseif os(macOS)
        return (font, PlatformColor.secondaryLabelColor)
      #endif

    case .boneyard:
      // Strikethrough, gray
      let font =
        PlatformFont(name: "Courier New", size: baseFontSize)
        ?? PlatformFont.monospacedSystemFont(ofSize: baseFontSize, weight: .regular)
      #if os(iOS)
        return (font, PlatformColor.tertiaryLabel)
      #elseif os(macOS)
        return (font, PlatformColor.tertiaryLabelColor)
      #endif

    case .pageBreak:
      // Centered, gray
      let font =
        PlatformFont(name: "Courier New Bold", size: baseFontSize)
        ?? PlatformFont.monospacedSystemFont(ofSize: baseFontSize, weight: .bold)
      #if os(iOS)
        return (font, PlatformColor.secondaryLabel)
      #elseif os(macOS)
        return (font, PlatformColor.secondaryLabelColor)
      #endif

    default:
      // Standard Courier
      let font =
        PlatformFont(name: "Courier New", size: baseFontSize)
        ?? PlatformFont.monospacedSystemFont(ofSize: baseFontSize, weight: .regular)
      #if os(iOS)
        return (font, PlatformColor.label)
      #elseif os(macOS)
        return (font, PlatformColor.labelColor)
      #endif
    }
  }

  /// Determines spacing (matches GuionElementsList logic exactly)
  private static func shouldAddSpacing(element: GuionElementModel, nextElement: GuionElementModel?)
    -> Bool
  {
    // Action and synopsis always get spacing
    if element.elementType == .action || element.elementType == .synopsis {
      return true
    }

    // Dialogue group logic
    if element.elementType == .dialogue || element.elementType == .parenthetical
      || element.elementType == .lyrics
    {
      guard let next = nextElement else { return true }
      return next.elementType != .dialogue && next.elementType != .parenthetical
        && next.elementType != .lyrics
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
