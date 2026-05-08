//
//  GuionElementsList.swift
//  SwiftCompartido
//
//  Simple list view displaying GuionElementModels from SwiftData
//

@preconcurrency import SwiftData
import SwiftUI

/// PreferenceKey for tracking scroll position
private struct ScrollOffsetPreferenceKey: PreferenceKey {
  static let defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

/// Container view for element rows with stable identity
///
/// This view wraps GuionElementRow and its spacing with a stable identity
/// based on the element's persistent model ID to optimize list performance.
struct ElementRowContainer<TrailingContent: View>: View {
  let element: GuionElementModel
  let needsSpacing: Bool
  let fontSize: CGFloat
  let trailingContent: ((GuionElementModel) -> TrailingContent)?

  var body: some View {
    VStack(spacing: 0) {
      GuionElementRow(element: element, trailingContent: trailingContent)

      // Add full line spacing using cached spacing map
      if needsSpacing {
        Spacer()
          .frame(height: fontSize * ScreenplayPageFormat.lineSpacingMultiplier)
      }
    }
  }
}

/// Simple list displaying GuionElementModels from SwiftData
public struct GuionElementsList<TrailingContent: View>: View {
  @Query private var elements: [GuionElementModel]
  @Environment(\.screenplayFontSize) var fontSize
  @State private var scrollState = ScrollDetectionState()
  @State private var dismissID = UUID()

  private let trailingContent: ((GuionElementModel) -> TrailingContent)?
  private let isHierarchical: Bool

  /// Cached spacing map: true if element needs spacing after it
  @State private var spacingMap: [PersistentIdentifier: Bool] = [:]

  /// Hierarchical tree (only built if isHierarchical == true)
  @State private var hierarchyRoots: [HierarchyNode] = []

  /// Disclosure states for hierarchy nodes
  @State private var disclosureStates: [PersistentIdentifier: Bool] = [:]

  /// Progress tracking for hierarchy building
  @State private var buildProgress: OperationProgress? = nil
  @State private var buildProgressMessage: String = ""
  @State private var buildProgressFraction: Double = 0.0
  @State private var isBuilding: Bool = false

  /// Creates a GuionElementsList with all elements in order
  /// - Parameter hierarchical: If true, displays elements in hierarchical disclosure groups (default: false)
  public init(hierarchical: Bool = false) where TrailingContent == EmptyView {
    _elements = Query(sort: [
      SortDescriptor(\GuionElementModel.chapterIndex),
      SortDescriptor(\GuionElementModel.orderIndex),
    ])
    self.trailingContent = nil
    self.isHierarchical = hierarchical
  }

  /// Creates a GuionElementsList filtered to a specific document, in order
  /// - Parameters:
  ///   - document: The document to filter elements by
  ///   - hierarchical: If true, displays elements in hierarchical disclosure groups (default: false)
  public init(document: GuionDocumentModel, hierarchical: Bool = false)
  where TrailingContent == EmptyView {
    let documentID = document.persistentModelID
    _elements = Query(
      filter: #Predicate<GuionElementModel> { element in
        element.document?.persistentModelID == documentID
      },
      sort: [
        SortDescriptor(\GuionElementModel.chapterIndex),
        SortDescriptor(\GuionElementModel.orderIndex),
      ]
    )
    self.trailingContent = nil
    self.isHierarchical = hierarchical
  }

  /// Creates a GuionElementsList with all elements in order and custom trailing content for each row
  /// - Parameters:
  ///   - hierarchical: If true, displays elements in hierarchical disclosure groups (default: false)
  ///   - trailingContent: A ViewBuilder closure that creates trailing content for each element
  public init(
    hierarchical: Bool = false,
    @ViewBuilder trailingContent: @escaping (GuionElementModel) -> TrailingContent
  ) {
    _elements = Query(sort: [
      SortDescriptor(\GuionElementModel.chapterIndex),
      SortDescriptor(\GuionElementModel.orderIndex),
    ])
    self.trailingContent = trailingContent
    self.isHierarchical = hierarchical
  }

  /// Creates a GuionElementsList filtered to a specific document with custom trailing content for each row
  /// - Parameters:
  ///   - document: The document to filter elements by
  ///   - hierarchical: If true, displays elements in hierarchical disclosure groups (default: false)
  ///   - trailingContent: A ViewBuilder closure that creates trailing content for each element
  public init(
    document: GuionDocumentModel, hierarchical: Bool = false,
    @ViewBuilder trailingContent: @escaping (GuionElementModel) -> TrailingContent
  ) {
    let documentID = document.persistentModelID
    _elements = Query(
      filter: #Predicate<GuionElementModel> { element in
        element.document?.persistentModelID == documentID
      },
      sort: [
        SortDescriptor(\GuionElementModel.chapterIndex),
        SortDescriptor(\GuionElementModel.orderIndex),
      ]
    )
    self.trailingContent = trailingContent
    self.isHierarchical = hierarchical
  }

  public var body: some View {
    ZStack {
      ScrollView {
        LazyVStack(spacing: 0, pinnedViews: []) {
          // Scroll position tracker (invisible)
          GeometryReader { geometry in
            Color.clear
              .preference(
                key: ScrollOffsetPreferenceKey.self,
                value: geometry.frame(in: .named("scroll")).minY)
          }
          .frame(height: 0)

          if isHierarchical {
            // Hierarchical mode - render tree
            ForEach(hierarchyRoots) { node in
              HierarchySection(
                node: node,
                elements: elements,
                spacingMap: spacingMap,
                fontSize: fontSize,
                trailingContent: trailingContent,
                disclosureStates: $disclosureStates
              )
            }
          } else {
            // Flat mode - render list
            ForEach(elements, id: \.persistentModelID) { element in
              ElementRowContainer(
                element: element,
                needsSpacing: spacingMap[element.persistentModelID] == true,
                fontSize: fontSize,
                trailingContent: trailingContent
              )
              .id(element.persistentModelID)
            }
          }
        }
        .scrollTargetLayout()
        .padding(.horizontal, 0)
      }
      .scrollBounceBehavior(.basedOnSize)
      .coordinateSpace(name: "scroll")
      .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
        scrollState.updateScrollPosition(offset)
      }

      // Progress overlay for hierarchy building
      if isBuilding {
        VStack {
          Spacer()
          HStack {
            ProgressView(value: buildProgressFraction) {
              Text(buildProgressMessage)
                .font(.caption)
            }
            .progressViewStyle(.linear)
            .frame(maxWidth: 400)
            .padding()
            .background(.regularMaterial)
            .cornerRadius(8)
          }
          .padding()
        }
      }
    }
    .environment(scrollState)
    .environment(\.popoverDismissAction, { dismissID = UUID() })
    .environment(\.popoverDismissID, dismissID)
    .onAppear {
      computeSpacingMap()
      if isHierarchical {
        buildHierarchy()
      }
    }
    .onChange(of: elements.count) { _, _ in
      computeSpacingMap()
      if isHierarchical {
        buildHierarchy()
      }
    }
    .onDisappear {
      scrollState.reset()
    }
  }

  // MARK: - Spacing Helpers

  /// Pre-compute which elements need spacing after them
  /// This eliminates N+1 lookups during scroll by computing the map once
  private func computeSpacingMap() {
    var map: [PersistentIdentifier: Bool] = [:]

    for (index, element) in elements.enumerated() {
      // Action and synopsis always get spacing
      if element.elementType == .action || element.elementType == .synopsis {
        map[element.persistentModelID] = true
        continue
      }

      // Dialogue, parenthetical, and lyrics get spacing if at end of dialogue group
      if element.elementType == .dialogue || element.elementType == .parenthetical
        || element.elementType == .lyrics
      {
        // Check if there's a next element
        if index + 1 < elements.count {
          let nextElement = elements[index + 1]
          // Group ends if next element is NOT dialogue, parenthetical, or lyrics
          map[element.persistentModelID] =
            (nextElement.elementType != .dialogue && nextElement.elementType != .parenthetical
              && nextElement.elementType != .lyrics)
        } else {
          // Last element in list - it ends the group
          map[element.persistentModelID] = true
        }
      } else {
        // All other element types don't get spacing
        map[element.persistentModelID] = false
      }
    }

    spacingMap = map
  }

  /// Determines if the element at the given index is the end of a dialogue group
  /// A dialogue group consists of: character, dialogue, parenthetical, lyrics (in any combination)
  /// The group ends when the next element is NOT dialogue, parenthetical, or lyrics
  /// - Note: This function is deprecated in favor of the cached spacingMap
  @available(*, deprecated, message: "Use spacingMap instead for better performance")
  private func isEndOfDialogueGroup(at index: Int) -> Bool {
    let element = elements[index]

    // Only dialogue, parenthetical, and lyrics elements can end a dialogue group
    guard
      element.elementType == .dialogue || element.elementType == .parenthetical
        || element.elementType == .lyrics
    else {
      return false
    }

    // Check if there's a next element
    guard index + 1 < elements.count else {
      // Last element in list - it ends the group
      return true
    }

    let nextElement = elements[index + 1]

    // Group continues if next element is dialogue, parenthetical, or lyrics
    // Group ends if next element is anything else
    return nextElement.elementType != .dialogue && nextElement.elementType != .parenthetical
      && nextElement.elementType != .lyrics
  }

  // MARK: - Hierarchy Building

  /// Builds the hierarchical tree structure asynchronously with progress reporting
  private func buildHierarchy() {
    isBuilding = true
    buildProgressMessage = "Building hierarchy..."
    buildProgressFraction = 0.0

    // Capture elements and spacingMap on main actor
    let elementsCopy = elements
    let spacingMapCopy = spacingMap

    Task { @MainActor in
      let progress = OperationProgress(totalUnits: Int64(elementsCopy.count)) { update in
        Task { @MainActor in
          self.buildProgressMessage = update.description
          self.buildProgressFraction = update.fractionCompleted ?? 0.0
        }
      }

      // Build hierarchy (MainActor-isolated for Swift 6 concurrency)
      let roots = HierarchyBuilder.buildHierarchy(
        from: elementsCopy,
        spacingMap: spacingMapCopy,
        progress: progress
      )

      // Update UI
      hierarchyRoots = roots
      isBuilding = false
    }
  }
}

// MARK: - Preview

#Preview("Elements List - Default") {
  GuionElementsList()
    .modelContainer(for: [GuionDocumentModel.self, GuionElementModel.self])
}

#Preview("Elements List - With Trailing Column") {
  GuionElementsList { element in
    VStack(alignment: .trailing, spacing: 4) {
      Text("\(element.chapterIndex)")
        .font(.caption)
        .foregroundStyle(.secondary)
      Text("\(element.orderIndex)")
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
    .frame(width: 50)
  }
  .modelContainer(for: [GuionDocumentModel.self, GuionElementModel.self])
}
