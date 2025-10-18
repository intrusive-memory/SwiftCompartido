//
//  TextConfigurationView.swift
//  SwiftHablare
//
//  Phase 7A: Configuration UI for text generation
//

import Foundation
import SwiftUI

/// Configuration view for text generation parameters.
///
/// Provides an intuitive interface for adjusting temperature, max tokens,
/// sampling parameters, and penalties for text generation models.
///
/// ## Usage
/// ```swift
/// @State private var config = TextGenerationConfig()
///
/// var body: some View {
///     TextConfigurationView(configuration: $config)
/// }
/// ```
@available(macOS 15.0, iOS 17.0, *)
public struct TextConfigurationView: View {

    /// Binding to the text generation configuration
    @Binding public var configuration: TextGenerationConfig

    /// Whether to show advanced options
    @State private var showAdvanced = false

    /// Creates a text configuration view
    ///
    /// - Parameter configuration: Binding to the configuration to edit
    public init(configuration: Binding<TextGenerationConfig>) {
        self._configuration = configuration
    }

    public var body: some View {
        Form {
            // Basic Settings
            Section("Basic Settings") {
                // Temperature
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Temperature")
                        Spacer()
                        Text(String(format: "%.2f", configuration.temperature))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $configuration.temperature, in: 0...2, step: 0.1)
                    Text("Higher values make output more random, lower values more focused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Max Tokens
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Max Tokens")
                        Spacer()
                        Text("\(configuration.maxTokens)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: Binding(
                        get: { Double(configuration.maxTokens) },
                        set: { configuration.maxTokens = Int($0) }
                    ), in: 1...4096, step: 1)
                    Text("Maximum number of tokens to generate (~750 words per 1000 tokens)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Advanced Settings
            DisclosureGroup("Advanced Settings", isExpanded: $showAdvanced) {
                VStack(alignment: .leading, spacing: 16) {
                    // Top-P
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Top-P (Nucleus Sampling)")
                            Spacer()
                            Text(String(format: "%.2f", configuration.topP))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $configuration.topP, in: 0...1, step: 0.05)
                        Text("Consider tokens with top-p cumulative probability")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Frequency Penalty
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Frequency Penalty")
                            Spacer()
                            Text(String(format: "%.2f", configuration.frequencyPenalty))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $configuration.frequencyPenalty, in: -2...2, step: 0.1)
                        Text("Reduce likelihood of repeating tokens based on frequency")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Presence Penalty
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Presence Penalty")
                            Spacer()
                            Text(String(format: "%.2f", configuration.presencePenalty))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $configuration.presencePenalty, in: -2...2, step: 0.1)
                        Text("Reduce likelihood of repeating any token that has appeared")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            // Optional Settings
            Section("Optional Settings") {
                // System Prompt
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Prompt")
                        .font(.headline)
                    TextEditor(text: Binding(
                        get: { configuration.systemPrompt ?? "" },
                        set: { configuration.systemPrompt = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(minHeight: 60)
                    .font(.body)
                    #if os(macOS)
                    .border(Color.secondary.opacity(0.2))
                    #endif
                    Text("Sets the behavior and context for the AI assistant")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Stop Sequences
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stop Sequences")
                        .font(.headline)
                    TextEditor(text: Binding(
                        get: { configuration.stopSequences?.joined(separator: "\n") ?? "" },
                        set: {
                            let sequences = $0.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
                            configuration.stopSequences = sequences.isEmpty ? nil : sequences
                        }
                    ))
                    .frame(minHeight: 60)
                    .font(.body.monospaced())
                    #if os(macOS)
                    .border(Color.secondary.opacity(0.2))
                    #endif
                    Text("One sequence per line. Generation stops when encountered.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Reset Button
            Section {
                Button("Reset to Defaults") {
                    configuration = TextGenerationConfig()
                    showAdvanced = false
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }
}

// MARK: - Previews

@available(macOS 15.0, iOS 17.0, *)
#Preview("Default Configuration") {
    @Previewable @State var config = TextGenerationConfig()
    return TextConfigurationView(configuration: $config)
        .frame(width: 500, height: 600)
}

@available(macOS 15.0, iOS 17.0, *)
#Preview("Custom Configuration") {
    @Previewable @State var config = TextGenerationConfig(
        temperature: 1.5,
        maxTokens: 1000,
        topP: 0.9,
        frequencyPenalty: 0.5,
        presencePenalty: 0.5,
        systemPrompt: "You are a helpful assistant.",
        stopSequences: ["END", "STOP"]
    )
    return TextConfigurationView(configuration: $config)
        .frame(width: 500, height: 600)
}
