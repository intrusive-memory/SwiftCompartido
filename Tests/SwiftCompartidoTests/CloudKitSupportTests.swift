//
//  CloudKitSupportTests.swift
//  SwiftCompartidoTests
//
//  Tests for CloudKit support and dual storage functionality
//

import Testing
import Foundation
import SwiftData
@testable import SwiftCompartido

/// Tests for CloudKit sync support
struct CloudKitSupportTests {

    // MARK: - Storage Mode Tests

    @Test("GeneratedTextRecord defaults to local storage mode")
    func textRecordDefaultsToLocal() {
        let record = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            text: "Hello World",
            wordCount: 2,
            characterCount: 11
        )

        #expect(record.storageMode == .local)
        #expect(record.syncStatus == .localOnly)
        #expect(record.isCloudKitEnabled == false)
        #expect(record.cloudKitRecordID == nil)
    }

    @Test("GeneratedAudioRecord defaults to local storage mode")
    func audioRecordDefaultsToLocal() {
        let record = GeneratedAudioRecord(
            providerId: "test",
            requestorID: "test.audio",
            audioData: nil,
            format: "mp3",
            voiceID: "voice1",
            voiceName: "Test Voice"
        )

        #expect(record.storageMode == .local)
        #expect(record.syncStatus == .localOnly)
        #expect(record.isCloudKitEnabled == false)
    }

    @Test("GeneratedImageRecord defaults to local storage mode")
    func imageRecordDefaultsToLocal() {
        let record = GeneratedImageRecord(
            providerId: "test",
            requestorID: "test.image",
            imageData: nil,
            format: "png",
            width: 1024,
            height: 1024
        )

        #expect(record.storageMode == .local)
        #expect(record.syncStatus == .localOnly)
        #expect(record.isCloudKitEnabled == false)
    }

    @Test("GeneratedEmbeddingRecord defaults to local storage mode")
    func embeddingRecordDefaultsToLocal() {
        let record = GeneratedEmbeddingRecord(
            providerId: "test",
            requestorID: "test.embedding",
            embeddingData: nil,
            dimensions: 1536,
            inputText: "test",
            tokenCount: 1,
            modelIdentifier: "test-model"
        )

        #expect(record.storageMode == .local)
        #expect(record.syncStatus == .localOnly)
        #expect(record.isCloudKitEnabled == false)
    }

    // MARK: - CloudKit Mode Tests

    @Test("Record with CloudKit storage mode enables CloudKit")
    func cloudKitModeEnablesCloudKit() {
        let record = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            text: "Hello CloudKit",
            wordCount: 2,
            characterCount: 14,
            storageMode: .cloudKit
        )

        #expect(record.storageMode == .cloudKit)
        #expect(record.syncStatus == .pending)
        #expect(record.isCloudKitEnabled == true)
    }

    @Test("Record with hybrid storage mode enables CloudKit")
    func hybridModeEnablesCloudKit() {
        let record = GeneratedAudioRecord(
            providerId: "test",
            requestorID: "test.audio",
            audioData: Data(),
            format: "mp3",
            voiceID: "voice1",
            voiceName: "Test Voice",
            storageMode: .hybrid
        )

        #expect(record.storageMode == .hybrid)
        #expect(record.syncStatus == .pending)
        #expect(record.isCloudKitEnabled == true)
    }

    @Test("Setting cloudKitRecordID enables CloudKit")
    func settingRecordIDEnablesCloudKit() {
        let record = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            text: "Test",
            wordCount: 1,
            characterCount: 4
        )

        #expect(record.isCloudKitEnabled == false)

        record.cloudKitRecordID = "ckrecord-123"
        #expect(record.isCloudKitEnabled == true)
    }

    // MARK: - CloudKitSyncable Protocol Tests

    @Test("GeneratedTextRecord conforms to CloudKitSyncable")
    func textRecordConformsToCloudKitSyncable() {
        let record = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            text: "Test",
            wordCount: 1,
            characterCount: 4
        )

        let syncable: any CloudKitSyncable = record
        #expect(syncable.cloudKitRecordID == nil)
        #expect(syncable.conflictVersion == 1)
        #expect(syncable.syncStatus == .localOnly)
    }

    // MARK: - Dual Storage Tests

    @Test("Audio record can save to local storage")
    func audioSaveToLocalStorage() throws {
        let requestID = UUID()
        let storage = StorageAreaReference.temporary(requestID: requestID)
        let audioData = Data([0x01, 0x02, 0x03, 0x04])

        let record = GeneratedAudioRecord(
            id: requestID,
            providerId: "test",
            requestorID: "test.audio",
            audioData: nil,
            format: "mp3",
            voiceID: "voice1",
            voiceName: "Test Voice"
        )

        try record.saveAudio(audioData, to: storage, mode: .local)

        #expect(record.fileReference != nil)
        #expect(record.storageMode == .local)
        #expect(record.cloudKitAudioAsset == nil)
    }

    @Test("Audio record can save to CloudKit storage")
    func audioSaveToCloudKitStorage() throws {
        let requestID = UUID()
        let storage = StorageAreaReference.temporary(requestID: requestID)
        let audioData = Data([0x01, 0x02, 0x03, 0x04])

        let record = GeneratedAudioRecord(
            id: requestID,
            providerId: "test",
            requestorID: "test.audio",
            audioData: nil,
            format: "mp3",
            voiceID: "voice1",
            voiceName: "Test Voice"
        )

        try record.saveAudio(audioData, to: storage, mode: .cloudKit)

        #expect(record.fileReference != nil) // Still saves locally too
        #expect(record.cloudKitAudioAsset != nil)
        #expect(record.storageMode == .cloudKit)
        #expect(record.syncStatus == .pending)
    }

    @Test("Audio record can save to hybrid storage")
    func audioSaveToHybridStorage() throws {
        let requestID = UUID()
        let storage = StorageAreaReference.temporary(requestID: requestID)
        let audioData = Data([0x01, 0x02, 0x03, 0x04])

        let record = GeneratedAudioRecord(
            id: requestID,
            providerId: "test",
            requestorID: "test.audio",
            audioData: nil,
            format: "mp3",
            voiceID: "voice1",
            voiceName: "Test Voice"
        )

        try record.saveAudio(audioData, to: storage, mode: .hybrid)

        #expect(record.fileReference != nil)
        #expect(record.cloudKitAudioAsset != nil)
        #expect(record.storageMode == .hybrid)
    }

    @Test("Text record can save small text in-memory")
    func textSaveSmallInMemory() throws {
        let text = "Small text"
        let record = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            text: nil,
            wordCount: 2,
            characterCount: text.count
        )

        try record.saveText(text, mode: .local)

        #expect(record.text == text)
        #expect(record.fileReference == nil)
    }

    @Test("Text record can save large text to file")
    func textSaveLargeToFile() throws {
        let requestID = UUID()
        let storage = StorageAreaReference.temporary(requestID: requestID)
        let largeText = String(repeating: "A", count: 60_000)

        let record = GeneratedTextRecord(
            id: requestID,
            providerId: "test",
            requestorID: "test.text",
            text: nil,
            wordCount: 60_000,
            characterCount: 60_000
        )

        try record.saveText(largeText, to: storage, mode: .local)

        #expect(record.text == nil) // Not stored in memory
        #expect(record.fileReference != nil) // Stored in file
    }

    @Test("Image record dual storage saves both local and CloudKit")
    func imageDualStorage() throws {
        let requestID = UUID()
        let storage = StorageAreaReference.temporary(requestID: requestID)
        let imageData = Data(repeating: 0xFF, count: 1024)

        let record = GeneratedImageRecord(
            id: requestID,
            providerId: "test",
            requestorID: "test.image",
            imageData: nil,
            format: "png",
            width: 100,
            height: 100
        )

        try record.saveImage(imageData, to: storage, mode: .hybrid)

        #expect(record.fileReference != nil)
        #expect(record.cloudKitImageAsset != nil)
        #expect(record.cloudKitImageAsset?.count == 1024)
    }

    // MARK: - ModelConfiguration Tests

    // MARK: - ModelConfiguration Tests

    @Test("SwiftCompartidoSchema includes all model types")
    func schemaIncludesAllModels() {
        let models = SwiftCompartidoSchema.models

        #expect(models.count == 4)
        #expect(models.contains { $0 == GeneratedTextRecord.self })
        #expect(models.contains { $0 == GeneratedAudioRecord.self })
        #expect(models.contains { $0 == GeneratedImageRecord.self })
        #expect(models.contains { $0 == GeneratedEmbeddingRecord.self })
    }

    // MARK: - Conflict Resolution Tests

    @Test("Conflict version increments correctly")
    func conflictVersionIncrement() {
        let record = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            text: "Test",
            wordCount: 1,
            characterCount: 4
        )

        #expect(record.conflictVersion == 1)

        record.conflictVersion += 1
        #expect(record.conflictVersion == 2)
    }

    @Test("Sync status can be updated")
    func syncStatusUpdate() {
        let record = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            text: "Test",
            wordCount: 1,
            characterCount: 4,
            storageMode: .cloudKit
        )

        #expect(record.syncStatus == .pending)

        record.syncStatus = .synced
        record.lastSyncedAt = Date()

        #expect(record.syncStatus == .synced)
        #expect(record.lastSyncedAt != nil)
    }

    @Test("Conflict resolution prefers higher version number")
    func conflictResolutionPrefersHigherVersion() {
        let localRecord = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            text: "Local",
            wordCount: 1,
            characterCount: 5
        )
        localRecord.conflictVersion = 2

        let remoteRecord = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            text: "Remote",
            wordCount: 1,
            characterCount: 6
        )
        remoteRecord.conflictVersion = 3

        let resolution = localRecord.resolveConflict(with: remoteRecord)
        #expect(resolution == .useRemote)
    }

    @Test("Conflict resolution with equal versions uses most recent timestamp")
    func conflictResolutionWithEqualVersionsUsesTimestamp() {
        let now = Date()
        let earlier = now.addingTimeInterval(-3600) // 1 hour ago

        let localRecord = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            text: "Local",
            wordCount: 1,
            characterCount: 5
        )
        localRecord.conflictVersion = 1
        localRecord.modifiedAt = earlier

        let remoteRecord = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            text: "Remote",
            wordCount: 1,
            characterCount: 6
        )
        remoteRecord.conflictVersion = 1
        remoteRecord.modifiedAt = now

        let resolution = localRecord.resolveConflict(with: remoteRecord)
        #expect(resolution == .useRemote, "Should use remote because it has more recent timestamp")
    }

    @Test("Conflict resolution with equal versions and timestamps prefers local")
    func conflictResolutionWithEqualVersionsAndTimestampsUsesLocal() {
        let now = Date()

        let localRecord = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            text: "Local",
            wordCount: 1,
            characterCount: 5
        )
        localRecord.conflictVersion = 1
        localRecord.modifiedAt = now

        let remoteRecord = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            text: "Remote",
            wordCount: 1,
            characterCount: 6
        )
        remoteRecord.conflictVersion = 1
        remoteRecord.modifiedAt = now

        let resolution = localRecord.resolveConflict(with: remoteRecord)
        #expect(resolution == .useLocal, "Should use local when everything is equal")
    }

    @Test("Conflict resolution handles newly created records correctly")
    func conflictResolutionHandlesNewRecordsCorrectly() {
        // Simulate two devices creating records simultaneously
        let device1Time = Date()
        let device2Time = device1Time.addingTimeInterval(0.5) // 500ms later

        let device1Record = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            text: "Device 1",
            wordCount: 2,
            characterCount: 8
        )
        device1Record.modifiedAt = device1Time
        // conflictVersion = 1 (default)

        let device2Record = GeneratedTextRecord(
            providerId: "test",
            requestorID: "test.text",
            text: "Device 2",
            wordCount: 2,
            characterCount: 8
        )
        device2Record.modifiedAt = device2Time
        // conflictVersion = 1 (default)

        // Device 1 sees Device 2's record as remote
        let resolution = device1Record.resolveConflict(with: device2Record)
        #expect(resolution == .useRemote, "Should use Device 2's record because it's more recent")
    }
}
