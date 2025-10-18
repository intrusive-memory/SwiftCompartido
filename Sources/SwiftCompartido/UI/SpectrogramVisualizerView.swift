//
//  SpectrogramVisualizerView.swift
//  SwiftHablare
//
//  Spectrogram-style audio visualizer component
//

import SwiftUI

/// Spectrogram-style audio visualizer
public struct SpectrogramVisualizerView: View {
    @ObservedObject var playerManager: AudioPlayerManager

    private let barCount: Int = 40
    private let barSpacing: CGFloat = 2
    @State private var audioHistory: [[Float]] = []

    public init(playerManager: AudioPlayerManager) {
        self.playerManager = playerManager
    }

    public var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let barWidth = (size.width - CGFloat(barCount - 1) * barSpacing) / CGFloat(barCount)

                // Draw historical audio levels (spectrogram effect)
                for (historyIndex, levels) in audioHistory.enumerated() {
                    let opacity = Double(historyIndex) / Double(max(audioHistory.count - 1, 1))

                    for (index, level) in levels.enumerated() {
                        let x = CGFloat(index) * (barWidth + barSpacing)
                        let height = CGFloat(level) * size.height * 0.8
                        let y = (size.height - height) / 2

                        let rect = CGRect(x: x, y: y, width: barWidth, height: height)

                        context.fill(
                            Path(roundedRect: rect, cornerRadius: barWidth / 2),
                            with: .color(.blue.opacity(opacity * 0.6))
                        )
                    }
                }

                // Draw current audio levels on top
                if !playerManager.audioLevels.isEmpty {
                    let normalizedLevels = normalizeToBarCount(playerManager.audioLevels)

                    for (index, level) in normalizedLevels.enumerated() {
                        let x = CGFloat(index) * (barWidth + barSpacing)
                        let height = CGFloat(level) * size.height * 0.8
                        let y = (size.height - height) / 2

                        let rect = CGRect(x: x, y: y, width: barWidth, height: height)

                        // Gradient for current levels
                        let gradient = Gradient(colors: [.blue, .cyan])

                        context.fill(
                            Path(roundedRect: rect, cornerRadius: barWidth / 2),
                            with: .linearGradient(
                                gradient,
                                startPoint: CGPoint(x: x, y: size.height),
                                endPoint: CGPoint(x: x, y: 0)
                            )
                        )
                    }
                }
            }
        }
        .frame(height: 80)
        .onChange(of: playerManager.audioLevels) { oldValue, newValue in
            updateAudioHistory(newValue)
        }
        .onAppear {
            audioHistory = []
        }
    }

    private func normalizeToBarCount(_ levels: [Float]) -> [Float] {
        guard !levels.isEmpty else {
            return Array(repeating: 0.1, count: barCount)
        }

        // If we have fewer levels than bars, interpolate
        if levels.count < barCount {
            var result: [Float] = []
            let ratio = Float(barCount) / Float(levels.count)

            for i in 0..<barCount {
                let sourceIndex = Int(Float(i) / ratio)
                let nextIndex = min(sourceIndex + 1, levels.count - 1)
                let t = (Float(i) / ratio) - Float(sourceIndex)

                let interpolated = levels[sourceIndex] * (1 - t) + levels[nextIndex] * t
                result.append(max(interpolated, 0.05))
            }

            return result
        }

        // If we have more levels than bars, average them
        var result: [Float] = []
        let chunkSize = levels.count / barCount

        for i in 0..<barCount {
            let start = i * chunkSize
            let end = min(start + chunkSize, levels.count)
            let chunk = Array(levels[start..<end])
            let average = chunk.reduce(0, +) / Float(chunk.count)
            result.append(max(average, 0.05))
        }

        return result
    }

    private func updateAudioHistory(_ newLevels: [Float]) {
        guard !newLevels.isEmpty else { return }

        let normalized = normalizeToBarCount(newLevels)
        audioHistory.append(normalized)

        // Keep only last 5 frames for the trailing effect
        if audioHistory.count > 5 {
            audioHistory.removeFirst()
        }
    }
}
