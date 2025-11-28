//
//  CastListTrimTests.swift
//  SwiftCompartidoTests
//
//  Copyright (c) 2025
//

import Foundation
import Testing
@testable import SwiftCompartido

@Suite("Cast List Trim Tests")
struct CastListTrimTests {

    // MARK: - Helper Methods

    func createTestScreenplay(characters: [String]) -> GuionParsedElementCollection {
        var elements: [GuionElement] = []

        // Add scene heading
        elements.append(GuionElement(elementType: .sceneHeading, elementText: "INT. SCENE - DAY"))

        // Add character dialogue for each character
        for character in characters {
            elements.append(GuionElement(elementType: .character, elementText: character))
            elements.append(GuionElement(elementType: .dialogue, elementText: "Some dialogue."))
        }

        return GuionParsedElementCollection(
            filename: "test.fountain",
            elements: elements
        )
    }

    // MARK: - Trim Tests

    @Test("Trim removes cast members not in screenplay")
    func testTrimRemovesUnusedMembers() {
        var castList = CastListPage(
            title: "Cast List",
            position: 0,
            items: [
                CastListPage.CastMember(role: "BERNARD", name: "Actor A", position: 0),
                CastListPage.CastMember(role: "SYLVIA", name: "Actor B", position: 1),
                CastListPage.CastMember(role: "MASON", name: "Actor C", position: 2)
            ]
        )

        // Screenplay only has BERNARD and SYLVIA
        let screenplay = createTestScreenplay(characters: ["BERNARD", "SYLVIA"])

        castList.trim(toCharactersIn: screenplay)

        #expect(castList.items.count == 2)
        #expect(castList.items.contains(where: { $0.role == "BERNARD" }))
        #expect(castList.items.contains(where: { $0.role == "SYLVIA" }))
        #expect(!castList.items.contains(where: { $0.role == "MASON" }))
    }

    @Test("Trim preserves all members when all are in screenplay")
    func testTrimPreservesAllMembers() {
        var castList = CastListPage(
            title: "Cast List",
            position: 0,
            items: [
                CastListPage.CastMember(role: "BERNARD", name: "Actor A", position: 0),
                CastListPage.CastMember(role: "SYLVIA", name: "Actor B", position: 1)
            ]
        )

        let screenplay = createTestScreenplay(characters: ["BERNARD", "SYLVIA"])

        castList.trim(toCharactersIn: screenplay)

        #expect(castList.items.count == 2)
    }

    @Test("Trim is case-insensitive")
    func testTrimCaseInsensitive() {
        var castList = CastListPage(
            title: "Cast List",
            position: 0,
            items: [
                CastListPage.CastMember(role: "Bernard", name: "Actor A", position: 0),
                CastListPage.CastMember(role: "SYLVIA", name: "Actor B", position: 1)
            ]
        )

        // Screenplay has uppercase characters
        let screenplay = createTestScreenplay(characters: ["BERNARD", "SYLVIA"])

        castList.trim(toCharactersIn: screenplay)

        #expect(castList.items.count == 2)
        #expect(castList.items.contains(where: { $0.role == "Bernard" }))
    }

    @Test("Trim handles whitespace in character names")
    func testTrimHandlesWhitespace() {
        var castList = CastListPage(
            title: "Cast List",
            position: 0,
            items: [
                CastListPage.CastMember(role: "  BERNARD  ", name: "Actor A", position: 0),
                CastListPage.CastMember(role: "SYLVIA", name: "Actor B", position: 1)
            ]
        )

        let screenplay = createTestScreenplay(characters: ["BERNARD", "SYLVIA"])

        castList.trim(toCharactersIn: screenplay)

        #expect(castList.items.count == 2)
    }

    @Test("Trim preserves position values")
    func testTrimPreservesPositions() {
        var castList = CastListPage(
            title: "Cast List",
            position: 0,
            items: [
                CastListPage.CastMember(role: "BERNARD", name: "Actor A", position: 0),
                CastListPage.CastMember(role: "UNUSED", name: "Actor B", position: 5),
                CastListPage.CastMember(role: "SYLVIA", name: "Actor C", position: 10)
            ]
        )

        let screenplay = createTestScreenplay(characters: ["BERNARD", "SYLVIA"])

        castList.trim(toCharactersIn: screenplay)

        #expect(castList.items.count == 2)
        #expect(castList.items[0].position == 0)
        #expect(castList.items[1].position == 10) // Gap preserved
    }

    @Test("Trim results in empty list when no matches")
    func testTrimResultsInEmptyList() {
        var castList = CastListPage(
            title: "Cast List",
            position: 0,
            items: [
                CastListPage.CastMember(role: "HAMLET", name: "Actor A", position: 0),
                CastListPage.CastMember(role: "OPHELIA", name: "Actor B", position: 1)
            ]
        )

        let screenplay = createTestScreenplay(characters: ["BERNARD", "SYLVIA"])

        castList.trim(toCharactersIn: screenplay)

        #expect(castList.items.isEmpty)
    }

    @Test("Trim on empty cast list does nothing")
    func testTrimEmptyCastList() {
        var castList = CastListPage(
            title: "Cast List",
            position: 0,
            items: []
        )

        let screenplay = createTestScreenplay(characters: ["BERNARD", "SYLVIA"])

        castList.trim(toCharactersIn: screenplay)

        #expect(castList.items.isEmpty)
    }

    // MARK: - membersNotIn Tests

    @Test("membersNotIn returns unused cast members")
    func testMembersNotIn() {
        let castList = CastListPage(
            title: "Cast List",
            position: 0,
            items: [
                CastListPage.CastMember(role: "BERNARD", name: "Actor A", position: 0),
                CastListPage.CastMember(role: "SYLVIA", name: "Actor B", position: 1),
                CastListPage.CastMember(role: "MASON", name: "Actor C", position: 2)
            ]
        )

        let screenplay = createTestScreenplay(characters: ["BERNARD", "SYLVIA"])

        let unused = castList.membersNotIn(screenplay)

        #expect(unused.count == 1)
        #expect(unused[0].role == "MASON")
    }

    @Test("membersNotIn returns empty when all members used")
    func testMembersNotInAllUsed() {
        let castList = CastListPage(
            title: "Cast List",
            position: 0,
            items: [
                CastListPage.CastMember(role: "BERNARD", name: "Actor A", position: 0),
                CastListPage.CastMember(role: "SYLVIA", name: "Actor B", position: 1)
            ]
        )

        let screenplay = createTestScreenplay(characters: ["BERNARD", "SYLVIA", "MASON"])

        let unused = castList.membersNotIn(screenplay)

        #expect(unused.isEmpty)
    }

    // MARK: - charactersNotInCast Tests

    @Test("charactersNotInCast returns missing characters")
    func testCharactersNotInCast() {
        let castList = CastListPage(
            title: "Cast List",
            position: 0,
            items: [
                CastListPage.CastMember(role: "BERNARD", name: "Actor A", position: 0)
            ]
        )

        let screenplay = createTestScreenplay(characters: ["BERNARD", "SYLVIA", "MASON"])

        let missing = castList.charactersNotInCast(from: screenplay)

        #expect(missing.count == 2)
        #expect(missing.contains("SYLVIA"))
        #expect(missing.contains("MASON"))
    }

    @Test("charactersNotInCast returns empty when all characters in cast")
    func testCharactersNotInCastAllPresent() {
        let castList = CastListPage(
            title: "Cast List",
            position: 0,
            items: [
                CastListPage.CastMember(role: "BERNARD", name: "Actor A", position: 0),
                CastListPage.CastMember(role: "SYLVIA", name: "Actor B", position: 1)
            ]
        )

        let screenplay = createTestScreenplay(characters: ["BERNARD", "SYLVIA"])

        let missing = castList.charactersNotInCast(from: screenplay)

        #expect(missing.isEmpty)
    }

    @Test("charactersNotInCast is case-insensitive")
    func testCharactersNotInCastCaseInsensitive() {
        let castList = CastListPage(
            title: "Cast List",
            position: 0,
            items: [
                CastListPage.CastMember(role: "bernard", name: "Actor A", position: 0)
            ]
        )

        let screenplay = createTestScreenplay(characters: ["BERNARD", "SYLVIA"])

        let missing = castList.charactersNotInCast(from: screenplay)

        #expect(missing.count == 1)
        #expect(missing.contains("SYLVIA"))
    }

    @Test("charactersNotInCast returns sorted results")
    func testCharactersNotInCastSorted() {
        let castList = CastListPage(
            title: "Cast List",
            position: 0,
            items: []
        )

        let screenplay = createTestScreenplay(characters: ["ZELDA", "ALICE", "MASON"])

        let missing = castList.charactersNotInCast(from: screenplay)

        #expect(missing.count == 3)
        #expect(missing[0] == "ALICE")
        #expect(missing[1] == "MASON")
        #expect(missing[2] == "ZELDA")
    }

    // MARK: - Real-World Scenario Tests

    @Test("Shared cast list scenario - multiple fountain files")
    func testSharedCastListScenario() {
        // Shared cast list for multiple episodes
        var sharedCastList = CastListPage(
            title: "Series Cast",
            position: 0,
            items: [
                CastListPage.CastMember(role: "BERNARD", name: "Actor A", position: 0), // In episode 1
                CastListPage.CastMember(role: "SYLVIA", name: "Actor B", position: 1),  // In episode 1 & 2
                CastListPage.CastMember(role: "MASON", name: "Actor C", position: 2),   // Only in episode 2
                CastListPage.CastMember(role: "KILLIAN", name: "Actor D", position: 3)  // In episode 1 & 2
            ]
        )

        // Episode 1 only has BERNARD, SYLVIA, and KILLIAN
        let episode1 = createTestScreenplay(characters: ["BERNARD", "SYLVIA", "KILLIAN"])

        // Check which characters are unused in episode 1
        let unusedInEp1 = sharedCastList.membersNotIn(episode1)
        #expect(unusedInEp1.count == 1)
        #expect(unusedInEp1[0].role == "MASON")

        // User decides to trim to episode 1 only
        sharedCastList.trim(toCharactersIn: episode1)

        #expect(sharedCastList.items.count == 3)
        #expect(!sharedCastList.items.contains(where: { $0.role == "MASON" }))
    }

    @Test("Suggest new cast members workflow")
    func testSuggestNewMembersWorkflow() {
        var castList = CastListPage(
            title: "Cast List",
            position: 0,
            items: [
                CastListPage.CastMember(role: "BERNARD", name: "Jason Manino", position: 0)
            ]
        )

        // Screenplay has new characters
        let screenplay = createTestScreenplay(characters: ["BERNARD", "SYLVIA", "MASON"])

        // Find characters that need to be added
        let missing = castList.charactersNotInCast(from: screenplay)

        #expect(missing.count == 2)

        // User adds them manually
        for character in missing {
            castList.addMember(role: character, name: "")
        }

        #expect(castList.items.count == 3)
    }
}
