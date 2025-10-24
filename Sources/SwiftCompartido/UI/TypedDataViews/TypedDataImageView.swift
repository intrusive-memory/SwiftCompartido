//
//  TypedDataImageView.swift
//  SwiftCompartido
//
//  SwiftUI view for displaying image content from TypedDataStorage
//

import SwiftUI
import SwiftData
import UIKit

/// SwiftUI view for displaying image content from TypedDataStorage
///
/// Displays images from TypedDataStorage records with MIME type `image/*`.
/// Supports both in-memory and file-based storage.
///
/// ## Example
/// ```swift
/// TypedDataImageView(record: imageRecord, storageArea: storage)
///     .frame(width: 400, height: 400)
/// ```
public struct TypedDataImageView: View {

    // MARK: - Properties

    /// The image storage record to display
    let record: TypedDataStorage

    /// Optional storage area for file-based content
    let storageArea: StorageAreaReference?

    /// Content mode for the image
    let contentMode: ContentMode

    /// Loaded SwiftUI image
    @State private var image: Image?

    /// Error state
    @State private var error: Error?

    /// Loading state
    @State private var isLoading: Bool = true

    // MARK: - Initialization

    /// Creates an image view for a TypedDataStorage record
    ///
    /// - Parameters:
    ///   - record: The image storage record
    ///   - storageArea: Optional storage area for file-based content
    ///   - contentMode: How to fit the image (default: .fit)
    public init(
        record: TypedDataStorage,
        storageArea: StorageAreaReference? = nil,
        contentMode: ContentMode = .fit
    ) {
        self.record = record
        self.storageArea = storageArea
        self.contentMode = contentMode
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading image...")
            } else if let error = error {
                ErrorView(error: error)
            } else if let image = image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Text("No image available")
                    .foregroundColor(.secondary)
            }
        }
        .task {
            await loadImage()
        }
    }

    // MARK: - Loading

    /// Loads image from the record
    private func loadImage() async {
        do {
            let imageData = try record.getBinary(from: storageArea)

            if let uiImage = UIImage(data: imageData) {
                image = Image(uiImage: uiImage)
            } else {
                throw TypedDataError.typeConversionFailed(
                    fromType: "Data",
                    toType: "UIImage",
                    reason: "Invalid image data"
                )
            }

            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
}

/// Error view for displaying load errors
private struct ErrorView: View {
    let error: Error

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text("Failed to load image")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Preview

#if DEBUG
struct TypedDataImageView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a simple 100x100 red square as sample image data
        let imageData: Data = {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
            let image = renderer.image { context in
                UIColor.red.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            }
            return image.pngData() ?? Data()
        }()

        let record = TypedDataStorage(
            providerId: "openai",
            requestorID: "dalle-3",
            mimeType: "image/png",
            binaryValue: imageData,
            prompt: "Generate a red square",
            imageFormat: "png",
            width: 100,
            height: 100
        )

        TypedDataImageView(record: record)
            .frame(width: 200, height: 200)
    }
}
#endif
