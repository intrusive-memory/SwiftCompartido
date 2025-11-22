//
//  GitAttributesParserTests.swift
//  SwiftCompartidoTests
//
//  Tests for .gitattributes parser for Git LFS configuration.
//

import Testing
import Foundation
@testable import SwiftCompartido

@Suite("Git Attributes Parser Tests")
struct GitAttributesParserTests {

    // MARK: - Helper Methods

    private func createTemporaryDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitAttributesParserTests-\(UUID().uuidString)")

        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    private func cleanupTemporaryDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Parsing Tests

    @Test("Parse empty file")
    func testParseEmptyFile() throws {
        let parser = GitAttributesParser()
        let lines = try parser.parseContent("")

        #expect(lines.isEmpty)
    }

    @Test("Parse file with comments only")
    func testParseCommentsOnly() throws {
        let content = """
        # This is a comment
        # Another comment

        # More comments
        """

        let parser = GitAttributesParser()
        let lines = try parser.parseContent(content)

        #expect(lines.isEmpty)
    }

    @Test("Parse LFS pattern")
    func testParseLFSPattern() throws {
        let content = "*.mp3 filter=lfs diff=lfs merge=lfs -text"

        let parser = GitAttributesParser()
        let lines = try parser.parseContent(content)

        #expect(lines.count == 1)
        #expect(lines[0].pattern == "*.mp3")
        #expect(lines[0].attributes == "filter=lfs diff=lfs merge=lfs -text")
        #expect(lines[0].isLFS == true)
    }

    @Test("Parse multiple patterns")
    func testParseMultiplePatterns() throws {
        let content = """
        *.mp3 filter=lfs diff=lfs merge=lfs -text
        *.wav filter=lfs diff=lfs merge=lfs -text
        *.pdf filter=lfs diff=lfs merge=lfs -text
        """

        let parser = GitAttributesParser()
        let lines = try parser.parseContent(content)

        #expect(lines.count == 3)
        #expect(lines[0].pattern == "*.mp3")
        #expect(lines[1].pattern == "*.wav")
        #expect(lines[2].pattern == "*.pdf")
        #expect(lines.allSatisfy { $0.isLFS })
    }

    @Test("Parse mixed content with comments")
    func testParseMixedContent() throws {
        let content = """
        # Audio files
        *.mp3 filter=lfs diff=lfs merge=lfs -text

        # Video files
        *.mp4 filter=lfs diff=lfs merge=lfs -text

        # Other files
        *.txt text
        """

        let parser = GitAttributesParser()
        let lines = try parser.parseContent(content)

        #expect(lines.count == 3)
        #expect(lines[0].pattern == "*.mp3")
        #expect(lines[1].pattern == "*.mp4")
        #expect(lines[2].pattern == "*.txt")
        #expect(lines[0].isLFS == true)
        #expect(lines[1].isLFS == true)
        #expect(lines[2].isLFS == false)
    }

    @Test("Parse file from disk")
    func testParseFileFromDisk() throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let fileURL = tempDir.appendingPathComponent(".gitattributes")
        let content = """
        *.mp3 filter=lfs diff=lfs merge=lfs -text
        *.wav filter=lfs diff=lfs merge=lfs -text
        """

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let parser = GitAttributesParser()
        let lines = try parser.parseFile(at: fileURL)

        #expect(lines.count == 2)
        #expect(lines[0].pattern == "*.mp3")
        #expect(lines[1].pattern == "*.wav")
    }

    @Test("Parse nonexistent file throws error")
    func testParseNonexistentFile() {
        let parser = GitAttributesParser()
        let nonexistentURL = URL(fileURLWithPath: "/nonexistent/.gitattributes")

        #expect(throws: GitAttributesParser.ParsingError.self) {
            try parser.parseFile(at: nonexistentURL)
        }
    }

    // MARK: - LFS Pattern Extraction Tests

    @Test("Get LFS patterns only")
    func testGetLFSPatternsOnly() throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let fileURL = tempDir.appendingPathComponent(".gitattributes")
        let content = """
        *.mp3 filter=lfs diff=lfs merge=lfs -text
        *.txt text
        *.wav filter=lfs diff=lfs merge=lfs -text
        *.md text
        """

        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let parser = GitAttributesParser()
        let lfsPatterns = try parser.getLFSPatterns(from: fileURL)

        #expect(lfsPatterns.count == 2)
        #expect(lfsPatterns.contains("*.mp3"))
        #expect(lfsPatterns.contains("*.wav"))
        #expect(!lfsPatterns.contains("*.txt"))
        #expect(!lfsPatterns.contains("*.md"))
    }

    // MARK: - Writing Tests

    @Test("Write default LFS patterns")
    func testWriteDefaultLFSPatterns() throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let fileURL = tempDir.appendingPathComponent(".gitattributes")

        let parser = GitAttributesParser()
        try parser.writeDefaultLFSPatterns(to: fileURL)

        // Verify file was created
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        // Verify content
        let lines = try parser.parseFile(at: fileURL)
        #expect(lines.count > 0)
        #expect(lines.allSatisfy { $0.isLFS })

        // Verify specific patterns exist
        let patterns = lines.map { $0.pattern }
        #expect(patterns.contains("*.mp3"))
        #expect(patterns.contains("*.wav"))
        #expect(patterns.contains("*.mp4"))
        #expect(patterns.contains("*.png"))
        #expect(patterns.contains("*.pdf"))
    }

    @Test("Add LFS pattern to new file")
    func testAddPatternToNewFile() throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let fileURL = tempDir.appendingPathComponent(".gitattributes")

        let parser = GitAttributesParser()
        try parser.addLFSPattern("*.mp3", to: fileURL)

        // Verify file was created
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        // Verify content
        let lines = try parser.parseFile(at: fileURL)
        #expect(lines.count == 1)
        #expect(lines[0].pattern == "*.mp3")
        #expect(lines[0].isLFS == true)
    }

    @Test("Add LFS pattern to existing file")
    func testAddPatternToExistingFile() throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let fileURL = tempDir.appendingPathComponent(".gitattributes")

        // Create initial file
        let initialContent = "*.mp3 filter=lfs diff=lfs merge=lfs -text"
        try initialContent.write(to: fileURL, atomically: true, encoding: .utf8)

        // Add new pattern
        let parser = GitAttributesParser()
        try parser.addLFSPattern("*.wav", to: fileURL)

        // Verify both patterns exist
        let lines = try parser.parseFile(at: fileURL)
        #expect(lines.count == 2)
        #expect(lines.map { $0.pattern }.contains("*.mp3"))
        #expect(lines.map { $0.pattern }.contains("*.wav"))
    }

    @Test("Add duplicate pattern is idempotent")
    func testAddDuplicatePattern() throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let fileURL = tempDir.appendingPathComponent(".gitattributes")

        let parser = GitAttributesParser()
        try parser.addLFSPattern("*.mp3", to: fileURL)
        try parser.addLFSPattern("*.mp3", to: fileURL) // Add again

        // Verify only one pattern exists
        let lines = try parser.parseFile(at: fileURL)
        #expect(lines.count == 1)
        #expect(lines[0].pattern == "*.mp3")
    }

    @Test("Add empty pattern throws error")
    func testAddEmptyPattern() {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let fileURL = tempDir.appendingPathComponent(".gitattributes")

        let parser = GitAttributesParser()

        #expect(throws: GitAttributesParser.ParsingError.self) {
            try parser.addLFSPattern("", to: fileURL)
        }
    }

    // MARK: - Removal Tests

    @Test("Remove LFS pattern")
    func testRemovePattern() throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let fileURL = tempDir.appendingPathComponent(".gitattributes")

        let initialContent = """
        *.mp3 filter=lfs diff=lfs merge=lfs -text
        *.wav filter=lfs diff=lfs merge=lfs -text
        *.pdf filter=lfs diff=lfs merge=lfs -text
        """
        try initialContent.write(to: fileURL, atomically: true, encoding: .utf8)

        // Remove pattern
        let parser = GitAttributesParser()
        try parser.removeLFSPattern("*.wav", from: fileURL)

        // Verify pattern was removed
        let lines = try parser.parseFile(at: fileURL)
        #expect(lines.count == 2)
        #expect(lines.map { $0.pattern }.contains("*.mp3"))
        #expect(lines.map { $0.pattern }.contains("*.pdf"))
        #expect(!lines.map { $0.pattern }.contains("*.wav"))
    }

    @Test("Remove pattern from nonexistent file is noop")
    func testRemoveFromNonexistentFile() throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let fileURL = tempDir.appendingPathComponent(".gitattributes")

        let parser = GitAttributesParser()
        // Should not throw
        try parser.removeLFSPattern("*.mp3", from: fileURL)
    }

    @Test("Remove pattern preserves comments")
    func testRemovePreservesComments() throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let fileURL = tempDir.appendingPathComponent(".gitattributes")

        let initialContent = """
        # Audio files
        *.mp3 filter=lfs diff=lfs merge=lfs -text
        *.wav filter=lfs diff=lfs merge=lfs -text
        """
        try initialContent.write(to: fileURL, atomically: true, encoding: .utf8)

        // Remove pattern
        let parser = GitAttributesParser()
        try parser.removeLFSPattern("*.mp3", from: fileURL)

        // Verify comment is preserved
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(content.contains("# Audio files"))
    }

    // MARK: - Pattern Tracking Tests

    @Test("Check if pattern is tracked")
    func testIsPatternTracked() throws {
        let tempDir = createTemporaryDirectory()
        defer { cleanupTemporaryDirectory(tempDir) }

        let fileURL = tempDir.appendingPathComponent(".gitattributes")

        let content = """
        *.mp3 filter=lfs diff=lfs merge=lfs -text
        *.wav filter=lfs diff=lfs merge=lfs -text
        """
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let parser = GitAttributesParser()

        #expect(try parser.isPatternTracked("*.mp3", in: fileURL) == true)
        #expect(try parser.isPatternTracked("*.wav", in: fileURL) == true)
        #expect(try parser.isPatternTracked("*.pdf", in: fileURL) == false)
    }

    @Test("Check pattern in nonexistent file returns false")
    func testIsPatternTrackedNonexistentFile() throws {
        let parser = GitAttributesParser()
        let nonexistentURL = URL(fileURLWithPath: "/nonexistent/.gitattributes")

        #expect(try parser.isPatternTracked("*.mp3", in: nonexistentURL) == false)
    }

    // MARK: - AttributeLine Tests

    @Test("AttributeLine equality")
    func testAttributeLineEquality() {
        let line1 = GitAttributesParser.AttributeLine(
            pattern: "*.mp3",
            attributes: "filter=lfs diff=lfs merge=lfs -text"
        )

        let line2 = GitAttributesParser.AttributeLine(
            pattern: "*.mp3",
            attributes: "filter=lfs diff=lfs merge=lfs -text"
        )

        let line3 = GitAttributesParser.AttributeLine(
            pattern: "*.wav",
            attributes: "filter=lfs diff=lfs merge=lfs -text"
        )

        #expect(line1 == line2)
        #expect(line1 != line3)
    }

    @Test("AttributeLine isLFS detection")
    func testIsLFSDetection() {
        let lfsLine = GitAttributesParser.AttributeLine(
            pattern: "*.mp3",
            attributes: "filter=lfs diff=lfs merge=lfs -text"
        )

        let nonLFSLine = GitAttributesParser.AttributeLine(
            pattern: "*.txt",
            attributes: "text"
        )

        #expect(lfsLine.isLFS == true)
        #expect(nonLFSLine.isLFS == false)
    }

    // MARK: - Error Description Tests

    @Test("File not found error description")
    func testFileNotFoundErrorDescription() {
        let error = GitAttributesParser.ParsingError.fileNotFound(path: "/path/to/file")
        #expect(error.errorDescription?.contains("not found") == true)
        #expect(error.errorDescription?.contains("/path/to/file") == true)
    }

    @Test("Invalid format error description")
    func testInvalidFormatErrorDescription() {
        let error = GitAttributesParser.ParsingError.invalidFormat(line: "bad line")
        #expect(error.errorDescription?.contains("Invalid") == true)
        #expect(error.errorDescription?.contains("bad line") == true)
    }

    @Test("Write failed error description")
    func testWriteFailedErrorDescription() {
        let error = GitAttributesParser.ParsingError.writeFailed(reason: "Permission denied")
        #expect(error.errorDescription?.contains("Failed to write") == true)
        #expect(error.errorDescription?.contains("Permission denied") == true)
    }

    @Test("Invalid pattern error description")
    func testInvalidPatternErrorDescription() {
        let error = GitAttributesParser.ParsingError.invalidPattern(pattern: "bad*pattern")
        #expect(error.errorDescription?.contains("Invalid") == true)
        #expect(error.errorDescription?.contains("bad*pattern") == true)
    }

    // MARK: - Default Patterns Tests

    @Test("Default patterns include multimedia types")
    func testDefaultPatternsCompleteness() {
        let patterns = GitAttributesParser.defaultLFSPatterns

        // Audio
        #expect(patterns.contains("*.mp3"))
        #expect(patterns.contains("*.wav"))
        #expect(patterns.contains("*.m4a"))

        // Video
        #expect(patterns.contains("*.mp4"))
        #expect(patterns.contains("*.mov"))

        // Images
        #expect(patterns.contains("*.png"))
        #expect(patterns.contains("*.jpg"))

        // PDF
        #expect(patterns.contains("*.pdf"))
    }

    @Test("LFS attributes constant is correct")
    func testLFSAttributesConstant() {
        #expect(GitAttributesParser.lfsAttributes == "filter=lfs diff=lfs merge=lfs -text")
    }
}
