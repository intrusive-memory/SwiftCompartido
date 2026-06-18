//
//  TestTags.swift
//  SwiftCompartido
//
//  Test tags for organizing test suites
//

import Testing

extension Tag {
  /// Tests that require Apple Intelligence to be enabled
  ///
  /// These tests:
  /// - Require iOS 26.2+ or macOS 26.0+
  /// - Require Apple Intelligence enabled in System Settings
  /// - Require M1+ Mac or A17 Pro+ device
  /// - Should NOT run in CI (Apple Intelligence unavailable in headless runners)
  /// - Run via ./Scripts/test-ai-features.sh
  @Tag static var ai: Self

  /// Tests for glosa annotation integration
  ///
  /// These tests verify:
  /// - SpeakableElement protocol conformance
  /// - Glosa annotation parsing and storage
  /// - Breath/pause offset handling
  /// - Integration with GlosaCore
  @Tag static var glosa: Self
}
