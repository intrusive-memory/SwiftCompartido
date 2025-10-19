//
//  CloudKitModelConfiguration.swift
//  SwiftCompartido
//
//  ModelConfiguration extensions for CloudKit support
//

import Foundation
import SwiftData
import CloudKit

/// ModelConfiguration extensions for CloudKit
extension ModelConfiguration {

    /// Creates a local-only configuration (no CloudKit sync)
    ///
    /// Use this for documents that should never sync to iCloud.
    ///
    /// ## Example
    /// ```swift
    /// let container = try ModelContainer(
    ///     for: GeneratedAudioRecord.self, GeneratedTextRecord.self,
    ///     configurations: .localOnly
    /// )
    /// ```
    public static var localOnly: ModelConfiguration {
        ModelConfiguration(
            schema: SwiftCompartidoSchema.schema,
            isStoredInMemoryOnly: false
        )
    }

    /// Creates a CloudKit private database configuration
    ///
    /// Use this for syncing records to the user's private CloudKit database.
    /// Records are accessible only to the signed-in user.
    ///
    /// ## Example
    /// ```swift
    /// let container = try ModelContainer(
    ///     for: GeneratedAudioRecord.self, GeneratedTextRecord.self,
    ///     configurations: .cloudKitPrivate()
    /// )
    /// ```
    ///
    /// - Parameter containerIdentifier: iCloud container identifier
    /// - Returns: ModelConfiguration with CloudKit private database
    public static func cloudKitPrivate(
        containerIdentifier: String = CloudKitConfiguration.default.containerIdentifier
    ) -> ModelConfiguration {
        ModelConfiguration(
            schema: SwiftCompartidoSchema.schema,
            cloudKitDatabase: .private(containerIdentifier)
        )
    }

    /// Creates an automatic CloudKit configuration
    ///
    /// SwiftData will automatically choose the appropriate CloudKit database.
    /// This is useful for apps that want CloudKit sync with minimal configuration.
    ///
    /// ## Example
    /// ```swift
    /// let container = try ModelContainer(
    ///     for: GeneratedAudioRecord.self, GeneratedTextRecord.self,
    ///     configurations: .cloudKitAutomatic()
    /// )
    /// ```
    ///
    /// - Parameter containerIdentifier: iCloud container identifier
    /// - Returns: ModelConfiguration with automatic CloudKit database selection
    public static func cloudKitAutomatic(
        containerIdentifier: String = CloudKitConfiguration.default.containerIdentifier
    ) -> ModelConfiguration {
        ModelConfiguration(
            schema: SwiftCompartidoSchema.schema,
            cloudKitDatabase: .automatic
        )
    }
}

/// Schema definition for SwiftCompartido models
public struct SwiftCompartidoSchema {

    /// All SwiftData models in SwiftCompartido
    public static var models: [any PersistentModel.Type] {
        [
            GeneratedTextRecord.self,
            GeneratedAudioRecord.self,
            GeneratedImageRecord.self,
            GeneratedEmbeddingRecord.self
        ]
    }

    /// SwiftData schema for all models
    public static var schema: Schema {
        Schema(models)
    }
}

/// ModelContainer factory for common configurations
public struct SwiftCompartidoContainer {

    /// Creates a local-only container (no CloudKit)
    ///
    /// - Returns: ModelContainer configured for local storage only
    /// - Throws: ModelContainer initialization errors
    public static func makeLocalContainer() throws -> ModelContainer {
        try ModelContainer(
            for: SwiftCompartidoSchema.schema,
            configurations: .localOnly
        )
    }

    /// Creates a CloudKit private container
    ///
    /// - Parameter containerIdentifier: iCloud container identifier
    /// - Returns: ModelContainer configured for CloudKit private database
    /// - Throws: ModelContainer initialization errors
    public static func makeCloudKitPrivateContainer(
        containerIdentifier: String = CloudKitConfiguration.default.containerIdentifier
    ) throws -> ModelContainer {
        try ModelContainer(
            for: SwiftCompartidoSchema.schema,
            configurations: .cloudKitPrivate(containerIdentifier: containerIdentifier)
        )
    }

    /// Creates an automatic CloudKit container
    ///
    /// - Parameter containerIdentifier: iCloud container identifier
    /// - Returns: ModelContainer configured for automatic CloudKit database
    /// - Throws: ModelContainer initialization errors
    public static func makeCloudKitAutomaticContainer(
        containerIdentifier: String = CloudKitConfiguration.default.containerIdentifier
    ) throws -> ModelContainer {
        try ModelContainer(
            for: SwiftCompartidoSchema.schema,
            configurations: .cloudKitAutomatic(containerIdentifier: containerIdentifier)
        )
    }

    /// Creates a hybrid container with both local and CloudKit configurations
    ///
    /// This allows some records to be local-only while others sync to CloudKit.
    ///
    /// - Parameter containerIdentifier: iCloud container identifier
    /// - Returns: ModelContainer with dual configurations
    /// - Throws: ModelContainer initialization errors
    public static func makeHybridContainer(
        containerIdentifier: String = CloudKitConfiguration.default.containerIdentifier
    ) throws -> ModelContainer {
        try ModelContainer(
            for: SwiftCompartidoSchema.schema,
            configurations: [
                .localOnly,
                .cloudKitPrivate(containerIdentifier: containerIdentifier)
            ]
        )
    }
}

/// CloudKit container helpers
extension CKContainer {

    /// SwiftCompartido default CloudKit container
    public static var swiftCompartido: CKContainer {
        CKContainer(identifier: CloudKitConfiguration.default.containerIdentifier)
    }
}

/// CloudKit database helpers
extension CKDatabase {

    /// Checks if CloudKit is available
    ///
    /// - Returns: `true` if user is signed into iCloud, `false` otherwise
    public static func isCloudKitAvailable() async -> Bool {
        do {
            let status = try await CKContainer.swiftCompartido.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }
}
