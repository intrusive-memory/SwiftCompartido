//
//  GuionViewerApp.swift
//  GuionViewer
//
//  Created by TOM STOVALL on 12/28/25.
//

import SwiftUI
import SwiftData
import SwiftCompartido

@main
struct GuionViewerApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                GuionDocumentModel.self,
                GuionElementModel.self,
                TypedDataStorage.self,
                TitlePageEntryModel.self,
                CustomPageModel.self,
                CharacterVoiceMapping.self
            ])
            modelContainer = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(modelContainer: modelContainer)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1000, height: 700)
    }
}
