//
//  FDXDocumentWriter.swift
//  SwiftFountain
//

import Foundation
#if canImport(SwiftData)

public enum FDXDocumentWriter {
    private static let header = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>\n"

    public static func makeFDX(from model: GuionDocumentModel) -> Data {
        var xml = header
        xml += "<FinalDraft DocumentType=\"Script\" Template=\"No\" Version=\"4\">\n"
        xml += "  <Content>\n"

        for element in model.elements {
            xml += paragraphXML(for: element)
        }

        xml += "  </Content>\n"
        xml += titlePageXML(from: model)
        xml += "</FinalDraft>\n"

        return Data(xml.utf8)
    }

    /// Write a GuionParsedElementCollection to FDX format
    /// - Parameter screenplay: The screenplay to export
    /// - Returns: FDX XML data
    public static func write(_ screenplay: GuionParsedElementCollection) -> Data {
        var xml = header
        xml += "<FinalDraft DocumentType=\"Script\" Template=\"No\" Version=\"4\">\n"
        xml += "  <Content>\n"

        for element in screenplay.elements {
            xml += paragraphXML(for: element)
        }

        xml += "  </Content>\n"
        xml += titlePageXML(from: screenplay)
        xml += "</FinalDraft>\n"

        return Data(xml.utf8)
    }

    private static func paragraphXML(for element: GuionElementModel) -> String {
        var paragraph = "    <Paragraph Type=\"\(escape(element.elementType.description))\">\n"

        if let sceneNumber = element.sceneNumber, element.elementType == .sceneHeading {
            paragraph += "      <SceneProperties Number=\"\(escape(sceneNumber))\"/>\n"
        }

        let text = escape(element.elementText)
        paragraph += "      <Text>\(text)</Text>\n"
        paragraph += "    </Paragraph>\n"
        return paragraph
    }

    private static func paragraphXML(for element: GuionElement) -> String {
        var paragraph = "    <Paragraph Type=\"\(escape(element.elementType.description))\">\n"

        if let sceneNumber = element.sceneNumber, element.elementType == .sceneHeading {
            paragraph += "      <SceneProperties Number=\"\(escape(sceneNumber))\"/>\n"
        }

        let text = escape(element.elementText)
        paragraph += "      <Text>\(text)</Text>\n"
        paragraph += "    </Paragraph>\n"
        return paragraph
    }

    private static func titlePageXML(from model: GuionDocumentModel) -> String {
        guard !model.titlePage.isEmpty else {
            return "  <TitlePage>\n    <Content/>\n  </TitlePage>\n"
        }

        var xml = "  <TitlePage>\n"
        xml += "    <Content>\n"

        for entry in model.titlePage {
            for value in entry.values {
                guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                xml += "      <Paragraph Alignment=\"Center\" FirstIndent=\"0.00\" Leading=\"Regular\" LeftIndent=\"1.00\" RightIndent=\"7.50\" SpaceBefore=\"0\" Spacing=\"1\" StartsNewPage=\"No\">\n"
                xml += "        <Text>\(escape(value))</Text>\n"
                xml += "      </Paragraph>\n"
            }
        }

        xml += "    </Content>\n"
        xml += "  </TitlePage>\n"
        return xml
    }

    private static func titlePageXML(from screenplay: GuionParsedElementCollection) -> String {
        guard !screenplay.titlePage.isEmpty else {
            return "  <TitlePage>\n    <Content/>\n  </TitlePage>\n"
        }

        var xml = "  <TitlePage>\n"
        xml += "    <Content>\n"

        for dictionary in screenplay.titlePage {
            for (_, values) in dictionary {
                for value in values {
                    guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                    xml += "      <Paragraph Alignment=\"Center\" FirstIndent=\"0.00\" Leading=\"Regular\" LeftIndent=\"1.00\" RightIndent=\"7.50\" SpaceBefore=\"0\" Spacing=\"1\" StartsNewPage=\"No\">\n"
                    xml += "        <Text>\(escape(value))</Text>\n"
                    xml += "      </Paragraph>\n"
                }
            }
        }

        xml += "    </Content>\n"
        xml += "  </TitlePage>\n"
        return xml
    }

    private static func escape(_ text: String) -> String {
        var escaped = text
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }
}
#endif
