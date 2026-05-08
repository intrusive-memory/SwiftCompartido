import SwiftUI

#if canImport(AppKit)
  import AppKit

  /// Example SwiftUI app demonstrating voice download integration
  ///
  /// This example shows how to:
  /// 1. Check if Premium voices are installed
  /// 2. Prompt user to download voices
  /// 3. Display voice status
  /// 4. Test voices with sample text
  ///
  /// Usage:
  /// Run this as a standalone macOS app or integrate into your app's settings.
  @available(macOS 26.0, *)
  struct VoiceDownloadExampleApp: App {
    var body: some Scene {
      WindowGroup {
        VoiceDownloadExampleView()
          .frame(minWidth: 600, minHeight: 400)
      }
    }
  }

  @available(macOS 26.0, *)
  struct VoiceDownloadExampleView: View {
    @State private var installedVoices: [String] = []
    @State private var currentVoice: String?
    @State private var isPremiumVoice: Bool = false
    @State private var showVoiceDownload: Bool = false
    @State private var testText: String =
      "The quick brown fox jumps over the lazy dog. This is a test of the Text-to-Speech system."

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          // Header
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Image(systemName: "speaker.wave.3.fill")
                .font(.largeTitle)
                .foregroundColor(.blue)

              VStack(alignment: .leading) {
                Text("Voice Download Manager")
                  .font(.title)
                Text("SwiftCompartido Example")
                  .font(.subheadline)
                  .foregroundColor(.secondary)
              }
            }
          }
          .padding()

          Divider()

          // Current Voice Status
          VStack(alignment: .leading, spacing: 12) {
            Label("Current System Voice", systemImage: "checkmark.circle.fill")
              .font(.headline)

            if let voice = currentVoice {
              VStack(alignment: .leading, spacing: 8) {
                Text(voice)
                  .font(.system(.body, design: .monospaced))
                  .padding(8)
                  .background(Color.secondary.opacity(0.1))
                  .cornerRadius(6)

                HStack {
                  Image(systemName: isPremiumVoice ? "star.fill" : "star")
                    .foregroundColor(isPremiumVoice ? .yellow : .gray)
                  Text(isPremiumVoice ? "Premium/Enhanced Quality" : "Standard Quality")
                    .font(.subheadline)
                    .foregroundColor(isPremiumVoice ? .primary : .secondary)
                }
              }
            } else {
              Text("No system voice configured")
                .foregroundColor(.secondary)
            }

            // Quick Actions
            HStack(spacing: 12) {
              Button("Refresh Status") {
                refreshVoiceStatus()
              }

              Button("Test Voice") {
                testCurrentVoice()
              }

              if !isPremiumVoice {
                Button("Download Premium Voices") {
                  showVoiceDownload = true
                }
                .buttonStyle(.borderedProminent)
              }
            }
          }
          .padding()
          .background(Color.secondary.opacity(0.05))
          .cornerRadius(12)

          // Installed Voices List
          VStack(alignment: .leading, spacing: 12) {
            Label("Installed Voices (\(installedVoices.count))", systemImage: "list.bullet")
              .font(.headline)

            if installedVoices.isEmpty {
              Text("No voices found")
                .foregroundColor(.secondary)
            } else {
              ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                  ForEach(installedVoices, id: \.self) { voice in
                    VoiceCard(voiceIdentifier: voice)
                  }
                }
                .padding(.horizontal, 4)
              }
            }
          }
          .padding()

          // Voice Test Section
          VStack(alignment: .leading, spacing: 12) {
            Label("Test Text-to-Speech", systemImage: "text.bubble")
              .font(.headline)

            TextEditor(text: $testText)
              .font(.body)
              .frame(height: 100)
              .padding(8)
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(8)

            HStack {
              Button {
                speakText(testText)
              } label: {
                Label("Speak", systemImage: "play.circle")
              }
              .buttonStyle(.borderedProminent)

              Button {
                stopSpeaking()
              } label: {
                Label("Stop", systemImage: "stop.circle")
              }
            }
          }
          .padding()
          .background(Color.secondary.opacity(0.05))
          .cornerRadius(12)

          // Info Section
          VStack(alignment: .leading, spacing: 8) {
            Label("About Premium Voices", systemImage: "info.circle")
              .font(.headline)

            Text(
              """
              Premium and Enhanced voices provide:
              • More natural intonation and prosody
              • Better handling of dialogue and character names
              • Neural TTS quality comparable to cloud services
              • Offline functionality (no internet required)

              Click "Download Premium Voices" to install high-quality voices for your language.
              """
            )
            .font(.subheadline)
            .foregroundColor(.secondary)
          }
          .padding()

          Spacer()
        }
        .padding()
      }
      .presentVoiceDownload(isPresented: $showVoiceDownload) { success in
        if success {
          // Refresh voice list after download
          DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            refreshVoiceStatus()
          }
        }
      }
      .onAppear {
        refreshVoiceStatus()
      }
    }

    // MARK: - Private Methods

    private func refreshVoiceStatus() {
      installedVoices = VoiceDownloadHelper.getInstalledVoices()
      currentVoice = VoiceDownloadHelper.getCurrentSystemVoice()
      isPremiumVoice = VoiceDownloadHelper.isUsingPremiumVoice()
    }

    private func testCurrentVoice() {
      let synthesizer = NSSpeechSynthesizer()
      synthesizer.startSpeaking("Hello! This is a test of the current system voice.")
    }

    private func speakText(_ text: String) {
      let synthesizer = NSSpeechSynthesizer()
      synthesizer.startSpeaking(text)
    }

    private func stopSpeaking() {
      let synthesizer = NSSpeechSynthesizer()
      synthesizer.stopSpeaking()
    }
  }

  /// Voice card displaying voice information
  @available(macOS 26.0, *)
  struct VoiceCard: View {
    let voiceIdentifier: String

    var body: some View {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Image(systemName: iconForVoice)
            .foregroundColor(colorForVoice)
          Text(voiceName)
            .font(.headline)
            .lineLimit(1)
        }

        Text(voiceQuality)
          .font(.caption)
          .foregroundColor(.secondary)

        if let language = voiceLanguage {
          Text(language)
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }
      .padding(12)
      .frame(width: 160)
      .background(Color.secondary.opacity(0.1))
      .cornerRadius(8)
    }

    private var voiceName: String {
      // Extract voice name from identifier
      // e.g., "com.apple.voice.premium.en-US.Jamie" → "Jamie"
      let components = voiceIdentifier.components(separatedBy: ".")
      return components.last ?? "Unknown"
    }

    private var voiceQuality: String {
      if voiceIdentifier.contains("premium") {
        return "Premium"
      } else if voiceIdentifier.contains("enhanced") {
        return "Enhanced"
      } else if voiceIdentifier.contains("compact") {
        return "Standard"
      } else {
        return "Unknown"
      }
    }

    private var voiceLanguage: String? {
      // Extract language code
      // e.g., "com.apple.voice.premium.en-US.Jamie" → "en-US"
      let components = voiceIdentifier.components(separatedBy: ".")
      if components.count >= 5 {
        return components[components.count - 2]
      }
      return nil
    }

    private var iconForVoice: String {
      switch voiceQuality {
      case "Premium":
        return "star.fill"
      case "Enhanced":
        return "star.leadinghalf.filled"
      default:
        return "speaker.wave.2"
      }
    }

    private var colorForVoice: Color {
      switch voiceQuality {
      case "Premium":
        return .yellow
      case "Enhanced":
        return .orange
      default:
        return .gray
      }
    }
  }

  // MARK: - Preview

  @available(macOS 26.0, *)
  #Preview {
    VoiceDownloadExampleView()
      .frame(width: 600, height: 800)
  }
#endif
