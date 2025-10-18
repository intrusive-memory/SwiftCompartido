import Testing
import Foundation
@testable import SwiftCompartido

struct AIRequestTests {

    @Test("AIRequest initializes with defaults")
    func testInitialization() {
        let request = AIRequest(prompt: "Test prompt")

        #expect(request.prompt == "Test prompt")
        #expect(request.parameters.isEmpty)
        #expect(request.timeout == nil)
        #expect(request.useCache == true)
        #expect(request.metadata.isEmpty)
        #expect(request.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
    }

    @Test("AIRequest initializes with all parameters")
    func testFullInitialization() {
        let parameters = ["temperature": "0.7", "max_tokens": "100"]
        let metadata = ["source": "test"]

        let request = AIRequest(
            prompt: "Test prompt",
            parameters: parameters,
            timeout: 30.0,
            useCache: false,
            metadata: metadata
        )

        #expect(request.prompt == "Test prompt")
        #expect(request.parameters == parameters)
        #expect(request.timeout == 30.0)
        #expect(request.useCache == false)
        #expect(request.metadata == metadata)
    }

    @Test("AIRequest withParameters merges parameters")
    func testWithParameters() {
        let original = AIRequest(
            prompt: "Test",
            parameters: ["a": "1", "b": "2"]
        )

        let updated = original.withParameters(["b": "3", "c": "4"])

        #expect(updated.parameters["a"] == "1")
        #expect(updated.parameters["b"] == "3") // Updated
        #expect(updated.parameters["c"] == "4") // Added
        #expect(updated.prompt == original.prompt)
    }

    @Test("AIRequest withTimeout updates timeout")
    func testWithTimeout() {
        let original = AIRequest(prompt: "Test", timeout: 10.0)
        let updated = original.withTimeout(20.0)

        #expect(updated.timeout == 20.0)
        #expect(updated.prompt == original.prompt)
    }

    @Test("AIRequest withCache updates cache setting")
    func testWithCache() {
        let original = AIRequest(prompt: "Test", useCache: true)
        let updated = original.withCache(false)

        #expect(updated.useCache == false)
        #expect(updated.prompt == original.prompt)
    }

    @Test("AIRequest is Hashable by ID")
    func testHashable() {
        let request1 = AIRequest(prompt: "Test")
        let request2 = AIRequest(prompt: "Test")

        #expect(request1 != request2) // Different IDs
        #expect(request1.hashValue != request2.hashValue)
    }

    @Test("AIRequest equality based on ID")
    func testEquality() {
        let request1 = AIRequest(prompt: "Test")
        let request2 = request1

        #expect(request1 == request2)
    }

    @Test("AIRequest is Sendable")
    func testSendable() async {
        let request = AIRequest(prompt: "Test")

        await Task {
            // Should compile without warnings
            let _ = request.prompt
        }.value
    }
}
