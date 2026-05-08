//
//  ContentView.swift
//  GuionViewer
//
//  Created by TOM STOVALL on 12/28/25.
//

import SwiftCompartido
import SwiftData
import SwiftUI

/// View for rendering a single screenplay element using SwiftCompartido element views
struct ScreenplayElementView: View {
  let element: DocumentModelActor.ElementInfo

  var body: some View {
    switch element.elementType {
    case .sceneHeading:
      SceneHeadingView(element: element)

    case .action:
      ActionView(element: element)

    case .character:
      DialogueCharacterView(element: element)

    case .dialogue:
      DialogueTextView(element: element)

    case .parenthetical:
      DialogueParentheticalView(element: element)

    case .transition:
      TransitionView(element: element)

    case .sectionHeading:
      SectionHeadingView(element: element)

    case .lyrics:
      DialogueLyricsView(element: element)

    case .synopsis:
      SynopsisView(element: element)

    case .comment:
      CommentView(element: element)

    case .pageBreak:
      PageBreakView()

    default:
      // Fallback for any element types not explicitly handled
      ActionView(element: element)
    }
  }
}

struct ContentView: View {
  let modelContainer: ModelContainer

  @State private var documentActor: DocumentModelActor?
  @State private var screenplayFiles: [URL] = []
  @State private var selectedFile: URL?
  @State private var currentDocumentInfo: DocumentModelActor.DocumentInfo?
  @State private var currentDocumentID: PersistentIdentifier?
  @State private var currentElements: [DocumentModelActor.ElementInfo] = []
  @State private var isLoading = false
  @State private var isLoadingMore = false
  @State private var errorMessage: String?
  @State private var elementsToLoad = 100

  var body: some View {
    VStack(spacing: 0) {
      // Dropdown menu
      HStack {
        Text("Select Screenplay:")
          .padding(.leading)

        Picker("", selection: $selectedFile) {
          Text("Choose a file...").tag(nil as URL?)
          ForEach(screenplayFiles, id: \.self) { file in
            Text(file.deletingPathExtension().lastPathComponent)
              .tag(file as URL?)
          }
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 300)

        Spacer()
      }
      .padding(.vertical, 8)

      Divider()

      // Content area
      if isLoading {
        Spacer()
        ProgressView("Loading screenplay...")
          .font(.system(.body, design: .monospaced))
        Spacer()
      } else if let error = errorMessage {
        Spacer()
        VStack(spacing: 12) {
          Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 48))
            .foregroundStyle(.red)
          Text("Error")
            .font(.system(.headline, design: .monospaced))
          Text(error)
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
        }
        Spacer()
      } else if let docInfo = currentDocumentInfo {
        // Screenplay display with fixed 12pt font and 102 character width
        // Width calculation: 12pt * 0.6 (Courier aspect ratio) * 102 chars = 734.4pt
        let fontSize: CGFloat = 12
        let characterWidth = fontSize * ScreenplayPageFormat.courierCharacterAspectRatio
        let contentWidth = characterWidth * 102

        ScrollView {
          LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
            // Title page
            VStack(spacing: 8) {
              Text(docInfo.title ?? "Untitled")
                .font(.custom("Courier New", size: 24).weight(.bold))
                .textCase(.uppercase)
                .padding(.top, 40)

              Text("Showing \(currentElements.count) of \(docInfo.elementCount) elements")
                .font(.custom("Courier New", size: 10))
                .foregroundStyle(.secondary)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity)

            // Screenplay elements with proper formatting
            ForEach(currentElements) { element in
              ScreenplayElementView(element: element)
                .onAppear {
                  // Load more when we reach the last element
                  if element.id == currentElements.last?.id {
                    Task {
                      await loadMoreElements()
                    }
                  }
                }
            }

            if isLoadingMore {
              HStack {
                Spacer()
                ProgressView()
                  .padding()
                Spacer()
              }
            } else if currentElements.count < docInfo.elementCount {
              Text("Loaded \(currentElements.count) of \(docInfo.elementCount) elements")
                .font(.custom("Courier New", size: 10))
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
            }
          }
          .frame(width: contentWidth)
          .frame(maxWidth: .infinity)  // Center the fixed-width content
          .environment(\.screenplayFontSize, fontSize)
        }
      } else {
        Spacer()
        VStack(spacing: 12) {
          Image(systemName: "doc.text")
            .font(.system(size: 48))
            .foregroundStyle(.secondary)
          Text("Select a screenplay to view")
            .font(.system(.headline, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        Spacer()
      }
    }
    .frame(minWidth: 800, minHeight: 600)
    .task {
      // Initialize the actor
      documentActor = DocumentModelActor(modelContainer: modelContainer)
      await discoverScreenplayFiles()
    }
    .onChange(of: selectedFile) { _, newValue in
      if let url = newValue {
        Task {
          await loadScreenplay(from: url)
        }
      }
    }
  }

  @MainActor
  private func discoverScreenplayFiles() async {
    // Determine where to look for screenplay files
    // 1. Try app bundle Resources folder (for built app with bundled fixtures)
    // 2. Fall back to project Fixtures folder (for development in Xcode)
    let searchURL: URL

    if let resourceURL = Bundle.main.resourceURL,
      FileManager.default.fileExists(atPath: resourceURL.path)
    {
      // Running from built app - look in Resources folder
      searchURL = resourceURL
    } else {
      // Running from Xcode - use project path
      let projectRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
      searchURL = projectRoot.appendingPathComponent("Fixtures")
    }

    guard FileManager.default.fileExists(atPath: searchURL.path) else {
      errorMessage = "Resources folder not found at: \(searchURL.path)"
      return
    }

    do {
      let contents = try FileManager.default.contentsOfDirectory(
        at: searchURL,
        includingPropertiesForKeys: [.isRegularFileKey]
      )

      let supportedExtensions = [
        "fountain", "fdx", "md", "markdown", "pdf", "highland", "textbundle",
      ]
      screenplayFiles = contents.filter { url in
        // Filter for screenplay files only (skip directories, bundles, etc.)
        guard supportedExtensions.contains(url.pathExtension.lowercased()) else { return false }

        // Ensure it's a regular file, not a directory or bundle
        let isFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile ?? false
        return isFile
      }.sorted { $0.lastPathComponent < $1.lastPathComponent }

      if screenplayFiles.isEmpty {
        errorMessage = "No screenplay files found in resources"
      } else {
        selectedFile = screenplayFiles.first
      }
    } catch {
      errorMessage = "Failed to read resources folder: \(error.localizedDescription)"
    }
  }

  @MainActor
  private func loadScreenplay(from url: URL) async {
    guard let actor = documentActor else {
      errorMessage = "Actor not initialized"
      return
    }

    isLoading = true
    errorMessage = nil
    currentDocumentInfo = nil
    currentElements = []
    currentDocumentID = nil
    elementsToLoad = 100

    do {
      // Parse and save document using the actor
      let documentID = try await actor.parseAndSaveDocument(from: url)

      // Fetch document info and elements (Sendable DTOs)
      guard let docInfo = await actor.getDocumentInfo(documentID: documentID) else {
        throw DocumentModelActorError.documentNotFound
      }

      let elements = try await actor.getElements(for: documentID, limit: elementsToLoad)

      currentDocumentID = documentID
      currentDocumentInfo = docInfo
      currentElements = elements
      isLoading = false
    } catch {
      errorMessage = "Failed to parse screenplay: \(error.localizedDescription)"
      isLoading = false
    }
  }

  @MainActor
  private func loadMoreElements() async {
    guard let actor = documentActor,
      let documentID = currentDocumentID,
      let docInfo = currentDocumentInfo,
      !isLoadingMore,
      currentElements.count < docInfo.elementCount
    else {
      return
    }

    isLoadingMore = true

    do {
      // Increase the limit by 100
      elementsToLoad += 100

      // Fetch more elements
      let elements = try await actor.getElements(for: documentID, limit: elementsToLoad)

      currentElements = elements
      isLoadingMore = false
    } catch {
      errorMessage = "Failed to load more elements: \(error.localizedDescription)"
      isLoadingMore = false
    }
  }
}

#Preview {
  let schema = Schema([
    GuionDocumentModel.self,
    GuionElementModel.self,
    TypedDataStorage.self,
  ])
  let container = try! ModelContainer(
    for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))

  ContentView(modelContainer: container)
    .modelContainer(container)
}
