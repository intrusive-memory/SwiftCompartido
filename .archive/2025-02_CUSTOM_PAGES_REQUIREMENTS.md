<!-- Archived 2026-02-15: Custom-pages.json support removed in favor of SwiftProyecto PROJECT.md -->

# Custom Pages Support - Requirements Document

## Overview

Add support for Highland's Custom Pages feature to SwiftCompartido, starting with Cast List pages. Custom pages are additional non-screenplay pages (cast lists, production notes, concept images, etc.) that can be included when printing or exporting a screenplay.

## Analysis of custom-pages.json Structure

### File Location: `Fixtures/custom-pages.json`

The JSON contains an array of custom page objects with three identified types:

1. **Cast List** (`type: "castList"`)
   - Properties:
     - `id`: UUID string
     - `title`: String (e.g., "Cast List")
     - `type`: "castList"
     - `position`: Int (print order position)
     - `printDots`: Bool (whether to print dots between role and actor name)
     - `items`: Array of cast members
       - `id`: UUID string
       - `role`: String (character name)
       - `name`: String (actor name, can be empty)
       - `position`: Int (always 0 in sample)

2. **Advanced Page** (`type: "advanced"`)
   - Properties:
     - `id`: UUID string
     - `title`: String
     - `type`: "advanced"
     - `position`: Int
     - `tc`, `tl`, `tr`, `cl`, `cc`, `cr`, `bl`, `bc`, `br`: Grid cells (top/center/bottom x left/center/right)
       - Each cell can have:
         - `text`: String
         - `assetFilename`: String (reference to asset in resources folder)

3. **Empty Page** (`type: "empty"`)
   - Properties:
     - `id`: UUID string
     - `title`: String
     - `type`: "empty"
     - `position`: Int
