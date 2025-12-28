# GuionViewer Demo App Requirements

## Purpose

GuionViewer is a minimal macOS demo application for SwiftCompartido that showcases the library's screenplay viewing capabilities.

## Target Platform

- **Platform**: macOS 26.0+
- **Architecture**: Apple Silicon (arm64) only
- **SwiftUI**: Native macOS window-based app

## UI Requirements

### Main Window

**Layout:**
```
┌─────────────────────────────────────────┐
│  [Dropdown: Select Screenplay ▼]       │
├─────────────────────────────────────────┤
│                                         │
│                                         │
│         GuionViewer Content             │
│         (Screenplay Display)            │
│                                         │
│                                         │
└─────────────────────────────────────────┘
```

**Components:**

1. **Dropdown Menu (Picker)**
   - Displays list of screenplay files from `Figures/` folder
   - Shows filename only (without path or extension)
   - Auto-selects first file on launch
   - Triggers screenplay load on selection change

2. **Content Frame**
   - Displays `GuionViewer` component from SwiftCompartido
   - Fills remaining window space below dropdown
   - Shows parsed screenplay content

3. **Window Properties**
   - Resizable (min size: 800x600)
   - Default size: 1000x700
   - Title: "GuionViewer Demo"

## Functional Requirements

### File Discovery

1. **Source Location**: `Fixtures/` folder (relative to project root)
2. **Supported Formats**: `.fountain`, `.fdx`, `.md`, `.markdown`, `.pdf`, `.highland`, `.textbundle`
3. **File Loading**: Scan folder on app launch, populate dropdown
4. **Error Handling**: Show alert if Fixtures folder is empty or missing

### Screenplay Loading

1. Parse selected file using `GuionParsedElementCollection`
2. Convert to SwiftData model using `GuionDocumentParserSwiftData`
3. Display in `GuionViewer` component
4. Show loading indicator during parse operation
5. Display error alert if parsing fails

### SwiftData Integration

1. Use in-memory ModelContainer (no persistence needed)
2. Container configured for `GuionDocumentModel` schema
3. Recreate document on each file selection (demo app, no history needed)

## Non-Requirements (Out of Scope)

- ❌ File editing capabilities
- ❌ Saving/exporting functionality
- ❌ Multiple window support
- ❌ Document persistence across launches
- ❌ Recent files menu
- ❌ Advanced UI features (toolbars, sidebars, preferences)
- ❌ CloudKit or external storage
- ❌ AI generation features
- ❌ Printing or PDF export

## Implementation Guidelines

### Code Minimalism

- **Single ContentView**: All UI in one SwiftUI view
- **No custom components**: Use stock SwiftUI controls
- **Inline logic**: No separate view models unless absolutely necessary
- **Standard spacing**: Use default SwiftUI layout modifiers

### Architecture

```
GuionViewerApp.swift        // @main entry point, configure ModelContainer
ContentView.swift           // Dropdown + GuionViewer layout
Fixtures/                   // Sample screenplay files
```

### Dependencies

- SwiftCompartido (local package)
- SwiftData (for ModelContainer/ModelContext)
- SwiftUI (for UI)

## Sample Screenplays

The `Fixtures/` folder should contain 3-5 sample screenplay files demonstrating different formats:

1. `sample.fountain` - Basic Fountain screenplay
2. `example.fdx` - Final Draft XML
3. `demo.md` - Markdown with YAML front matter
4. `test.pdf` - PDF screenplay (AI parsing)
5. `highland.highland` - Highland bundle (optional)

## Acceptance Criteria

✅ App launches and displays window
✅ Dropdown shows all screenplay files from Figures/
✅ Selecting a file loads and displays screenplay
✅ GuionViewer renders screenplay elements correctly
✅ Window is resizable without layout breaking
✅ Error alerts appear for missing files or parse failures
✅ Total code < 150 lines (excluding sample files)

## Future Enhancements (Not in MVP)

- Settings panel for font/theme customization
- Export to PDF
- Search within screenplay
- Element filtering (show only dialogue, etc.)
- Side-by-side comparison of two screenplays

## References

- SwiftCompartido: `/Sources/SwiftCompartido/`
- GuionViewer component: `/Sources/SwiftCompartido/UI/GuionViewer.swift`
- GuionParsedElementCollection: `/Sources/SwiftCompartido/GuionParsedElementCollection.swift`
