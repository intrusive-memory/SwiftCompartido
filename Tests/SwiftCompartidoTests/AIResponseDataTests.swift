import Testing
import Foundation
@testable import SwiftCompartido

struct AIResponseDataTests {

    // MARK: - Initialization Tests

    @Test("AIResponseData initializes with success result")
    func testSuccessInitialization() {
        let requestID = UUID()
        let content = ResponseContent.text("Hello, World!")

        let response = AIResponseData(
            requestID: requestID,
            providerID: "test-provider",
            content: content,
            metadata: ["key": "value"],
            usage: UsageStats(promptTokens: 10, completionTokens: 20)
        )

        #expect(response.requestID == requestID)
        #expect(response.id == requestID)
        #expect(response.providerID == "test-provider")
        #expect(response.isSuccess)
        #expect(!response.isFailure)
        #expect(response.content?.text == "Hello, World!")
        #expect(response.error == nil)
        #expect(response.metadata == ["key": "value"])
        #expect(response.usage?.promptTokens == 10)
        #expect(response.usage?.completionTokens == 20)
    }

    @Test("AIResponseData initializes with failure result")
    func testFailureInitialization() {
        let requestID = UUID()
        let error = AIServiceError.networkError("Connection failed")

        let response = AIResponseData(
            requestID: requestID,
            providerID: "test-provider",
            error: error,
            metadata: ["retry": "3"]
        )

        #expect(response.requestID == requestID)
        #expect(response.providerID == "test-provider")
        #expect(response.isFailure)
        #expect(!response.isSuccess)
        #expect(response.content == nil)
        #expect(response.error != nil)
        #expect(response.metadata == ["retry": "3"])
    }

    @Test("AIResponseData initializes with Result type")
    func testResultInitialization() {
        let requestID = UUID()
        let result: Result<ResponseContent, AIServiceError> = .success(.text("Test"))

        let response = AIResponseData(
            requestID: requestID,
            providerID: "test-provider",
            result: result
        )

        #expect(response.isSuccess)
        #expect(response.content?.text == "Test")
    }

    // MARK: - ResponseContent Tests

    @Test("ResponseContent text type")
    func testResponseContentText() {
        let content = ResponseContent.text("Sample text")

        #expect(content.contentType == .text)
        #expect(content.text == "Sample text")
        #expect(content.dataContent != nil)
        #expect(content.audioContent == nil)
        #expect(content.imageContent == nil)
        #expect(content.structuredContent == nil)
    }

    @Test("ResponseContent data type")
    func testResponseContentData() {
        let data = Data([0x01, 0x02, 0x03])
        let content = ResponseContent.data(data)

        #expect(content.contentType == .data)
        #expect(content.dataContent == data)
        #expect(content.text == nil)
    }

    @Test("ResponseContent audio type")
    func testResponseContentAudio() {
        let audioData = Data("audio".utf8)
        let content = ResponseContent.audio(audioData, format: .mp3)

        #expect(content.contentType == .audio)
        #expect(content.audioContent?.data == audioData)
        #expect(content.audioContent?.format == .mp3)
        #expect(content.text == nil)
    }

    @Test("ResponseContent image type")
    func testResponseContentImage() {
        let imageData = Data("image".utf8)
        let content = ResponseContent.image(imageData, format: .png)

        #expect(content.contentType == .image)
        #expect(content.imageContent?.data == imageData)
        #expect(content.imageContent?.format == .png)
        #expect(content.text == nil)
    }

    @Test("ResponseContent structured type")
    func testResponseContentStructured() {
        let structured: [String: SendableValue] = [
            "key1": .string("value1"),
            "key2": .int(42),
            "key3": .double(3.14),
            "key4": .bool(true)
        ]
        let content = ResponseContent.structured(structured)

        #expect(content.contentType == .structured)
        #expect(content.structuredContent?["key1"]?.stringValue == "value1")
        #expect(content.structuredContent?["key2"]?.intValue == 42)
        #expect(content.structuredContent?["key3"]?.doubleValue == 3.14)
        #expect(content.structuredContent?["key4"]?.boolValue == true)
    }

    // MARK: - SendableValue Tests

    @Test("SendableValue string type")
    func testSendableValueString() {
        let value = SendableValue.string("test")

        #expect(value.stringValue == "test")
        #expect(value.intValue == nil)
        #expect(value.doubleValue == nil)
        #expect(value.boolValue == nil)
        #expect(!value.isNull)
    }

    @Test("SendableValue int type")
    func testSendableValueInt() {
        let value = SendableValue.int(42)

        #expect(value.intValue == 42)
        #expect(value.stringValue == nil)
    }

    @Test("SendableValue double type")
    func testSendableValueDouble() {
        let value = SendableValue.double(3.14159)

        #expect(value.doubleValue == 3.14159)
        #expect(value.intValue == nil)
    }

    @Test("SendableValue bool type")
    func testSendableValueBool() {
        let trueValue = SendableValue.bool(true)
        let falseValue = SendableValue.bool(false)

        #expect(trueValue.boolValue == true)
        #expect(falseValue.boolValue == false)
    }

    @Test("SendableValue null type")
    func testSendableValueNull() {
        let value = SendableValue.null

        #expect(value.isNull)
        #expect(value.stringValue == nil)
        #expect(value.intValue == nil)
    }

    @Test("SendableValue array type")
    func testSendableValueArray() {
        let array: [SendableValue] = [
            .string("a"),
            .int(1),
            .bool(true)
        ]
        let value = SendableValue.array(array)

        #expect(value.arrayValue?.count == 3)
        #expect(value.arrayValue?[0].stringValue == "a")
        #expect(value.arrayValue?[1].intValue == 1)
        #expect(value.arrayValue?[2].boolValue == true)
    }

    @Test("SendableValue dictionary type")
    func testSendableValueDictionary() {
        let dict: [String: SendableValue] = [
            "name": .string("John"),
            "age": .int(30)
        ]
        let value = SendableValue.dictionary(dict)

        #expect(value.dictionaryValue?["name"]?.stringValue == "John")
        #expect(value.dictionaryValue?["age"]?.intValue == 30)
    }

    @Test("SendableValue nested structures")
    func testSendableValueNested() {
        let nested: [String: SendableValue] = [
            "user": .dictionary([
                "name": .string("Jane"),
                "tags": .array([.string("admin"), .string("user")])
            ])
        ]
        let value = SendableValue.dictionary(nested)

        let user = value.dictionaryValue?["user"]?.dictionaryValue
        #expect(user?["name"]?.stringValue == "Jane")
        #expect(user?["tags"]?.arrayValue?.count == 2)
    }

    // MARK: - UsageStats Tests

    @Test("UsageStats initializes with all parameters")
    func testUsageStatsFullInitialization() {
        let usage = UsageStats(
            promptTokens: 100,
            completionTokens: 200,
            totalTokens: 300,
            costUSD: 0.05,
            durationSeconds: 1.5
        )

        #expect(usage.promptTokens == 100)
        #expect(usage.completionTokens == 200)
        #expect(usage.totalTokens == 300)
        #expect(usage.costUSD == 0.05)
        #expect(usage.cost == 0.05) // Legacy property
        #expect(usage.durationSeconds == 1.5)
    }

    @Test("UsageStats initializes with minimal parameters")
    func testUsageStatsMinimalInitialization() {
        let usage = UsageStats()

        #expect(usage.promptTokens == nil)
        #expect(usage.completionTokens == nil)
        #expect(usage.totalTokens == nil)
        #expect(usage.costUSD == nil)
        #expect(usage.durationSeconds == nil)
    }

    @Test("UsageStats initializes with partial parameters")
    func testUsageStatsPartialInitialization() {
        let usage = UsageStats(
            promptTokens: 50,
            completionTokens: 75
        )

        #expect(usage.promptTokens == 50)
        #expect(usage.completionTokens == 75)
        #expect(usage.totalTokens == nil)
        #expect(usage.costUSD == nil)
    }

    @Test("UsageStats equality")
    func testUsageStatsEquality() {
        let usage1 = UsageStats(
            promptTokens: 100,
            completionTokens: 200,
            totalTokens: 300,
            costUSD: 0.05,
            durationSeconds: 1.5
        )

        let usage2 = UsageStats(
            promptTokens: 100,
            completionTokens: 200,
            totalTokens: 300,
            costUSD: 0.05,
            durationSeconds: 1.5
        )

        let usage3 = UsageStats(
            promptTokens: 100,
            completionTokens: 201
        )

        #expect(usage1 == usage2)
        #expect(usage1 != usage3)
    }

    // MARK: - AudioFormat Tests

    @Test("AudioFormat all cases")
    func testAudioFormatCases() {
        #expect(AudioFormat.mp3.rawValue == "mp3")
        #expect(AudioFormat.wav.rawValue == "wav")
        #expect(AudioFormat.aac.rawValue == "aac")
        #expect(AudioFormat.flac.rawValue == "flac")
        #expect(AudioFormat.ogg.rawValue == "ogg")
        #expect(AudioFormat.opus.rawValue == "opus")
        #expect(AudioFormat.pcm.rawValue == "pcm")
        #expect(AudioFormat.unknown.rawValue == "unknown")
    }

    // MARK: - ImageFormat Tests

    @Test("ImageFormat all cases")
    func testImageFormatCases() {
        #expect(ImageFormat.jpeg.rawValue == "jpeg")
        #expect(ImageFormat.png.rawValue == "png")
        #expect(ImageFormat.gif.rawValue == "gif")
        #expect(ImageFormat.webp.rawValue == "webp")
        #expect(ImageFormat.heic.rawValue == "heic")
        #expect(ImageFormat.tiff.rawValue == "tiff")
        #expect(ImageFormat.bmp.rawValue == "bmp")
        #expect(ImageFormat.unknown.rawValue == "unknown")
    }

    // MARK: - Integration Tests

    @Test("AIResponseData with text content and usage")
    func testIntegrationTextWithUsage() {
        let requestID = UUID()
        let content = ResponseContent.text("Generated text content")
        let usage = UsageStats(
            promptTokens: 10,
            completionTokens: 5,
            totalTokens: 15,
            costUSD: 0.001,
            durationSeconds: 0.5
        )

        let response = AIResponseData(
            requestID: requestID,
            providerID: "openai",
            content: content,
            metadata: ["model": "gpt-4"],
            usage: usage
        )

        #expect(response.isSuccess)
        #expect(response.content?.text == "Generated text content")
        #expect(response.usage?.totalTokens == 15)
        #expect(response.usage?.costUSD == 0.001)
        #expect(response.usage?.durationSeconds == 0.5)
        #expect(response.metadata["model"] == "gpt-4")
    }

    @Test("AIResponseData with audio content")
    func testIntegrationAudioContent() {
        let audioData = Data(repeating: 0x00, count: 1024)
        let content = ResponseContent.audio(audioData, format: .mp3)

        let response = AIResponseData(
            requestID: UUID(),
            providerID: "elevenlabs",
            content: content
        )

        #expect(response.isSuccess)
        #expect(response.content?.contentType == .audio)
        #expect(response.content?.audioContent?.data.count == 1024)
        #expect(response.content?.audioContent?.format == .mp3)
    }

    @Test("AIResponseData with image content")
    func testIntegrationImageContent() {
        let imageData = Data(repeating: 0xFF, count: 2048)
        let content = ResponseContent.image(imageData, format: .png)

        let response = AIResponseData(
            requestID: UUID(),
            providerID: "dall-e",
            content: content
        )

        #expect(response.isSuccess)
        #expect(response.content?.contentType == .image)
        #expect(response.content?.imageContent?.data.count == 2048)
        #expect(response.content?.imageContent?.format == .png)
    }

    @Test("AIResponseData error handling")
    func testIntegrationErrorHandling() {
        let errors: [AIServiceError] = [
            .networkError("Connection timeout"),
            .authenticationFailed("Invalid API key"),
            .invalidRequest("Missing parameter"),
            .rateLimitExceeded("Too many requests"),
            .providerError("Service unavailable"),
            .unexpectedResponseFormat("Malformed JSON"),
            .timeout("Request timeout"),
            .configurationError("Invalid config"),
            .validationError("Data validation failed")
        ]

        for error in errors {
            let response = AIResponseData(
                requestID: UUID(),
                providerID: "test",
                error: error
            )

            #expect(response.isFailure)
            #expect(!response.isSuccess)
            #expect(response.error != nil)
            #expect(response.content == nil)
        }
    }

    @Test("AIResponseData is Sendable")
    func testSendable() async {
        let response = AIResponseData(
            requestID: UUID(),
            providerID: "test",
            content: .text("Test")
        )

        await Task {
            // Should compile without warnings
            let _ = response.requestID
            let _ = response.content
        }.value
    }

    @Test("ResponseContent data conversion for text")
    func testResponseContentDataConversionText() {
        let content = ResponseContent.text("Hello")
        let data = content.dataContent

        #expect(data != nil)
        let string = String(data: data!, encoding: .utf8)
        #expect(string == "Hello")
    }

    @Test("ResponseContent data conversion for structured")
    func testResponseContentDataConversionStructured() {
        let structured: [String: SendableValue] = [
            "key": .string("value")
        ]
        let content = ResponseContent.structured(structured)
        let data = content.dataContent

        #expect(data != nil)
        // Data should be JSON-encoded
        #expect(data!.count > 0)
    }

    @Test("AIResponseData timestamp is set")
    func testTimestampIsSet() {
        let before = Date()
        let response = AIResponseData(
            requestID: UUID(),
            providerID: "test",
            content: .text("Test")
        )
        let after = Date()

        #expect(response.receivedAt >= before)
        #expect(response.receivedAt <= after)
    }

    @Test("ContentType all cases")
    func testContentTypeCases() {
        let allCases = ResponseContent.ContentType.allCases
        #expect(allCases.count == 5)
        #expect(allCases.contains(.text))
        #expect(allCases.contains(.data))
        #expect(allCases.contains(.audio))
        #expect(allCases.contains(.image))
        #expect(allCases.contains(.structured))
    }
}
