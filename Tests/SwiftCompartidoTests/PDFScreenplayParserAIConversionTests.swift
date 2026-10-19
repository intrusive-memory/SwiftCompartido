//
//  PDFScreenplayParserAIConversionTests.swift
//  SwiftCompartidoTests
//
//  The one test that exercises the real Apple Intelligence conversion path.
//
//  Skipped when SystemLanguageModel is unavailable, bounded by
//  PDFScreenplayParser.Options.aiPageTimeout, and listed in the Makefile's
//  CI_SKIP_AI so headless runners never attempt it. Runs on a dev Mac via
//  `make test` or Scripts/test-ai-features.sh.
//

import CoreGraphics
import CoreText
import Foundation
import Testing

@testable import SwiftCompartido

#if canImport(FoundationModels)
  import FoundationModels
#endif

private func appleIntelligenceAvailable() -> Bool {
  #if canImport(FoundationModels)
    return SystemLanguageModel.default.isAvailable
  #else
    return false
  #endif
}

@Suite(
  "PDF Parser AI Conversion (requires Apple Intelligence)",
  .tags(.ai),
  .enabled(if: appleIntelligenceAvailable(), "Apple Intelligence is not available on this machine")
)
struct PDFScreenplayParserAIConversionTests {

  /// A benign one-page screenplay rendered to PDF with CoreText.
  ///
  /// Synthesized rather than cut from a fixture: a page of BULLITT trips the model's
  /// safety guardrails (the request fails in ~20 s and the parser falls back), which
  /// exercises the bound but never a model answer. Short so the request stays well
  /// inside the per-page timeout.
  private func onePagePDFURL() throws -> URL {
    let pageText = """
      INT. CORNER CAFE - MORNING

      Sunlight through tall windows. MAYA, thirties, sketches in a notebook. A waiter, LEO, sets down a coffee.

      LEO
      Same as yesterday?

      MAYA
      Same as every day. Thank you.

      LEO
      One of these mornings you will surprise me.

      She smiles and goes back to her drawing.

      CUT TO:
      """

    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("ai-one-page-\(UUID().uuidString).pdf")
    var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
    let context = try #require(
      CGContext(url as CFURL, mediaBox: &mediaBox, nil), "could not create the PDF context")

    let font = CTFontCreateWithName("Courier" as CFString, 12, nil)
    let attributed = NSAttributedString(
      string: pageText, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
    let framesetter = CTFramesetterCreateWithAttributedString(attributed)
    let path = CGPath(rect: mediaBox.insetBy(dx: 72, dy: 72), transform: nil)
    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)

    context.beginPDFPage(nil)
    context.textMatrix = .identity
    CTFrameDraw(frame, context)
    context.endPDFPage()
    context.closePDF()
    return url
  }

  @Test("One page converts through the model within the per-page timeout")
  func testOnePageConvertsWithinTimeout() async throws {
    let url = try onePagePDFURL()
    defer { try? FileManager.default.removeItem(at: url) }

    let timeout: Duration = .seconds(30)
    let options = PDFScreenplayParser.Options(useAIConversion: true, aiPageTimeout: timeout)

    let clock = ContinuousClock()
    let started = clock.now
    let screenplay = try await PDFScreenplayParser.parse(from: url, options: options)
    let elapsed = clock.now - started

    #expect(screenplay.elements.count > 0, "the page should yield screenplay elements")
    // The model request is capped at `timeout`; extraction and Fountain parsing of one
    // page add well under a second. Anything beyond this means the bound did not hold.
    #expect(elapsed < timeout + .seconds(10), "parse took \(elapsed); the AI bound did not hold")
    print("AI one-page conversion took \(elapsed) for \(screenplay.elements.count) elements")
  }
}
