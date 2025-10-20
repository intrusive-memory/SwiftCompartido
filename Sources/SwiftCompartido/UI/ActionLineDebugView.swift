//
//  ActionLineDebugView.swift
//  SwiftCompartido
//
//  Standalone test view for debugging action line truncation
//

import SwiftUI

/// DEBUG: Standalone view for testing action line rendering
public struct ActionLineDebugView: View {
    @State private var testText = """
    Bernard and Killian sit in a steam room at an upscale gym. The heat is oppressive, sweat dripping down their faces. They sit in silence for a moment, the tension palpable.
    """

    @State private var fontSize: CGFloat = 12
    @State private var useDebugView = true

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Controls
                GroupBox("Debug Controls") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Use Debug View (with colored backgrounds)", isOn: $useDebugView)

                        HStack {
                            Text("Font Size: \(Int(fontSize))pt")
                            Slider(value: $fontSize, in: 8...24, step: 1)
                        }

                        Text("Test Text:")
                            .font(.caption.bold())
                        TextEditor(text: $testText)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(height: 120)
                            .border(Color.gray.opacity(0.3))
                    }
                    .padding(8)
                }
                .padding()

                Divider()

                // Test Renders
                GroupBox("Action View Rendering") {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Current ActionView:")
                            .font(.headline)

                        if useDebugView {
                            ActionViewDebug(
                                element: GuionElementModel(
                                    elementText: testText,
                                    elementType: .action
                                )
                            )
                            .environment(\.screenplayFontSize, fontSize)
                        } else {
                            ActionView(
                                element: GuionElementModel(
                                    elementText: testText,
                                    elementType: .action
                                )
                            )
                            .environment(\.screenplayFontSize, fontSize)
                            .border(Color.blue, width: 1)
                        }

                        Divider()

                        Text("For Comparison - DialogueTextView:")
                            .font(.headline)

                        DialogueTextView(
                            element: GuionElementModel(
                                elementText: testText,
                                elementType: .dialogue
                            )
                        )
                        .environment(\.screenplayFontSize, fontSize)
                        .border(Color.green, width: 1)

                        Divider()

                        Text("Plain Text (no GeometryReader):")
                            .font(.headline)

                        Text(testText)
                            .font(.custom("Courier New", size: fontSize))
                            .padding(.horizontal, 40)
                            .border(Color.orange, width: 1)
                    }
                    .padding()
                }
                .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 800)
    }
}

// Preview
#Preview {
    ActionLineDebugView()
}
