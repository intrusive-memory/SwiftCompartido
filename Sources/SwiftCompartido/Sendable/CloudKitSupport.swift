//
//  CloudKitSupport.swift
//  SwiftCompartido
//
//  CloudKit sync support for SwiftData models
//

import Foundation
import CloudKit

/// Sync status for CloudKit records
public enum SyncStatus: String, Codable, Sendable {
    /// Not yet synced to CloudKit
    case pending

    /// Successfully synced to CloudKit
    case synced

    /// Conflict detected during sync
    case conflict

    /// Sync failed with error
    case failed

    /// Local-only, not configured for sync
    case localOnly
}

/// Storage mode for generated content
public enum StorageMode: String, Codable, Sendable {
    /// Stored locally in .guion bundle (Phase 6 architecture)
    case local

    /// Stored in CloudKit using CKAsset
    case cloudKit

    /// Hybrid: Both local and CloudKit storage
    case hybrid
}

/// CloudKit sync metadata protocol
public protocol CloudKitSyncable {
    /// CloudKit record identifier
    var cloudKitRecordID: String? { get set }

    /// CloudKit change tag for conflict detection
    var cloudKitChangeTag: String? { get set }

    /// When last synced to CloudKit
    var lastSyncedAt: Date? { get set }

    /// Current sync status
    var syncStatus: SyncStatus { get set }

    /// Owner's user record ID
    var ownerUserRecordID: String? { get set }

    /// User record IDs with access
    var sharedWith: [String]? { get set }

    /// Conflict resolution version counter
    var conflictVersion: Int { get set }

    /// Storage mode (local, CloudKit, or hybrid)
    var storageMode: StorageMode { get set }

    /// When this record was last modified (required for conflict resolution)
    var modifiedAt: Date { get set }

    /// Whether CloudKit features are enabled for this record
    var isCloudKitEnabled: Bool { get }
}

/// Extension providing default CloudKit behavior
extension CloudKitSyncable {
    /// Whether CloudKit features are enabled
    public var isCloudKitEnabled: Bool {
        cloudKitRecordID != nil || storageMode != .local
    }
}

/// Model configuration helpers for CloudKit
public struct CloudKitConfiguration {
    /// Container identifier for CloudKit
    public let containerIdentifier: String

    /// Database scope (private, public, or shared)
    public let databaseScope: CKDatabase.Scope

    /// Creates a CloudKit configuration
    ///
    /// - Parameters:
    ///   - containerIdentifier: iCloud container identifier
    ///   - databaseScope: Database scope (defaults to private)
    public init(
        containerIdentifier: String,
        databaseScope: CKDatabase.Scope = .private
    ) {
        self.containerIdentifier = containerIdentifier
        self.databaseScope = databaseScope
    }

    /// Default configuration for SwiftCompartido
    public static var `default`: CloudKitConfiguration {
        CloudKitConfiguration(
            containerIdentifier: "iCloud.com.intrusivememory.SwiftCompartido",
            databaseScope: .private
        )
    }
}
