import Foundation
import Testing

@testable import TailscaleSwift

/// Tests for TailscaleError enum
/// Verifies error messages, recovery suggestions, and error handling
@Suite("TailscaleError Tests")
struct TailscaleErrorTests {

  // MARK: - Error Description Tests

  @Test("commandFailed error has correct description")
  func testCommandFailedDescription() {
    let error = TailscaleError.commandFailed("Connection timeout")
    #expect(error.errorDescription == "Tailscale command failed: Connection timeout")
  }

  @Test("executionFailed error has correct description")
  func testExecutionFailedDescription() {
    let error = TailscaleError.executionFailed("Process crashed")
    #expect(error.errorDescription == "Failed to execute Tailscale command: Process crashed")
  }

  @Test("invalidIP error has correct description")
  func testInvalidIPDescription() {
    let error = TailscaleError.invalidIP("192.168.1.1")
    #expect(error.errorDescription == "Invalid Tailscale IP address: 192.168.1.1")
  }

  @Test("invalidOutput error has correct description")
  func testInvalidOutputDescription() {
    let error = TailscaleError.invalidOutput
    #expect(error.errorDescription == "Invalid output from Tailscale command")
  }

  @Test("notInstalled error has correct description")
  func testNotInstalledDescription() {
    let error = TailscaleError.notInstalled
    #expect(error.errorDescription == "Tailscale is not installed on this system")
  }

  @Test("notConnected error has correct description")
  func testNotConnectedDescription() {
    let error = TailscaleError.notConnected
    #expect(error.errorDescription == "Tailscale is not connected to a network")
  }

  // MARK: - Recovery Suggestion Tests

  @Test("commandFailed has recovery suggestion")
  func testCommandFailedRecoverySuggestion() {
    let error = TailscaleError.commandFailed("Error")
    #expect(error.recoverySuggestion != nil)
    #expect(error.recoverySuggestion?.contains("tailscale status") == true)
  }

  @Test("executionFailed has recovery suggestion")
  func testExecutionFailedRecoverySuggestion() {
    let error = TailscaleError.executionFailed("Error")
    #expect(error.recoverySuggestion != nil)
    #expect(error.recoverySuggestion?.contains("tailscale status") == true)
  }

  @Test("invalidIP has recovery suggestion")
  func testInvalidIPRecoverySuggestion() {
    let error = TailscaleError.invalidIP("0.0.0.0")
    #expect(error.recoverySuggestion != nil)
    #expect(error.recoverySuggestion?.contains("tailscale up") == true)
  }

  @Test("invalidOutput has recovery suggestion")
  func testInvalidOutputRecoverySuggestion() {
    let error = TailscaleError.invalidOutput
    #expect(error.recoverySuggestion != nil)
    #expect(error.recoverySuggestion?.contains("bug") == true)
  }

  @Test("notInstalled has recovery suggestion with download link")
  func testNotInstalledRecoverySuggestion() {
    let error = TailscaleError.notInstalled
    #expect(error.recoverySuggestion != nil)
    #expect(error.recoverySuggestion?.contains("tailscale.com/download") == true)
  }

  @Test("notConnected has recovery suggestion")
  func testNotConnectedRecoverySuggestion() {
    let error = TailscaleError.notConnected
    #expect(error.recoverySuggestion != nil)
    #expect(error.recoverySuggestion?.contains("tailscale up") == true)
  }

  // MARK: - Error Equality Tests

  @Test("commandFailed errors with different messages are not equal")
  func testCommandFailedEquality() {
    let error1 = TailscaleError.commandFailed("Error 1")
    let error2 = TailscaleError.commandFailed("Error 2")

    // Swift enums with associated values don't have automatic Equatable
    // but we can verify the descriptions are different
    #expect(error1.errorDescription != error2.errorDescription)
  }

  @Test("same error types without associated values are equal")
  func testErrorTypesEquality() {
    let error1 = TailscaleError.invalidOutput
    let error2 = TailscaleError.invalidOutput

    #expect(error1.errorDescription == error2.errorDescription)
  }

  // MARK: - Error Throwing Tests

  @Test("commandFailed can be thrown and caught")
  func testCommandFailedThrows() async {
    func throwError() throws {
      throw TailscaleError.commandFailed("Test error")
    }

    #expect(throws: TailscaleError.self) {
      try throwError()
    }
  }

  @Test("invalidIP can be thrown and caught")
  func testInvalidIPThrows() async {
    func throwError() throws {
      throw TailscaleError.invalidIP("0.0.0.0")
    }

    #expect(throws: TailscaleError.self) {
      try throwError()
    }
  }

  @Test("errors conform to LocalizedError")
  func testLocalizedErrorConformance() {
    let error = TailscaleError.notInstalled
    let localizedError: LocalizedError = error

    #expect(localizedError.errorDescription != nil)
    #expect(localizedError.recoverySuggestion != nil)
  }

  // MARK: - Sendable Conformance Tests

  @Test("TailscaleError is Sendable")
  func testSendableConformance() async {
    // Create error in one task
    let error = await Task {
      TailscaleError.commandFailed("Test")
    }.value

    // Use error in another task
    let description = await Task {
      error.errorDescription
    }.value

    #expect(description != nil)
  }

  // MARK: - Edge Cases

  @Test("error with empty message string")
  func testEmptyErrorMessage() {
    let error = TailscaleError.commandFailed("")
    #expect(error.errorDescription == "Tailscale command failed: ")
  }

  @Test("error with very long message")
  func testLongErrorMessage() {
    let longMessage = String(repeating: "error ", count: 100)
    let error = TailscaleError.executionFailed(longMessage)
    #expect(error.errorDescription?.contains(longMessage) == true)
  }

  @Test("error with special characters in message")
  func testSpecialCharactersInMessage() {
    let message = "Error: \"quoted\", 'apostrophe', <brackets>, & ampersand"
    let error = TailscaleError.commandFailed(message)
    #expect(error.errorDescription?.contains(message) == true)
  }

  @Test("error with newlines in message")
  func testNewlinesInMessage() {
    let message = "Line 1\nLine 2\nLine 3"
    let error = TailscaleError.commandFailed(message)
    #expect(error.errorDescription?.contains(message) == true)
  }

  @Test("error with unicode characters")
  func testUnicodeInMessage() {
    let message = "Error: 🚀 Emoji, 日本語, Русский"
    let error = TailscaleError.commandFailed(message)
    #expect(error.errorDescription?.contains(message) == true)
  }
}
