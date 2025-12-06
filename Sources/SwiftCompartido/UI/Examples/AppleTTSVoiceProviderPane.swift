import Foundation
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Opens the most relevant system settings page for downloading premium voices.
/// - Returns: `true` if the system accepted a URL to open; `false` if we could only open the
///   app's settings (iOS) or nothing at all.
@MainActor
@discardableResult
public func openVoiceSettings() -> Bool {
    #if os(macOS)
    // Primary: jump straight to Accessibility ▸ Spoken Content
    let anchors = [
        "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?SpokenContent",
        // Fallback: Accessibility root if the anchor changes
        "x-apple.systempreferences:com.apple.Accessibility-Settings.extension",
        // Last-ditch: open System Settings app
        "x-apple.systempreferences:com.apple.preference.universalaccess"
    ]

    for raw in anchors {
        if let url = URL(string: raw), NSWorkspace.shared.open(url) {
            return true
        }
    }
    return false

    #elseif targetEnvironment(macCatalyst)
    // Catalyst: opening the macOS System Settings deep link usually works.
    let macLinks = [
        "x-apple.systempreferences:com.apple.Accessibility-Settings.extension?SpokenContent",
        "x-apple.systempreferences:com.apple.Accessibility-Settings.extension"
    ]
    for raw in macLinks {
        if let url = URL(string: raw), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return true
        }
    }
    // Fallback (Catalyst behaves like iOS for this): open this app's Settings pane
    if let url = URL(string: UIApplication.openSettingsURLString),
       UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url)
        return false // opened app settings, not the target pane
    }
    return false

    #else // iOS
    // iOS cannot deep-link to Accessibility subpages via public APIs.
    // Best we can do is open this app's Settings so you can show guidance in-app.
    if let url = URL(string: UIApplication.openSettingsURLString),
       UIApplication.shared.canOpenURL(url) {
        UIApplication.shared.open(url)
        return false
    }
    return false
    #endif
}

/// Configuration pane for the Apple TTS voice provider.
///
/// Presents provider details, requirements, and a Configure button that opens the
/// appropriate system settings screen for managing premium voices.
public struct AppleTTSVoiceProviderPane: View {
    /// Indicates whether we should show fallback guidance when we cannot deep link
    @State private var showFallbackAlert = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Apple TTS Voice Provider")
                    .font(.title2)
                    .bold()

                Text("Use Apple's premium system voices for dialogue playback and narration.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Requires macOS 26 or iOS 26 with Apple Intelligence enabled", systemImage: "info.circle")
                    .font(.subheadline)
                Label("Download high-quality voices from System Settings ▸ Accessibility ▸ Spoken Content", systemImage: "waveform")
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)

            Button {
                let opened = openVoiceSettings()
                if !opened {
                    showFallbackAlert = true
                }
            } label: {
                Label("Configure", systemImage: "gear")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Text("After downloading voices, return here to assign them to characters or scenes.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .alert("Open Voice Settings Manually", isPresented: $showFallbackAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(fallbackMessage)
        }
    }

    private var fallbackMessage: String {
        #if os(macOS)
        return "System Settings did not open automatically. Open System Settings ▸ Accessibility ▸ Spoken Content manually to download additional voices."
        #elseif targetEnvironment(macCatalyst)
        return "We opened the app settings. If Spoken Content does not appear automatically, open System Settings on your Mac ▸ Accessibility ▸ Spoken Content to manage voices."
        #else
        return "We opened this app's Settings screen. Navigate to Accessibility ▸ Spoken Content to download the voices you need."
        #endif
    }
}

#Preview {
    AppleTTSVoiceProviderPane()
        .padding()
}
