//
//  CharacterInfo.swift
//  SwiftFountain
//
//  Copyright (c) 2025
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

/// Information about a character in a guión
public struct CharacterInfo: Codable {
    public var color: String?
    public var counts: CharacterCounts
    public var gender: CharacterGender
    public var scenes: [Int]

    public init(color: String? = nil, counts: CharacterCounts = CharacterCounts(), gender: CharacterGender = CharacterGender(), scenes: [Int] = []) {
        self.color = color
        self.counts = counts
        self.gender = gender
        self.scenes = scenes
    }
}

/// Statistics about a character's dialogue
public struct CharacterCounts: Codable {
    public var lineCount: Int
    public var wordCount: Int

    public init(lineCount: Int = 0, wordCount: Int = 0) {
        self.lineCount = lineCount
        self.wordCount = wordCount
    }
}

/// Gender specification for a character
public struct CharacterGender: Codable {
    public var unspecified: [String: String]?

    public init(unspecified: [String: String]? = [:]) {
        self.unspecified = unspecified
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Encode as empty object if unspecified
        try container.encode(unspecified ?? [:], forKey: .unspecified)
    }

    private enum CodingKeys: String, CodingKey {
        case unspecified
    }
}

/// Collection of all characters in a guión
public typealias CharacterList = [String: CharacterInfo]
