//
//  FountainRegexes.swift
//  SwiftFountain
//
//  Copyright (c) 2012-2013 Nima Yousefi & John August
//  Swift conversion (c) 2025
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import Foundation

public struct FountainRegexes {
    // Line breaks
    public static let universalLineBreaksPattern = "\\r\\n|\\r|\\n"
    public static let universalLineBreaksTemplate = "\n"

    // Match patterns
    public static let sceneHeaderPattern = "(?<=\\n)(([iI][nN][tT]|[eE][xX][tT]|[^\\w][eE][sS][tT]|\\.|[iI]\\.?\\/[eE]\\.?|[oO][vV][eE][rR]\\s+[bB][lL][aA][cC][kK])([^\\n]*))\\n"
    public static let actionPattern = "([^<>]*?)(\\n{2}|\\n<)"
    public static let multiLineActionPattern = "\n{2}(([^a-z\\n:]+?[\\.\\?,\\s!\\*_]*?)\\n{2}){1,2}"
    public static let characterCuePattern = "(?<=\\n)([ \\t]*[^<>a-z\\s\\/\\n][^<>a-z:!\\?\\n]*[^<>a-z\\(!\\?:,\\n\\.][ \\t]?)\\n{1}(?!\\n)"
    public static let dialoguePattern = "(<(Character|Parenthetical)>[^<>\\n]+<\\/(Character|Parenthetical)>)([^<>]*?)(?=\\n{2}|\\n{1}<Parenthetical>)"
    public static let parentheticalPattern = "(\\([^<>]*?\\)[\\s]?)\\n"
    public static let transitionPattern = "\\n([\\*_]*([^<>\\na-z]*TO:|FADE TO BLACK\\.|FADE OUT\\.|CUT TO BLACK\\.)[\\*_]*)\\n"
    public static let forcedTransitionPattern = "\\n((&gt;|>)\\s*[^<>\\n]+)\\n"
    public static let falseTransitionPattern = "\\n((&gt;|>)\\s*[^<>\\n]+(&lt;\\s*))\\n"
    public static let pageBreakPattern = "(?<=\\n)(\\s*[\\=\\-\\_]{3,8}\\s*)\\n{1}"
    public static let cleanupPattern = "<Action>\\s*<\\/Action>"
    public static let firstLineActionPattern = "^\\n\\n([^<>\\n#]*?)\\n"
    public static let sceneNumberPattern = "(\\#([0-9A-Za-z\\.\\)-]+)\\#)"
    public static let sectionHeaderPattern = "((#+)(\\s*[^\\n]*))\\n?"

    // Templates
    public static let sceneHeaderTemplate = "\n<Scene Heading>$1</Scene Heading>"
    public static let actionTemplate = "<Action>$1</Action>$2"
    public static let multiLineActionTemplate = "\n<Action>$2</Action>"
    public static let characterCueTemplate = "<Character>$1</Character>"
    public static let dialogueTemplate = "$1<Dialogue>$4</Dialogue>"
    public static let parentheticalTemplate = "<Parenthetical>$1</Parenthetical>"
    public static let transitionTemplate = "\n<Transition>$1</Transition>"
    public static let forcedTransitionTemplate = "\n<Transition>$1</Transition>"
    public static let falseTransitionTemplate = "\n<Action>$1</Action>"
    public static let pageBreakTemplate = "\n<Page Break></Page Break>\n"
    public static let cleanupTemplate = ""
    public static let firstLineActionTemplate = "<Action>$1</Action>\n"
    public static let sectionHeaderTemplate = "<Section Heading>$1</Section Heading>"

    // Comments
    public static let blockCommentPattern = "\\n\\/\\*([^<>]+?)\\*\\/\\n"
    public static let bracketCommentPattern = "\\n\\[{2}([^<>]+?)\\]{2}\\n"
    public static let synopsisPattern = "\\n={1}([^<>=][^<>]+?)\\n"

    public static let blockCommentTemplate = "\n<Boneyard>$1</Boneyard>\n"
    public static let bracketCommentTemplate = "\n<Comment>$1</Comment>\n"
    public static let synopsisTemplate = "\n<Synopsis>$1</Synopsis>\n"

    public static let newlineReplacement = "@@@@@"
    public static let newlineRestore = "\n"

    // Title page
    public static let titlePagePattern = "^([^\\n]+:(([ \\t]*|\\n)[^\\n]+\\n)+)+\\n"
    public static let inlineDirectivePattern = "^([\\w\\s&]+):\\s*([^\\s][\\w&,\\.\\?!:\\(\\)\\/\\s-©\\*\\_]+)$"
    public static let multiLineDirectivePattern = "^([\\w\\s&]+):\\s*$"
    public static let multiLineDataPattern = "^([ ]{2,8}|\\t)([^<>]+)$"

    // Misc
    public static let dualDialoguePattern = "\\^\\s*$"
    public static let centeredTextPattern = "^>[^<>\\n]+<"

    // Styling patterns
    public static let boldItalicUnderlinePattern = "(_\\*{3}|\\*{3}_)([^<>]+)(_\\*{3}|\\*{3}_)"
    public static let boldItalicPattern = "(\\*{3})([^<>]+)(\\*{3})"
    public static let boldUnderlinePattern = "(_\\*{2}|\\*{2}_)([^<>]+)(_\\*{2}|\\*{2}_)"
    public static let italicUnderlinePattern = "(_\\*{1}|\\*{1}_)([^<>]+)(_\\*{1}|\\*{1}_)"
    public static let boldPattern = "(\\*{2})(.+?)(\\*{2})"
    public static let italicPattern = "(\\*)(.+?)(\\*)"
    public static let underlinePattern = "(_)(.+?)(_)"

    // Styling templates
    public static let boldItalicUnderlineTemplate = "Bold+Italic+Underline"
    public static let boldItalicTemplate = "Bold+Italic"
    public static let boldUnderlineTemplate = "Bold+Underline"
    public static let italicUnderlineTemplate = "Italic+Underline"
    public static let boldTemplate = "Bold"
    public static let italicTemplate = "Italic"
    public static let underlineTemplate = "Underline"
}
