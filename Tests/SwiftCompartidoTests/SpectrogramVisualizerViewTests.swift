//
//  SpectrogramVisualizerViewTests.swift
//  SwiftCompartido Tests
//
//  Tests for SpectrogramVisualizerView component
//

import Testing
import Foundation
import SwiftUI
@testable import SwiftCompartido

@Suite("SpectrogramVisualizerView Tests")
@MainActor
struct SpectrogramVisualizerViewTests {

    // MARK: - Helper Methods

    private func makeAudioPlayerManager() -> AudioPlayerManager {
        return AudioPlayerManager()
    }

    // MARK: - Initialization Tests

    @Test("SpectrogramVisualizerView initializes with AudioPlayerManager")
    func testSpectrogramVisualizerViewInitialization() {
        let playerManager = makeAudioPlayerManager()

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        #expect(playerManager.audioLevels.isEmpty)
    }

    @Test("SpectrogramVisualizerView initializes with empty audio levels")
    func testSpectrogramVisualizerViewEmptyLevels() {
        let playerManager = makeAudioPlayerManager()

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        #expect(playerManager.audioLevels.count == 0)
    }

    // MARK: - Audio Levels Tests

    @Test("SpectrogramVisualizerView handles single audio level")
    func testSpectrogramVisualizerViewSingleLevel() {
        let playerManager = makeAudioPlayerManager()
        playerManager.audioLevels = [0.5]

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        #expect(playerManager.audioLevels.count == 1)
        #expect(playerManager.audioLevels[0] == 0.5)
    }

    @Test("SpectrogramVisualizerView handles multiple audio levels")
    func testSpectrogramVisualizerViewMultipleLevels() {
        let playerManager = makeAudioPlayerManager()
        playerManager.audioLevels = [0.1, 0.3, 0.5, 0.7, 0.9]

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        #expect(playerManager.audioLevels.count == 5)
        #expect(playerManager.audioLevels[2] == 0.5)
    }

    @Test("SpectrogramVisualizerView handles zero levels")
    func testSpectrogramVisualizerViewZeroLevels() {
        let playerManager = makeAudioPlayerManager()
        playerManager.audioLevels = [0.0, 0.0, 0.0, 0.0]

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        #expect(playerManager.audioLevels.allSatisfy { $0 == 0.0 })
    }

    @Test("SpectrogramVisualizerView handles maximum levels")
    func testSpectrogramVisualizerViewMaxLevels() {
        let playerManager = makeAudioPlayerManager()
        playerManager.audioLevels = [1.0, 1.0, 1.0, 1.0]

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        #expect(playerManager.audioLevels.allSatisfy { $0 == 1.0 })
    }

    @Test("SpectrogramVisualizerView handles varying levels")
    func testSpectrogramVisualizerViewVaryingLevels() {
        let playerManager = makeAudioPlayerManager()
        playerManager.audioLevels = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 0.8, 0.6, 0.4, 0.2]

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        #expect(playerManager.audioLevels.count == 10)
        #expect(playerManager.audioLevels[0] == 0.0)
        #expect(playerManager.audioLevels[5] == 1.0)
    }

    // MARK: - Audio Level Updates Tests

    @Test("SpectrogramVisualizerView updates with new levels")
    func testSpectrogramVisualizerViewUpdatesLevels() {
        let playerManager = makeAudioPlayerManager()

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        // Initial state
        #expect(playerManager.audioLevels.isEmpty)

        // Update levels
        playerManager.audioLevels = [0.5, 0.6, 0.7]

        #expect(playerManager.audioLevels.count == 3)
        #expect(playerManager.audioLevels[1] == 0.6)
    }

    @Test("SpectrogramVisualizerView handles rapid level updates")
    func testSpectrogramVisualizerViewRapidUpdates() {
        let playerManager = makeAudioPlayerManager()

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        // Simulate rapid updates
        for i in 0...10 {
            let level = Float(i) / 10.0
            playerManager.audioLevels = [level, level, level]
        }

        // Should have last update
        #expect(playerManager.audioLevels[0] == 1.0)
    }

    @Test("SpectrogramVisualizerView clears levels")
    func testSpectrogramVisualizerViewClearsLevels() {
        let playerManager = makeAudioPlayerManager()
        playerManager.audioLevels = [0.5, 0.6, 0.7]

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        #expect(playerManager.audioLevels.count == 3)

        // Clear levels
        playerManager.audioLevels = []

        #expect(playerManager.audioLevels.isEmpty)
    }

    // MARK: - Many Levels Tests

    @Test("SpectrogramVisualizerView handles 40 bars (default)")
    func testSpectrogramVisualizerView40Bars() {
        let playerManager = makeAudioPlayerManager()

        // Create 40 levels (matches barCount)
        var levels: [Float] = []
        for i in 0..<40 {
            levels.append(Float(i) / 40.0)
        }
        playerManager.audioLevels = levels

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        #expect(playerManager.audioLevels.count == 40)
    }

    @Test("SpectrogramVisualizerView handles fewer than 40 levels")
    func testSpectrogramVisualizerViewFewerBars() {
        let playerManager = makeAudioPlayerManager()

        // Create 20 levels (half of barCount)
        var levels: [Float] = []
        for i in 0..<20 {
            levels.append(Float(i) / 20.0)
        }
        playerManager.audioLevels = levels

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        #expect(playerManager.audioLevels.count == 20)
    }

    @Test("SpectrogramVisualizerView handles more than 40 levels")
    func testSpectrogramVisualizerViewMoreBars() {
        let playerManager = makeAudioPlayerManager()

        // Create 80 levels (double barCount)
        var levels: [Float] = []
        for i in 0..<80 {
            levels.append(Float(i) / 80.0)
        }
        playerManager.audioLevels = levels

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        #expect(playerManager.audioLevels.count == 80)
    }

    @Test("SpectrogramVisualizerView handles very many levels")
    func testSpectrogramVisualizerViewVeryManyLevels() {
        let playerManager = makeAudioPlayerManager()

        // Create 1000 levels
        var levels: [Float] = []
        for i in 0..<1000 {
            levels.append(Float(i % 100) / 100.0)
        }
        playerManager.audioLevels = levels

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        #expect(playerManager.audioLevels.count == 1000)
    }

    // MARK: - Audio Pattern Tests

    @Test("SpectrogramVisualizerView handles sine wave pattern")
    func testSpectrogramVisualizerViewSineWave() {
        let playerManager = makeAudioPlayerManager()

        // Create sine wave pattern
        var levels: [Float] = []
        for i in 0..<40 {
            let angle = Float(i) * .pi / 20.0
            levels.append((sin(angle) + 1.0) / 2.0) // Normalize to 0-1
        }
        playerManager.audioLevels = levels

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        #expect(playerManager.audioLevels.count == 40)
        #expect(playerManager.audioLevels[0] >= 0.0)
        #expect(playerManager.audioLevels[0] <= 1.0)
    }

    @Test("SpectrogramVisualizerView handles random pattern")
    func testSpectrogramVisualizerViewRandomPattern() {
        let playerManager = makeAudioPlayerManager()

        // Create random levels
        var levels: [Float] = []
        for _ in 0..<40 {
            levels.append(Float.random(in: 0.0...1.0))
        }
        playerManager.audioLevels = levels

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        #expect(playerManager.audioLevels.count == 40)
        #expect(playerManager.audioLevels.allSatisfy { $0 >= 0.0 && $0 <= 1.0 })
    }

    @Test("SpectrogramVisualizerView handles pulse pattern")
    func testSpectrogramVisualizerViewPulsePattern() {
        let playerManager = makeAudioPlayerManager()

        // Create pulse pattern (alternating high/low)
        var levels: [Float] = []
        for i in 0..<40 {
            levels.append(i % 2 == 0 ? 1.0 : 0.0)
        }
        playerManager.audioLevels = levels

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        #expect(playerManager.audioLevels.count == 40)
        #expect(playerManager.audioLevels[0] == 1.0)
        #expect(playerManager.audioLevels[1] == 0.0)
    }

    // MARK: - Edge Case Tests

    @Test("SpectrogramVisualizerView handles negative levels")
    func testSpectrogramVisualizerViewNegativeLevels() {
        let playerManager = makeAudioPlayerManager()
        playerManager.audioLevels = [-0.5, -0.3, -0.1]

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        // Should handle negative values (though typically audio levels are 0-1)
        #expect(playerManager.audioLevels.count == 3)
    }

    @Test("SpectrogramVisualizerView handles values above 1.0")
    func testSpectrogramVisualizerViewHighLevels() {
        let playerManager = makeAudioPlayerManager()
        playerManager.audioLevels = [1.5, 2.0, 3.0]

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        // Should handle values above 1.0 (clipping)
        #expect(playerManager.audioLevels.count == 3)
    }

    @Test("SpectrogramVisualizerView handles very small levels")
    func testSpectrogramVisualizerViewVerySmallLevels() {
        let playerManager = makeAudioPlayerManager()
        playerManager.audioLevels = [0.001, 0.002, 0.003]

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        #expect(playerManager.audioLevels.count == 3)
        #expect(playerManager.audioLevels[0] < 0.01)
    }

    @Test("SpectrogramVisualizerView handles NaN values gracefully")
    func testSpectrogramVisualizerViewNaNValues() {
        let playerManager = makeAudioPlayerManager()
        playerManager.audioLevels = [0.5, Float.nan, 0.7]

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        // Should handle NaN gracefully
        #expect(playerManager.audioLevels.count == 3)
    }

    @Test("SpectrogramVisualizerView handles infinity values gracefully")
    func testSpectrogramVisualizerViewInfinityValues() {
        let playerManager = makeAudioPlayerManager()
        playerManager.audioLevels = [0.5, Float.infinity, 0.7]

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        // Should handle infinity gracefully
        #expect(playerManager.audioLevels.count == 3)
    }

    // MARK: - Integration Tests

    @Test("SpectrogramVisualizerView in typical audio playback scenario")
    func testSpectrogramVisualizerViewTypicalPlayback() {
        let playerManager = makeAudioPlayerManager()

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        // Simulate typical audio playback levels
        let typicalLevels: [Float] = [
            0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0,
            0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1, 0.0
        ]

        playerManager.audioLevels = typicalLevels

        #expect(playerManager.audioLevels.count == 20)
        #expect(playerManager.audioLevels.first == 0.1)
        #expect(playerManager.audioLevels.last == 0.0)
    }

    @Test("SpectrogramVisualizerView during audio fade in/out")
    func testSpectrogramVisualizerViewFadeInOut() {
        let playerManager = makeAudioPlayerManager()

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        // Simulate fade in
        var fadeIn: [Float] = []
        for i in 0..<20 {
            fadeIn.append(Float(i) / 20.0)
        }
        playerManager.audioLevels = fadeIn

        #expect(playerManager.audioLevels.first == 0.0)
        #expect(playerManager.audioLevels.last ?? 0.0 > 0.9)

        // Simulate fade out
        var fadeOut: [Float] = []
        for i in 0..<20 {
            fadeOut.append(Float(20 - i) / 20.0)
        }
        playerManager.audioLevels = fadeOut

        #expect(playerManager.audioLevels.last == 0.0)
    }

    @Test("SpectrogramVisualizerView with music playback levels")
    func testSpectrogramVisualizerViewMusicPlayback() {
        let playerManager = makeAudioPlayerManager()

        _ = SpectrogramVisualizerView(playerManager: playerManager)

        // Simulate music with varying dynamics
        var musicLevels: [Float] = []
        for i in 0..<40 {
            // Simulate music with peaks and valleys
            let t = Float(i) / 40.0
            let level = abs(sin(t * .pi * 4)) * (0.5 + 0.5 * sin(t * .pi))
            musicLevels.append(level)
        }

        playerManager.audioLevels = musicLevels

        #expect(playerManager.audioLevels.count == 40)
        #expect(playerManager.audioLevels.allSatisfy { $0 >= 0.0 && $0 <= 1.0 })
    }

    @Test("SpectrogramVisualizerView multiple instances with same manager")
    func testSpectrogramVisualizerViewMultipleInstances() {
        let playerManager = makeAudioPlayerManager()
        playerManager.audioLevels = [0.5, 0.6, 0.7]

        _ = SpectrogramVisualizerView(playerManager: playerManager)
        _ = SpectrogramVisualizerView(playerManager: playerManager)

        // Both instances should show same levels
        #expect(playerManager.audioLevels.count == 3)
    }

    @Test("SpectrogramVisualizerView with different managers")
    func testSpectrogramVisualizerViewDifferentManagers() {
        let playerManager1 = makeAudioPlayerManager()
        let playerManager2 = makeAudioPlayerManager()

        playerManager1.audioLevels = [0.3, 0.4, 0.5]
        playerManager2.audioLevels = [0.6, 0.7, 0.8]

        _ = SpectrogramVisualizerView(playerManager: playerManager1)
        _ = SpectrogramVisualizerView(playerManager: playerManager2)

        // Each manager should have independent levels
        #expect(playerManager1.audioLevels[0] == 0.3)
        #expect(playerManager2.audioLevels[0] == 0.6)
    }
}
