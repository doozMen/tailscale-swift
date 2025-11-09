import Foundation
import Testing

@testable import TailscaleSwift

/// Integration tests for TailscaleService
/// These tests use the real TailscaleService and will skip if Tailscale is not installed
@Suite("Integration Tests (Real Tailscale CLI)")
struct IntegrationTests {

  // MARK: - Availability Tests

  @Test("isAvailable returns true when Tailscale is installed")
  func testIsAvailableWithRealCLI() async {
    let service = TailscaleService()
    let available = await service.isAvailable()

    // This test documents the expected behavior but doesn't enforce it
    // since Tailscale may or may not be installed on the test machine
    if available {
      print("Tailscale CLI is available at expected path")
    } else {
      print("Tailscale CLI is not installed (test will skip real CLI tests)")
    }
  }

  @Test("isAvailable with custom path checks correct location")
  func testIsAvailableWithCustomPath() async {
    let service = TailscaleService(tailscalePath: "/usr/local/bin/tailscale")
    let available = await service.isAvailable()

    if available {
      print("Tailscale CLI found at /usr/local/bin/tailscale")
    } else {
      print("Tailscale CLI not found at /usr/local/bin/tailscale")
    }
  }

  @Test("isAvailable returns false for invalid path")
  func testIsAvailableWithInvalidPath() async {
    let service = TailscaleService(tailscalePath: "/nonexistent/tailscale")
    let available = await service.isAvailable()

    #expect(available == false)
  }

  // MARK: - Connection Tests (Skipped if not installed/connected)

  @Test("isConnected returns false when not connected", .enabled(if: false))
  func testIsConnectedWhenNotConnected() async {
    let service = TailscaleService()
    let connected = await service.isConnected()

    // This test is disabled by default since we can't guarantee the connection state
    // Enable it manually if you want to test with a real Tailscale installation
    print("Connection status: \(connected)")
  }

  @Test("getIP works with real Tailscale CLI", .enabled(if: false))
  func testGetIPWithRealCLI() async throws {
    // This test is disabled by default
    // Enable it manually if you want to test with a real Tailscale installation
    let service = TailscaleService()

    guard await service.isAvailable() else {
      throw XCTSkip("Tailscale not installed")
    }

    let ip = try await service.getIP()
    #expect(ip.starts(with: "100."))
    print("Real Tailscale IP: \(ip)")
  }

  @Test("getStatus works with real Tailscale CLI", .enabled(if: false))
  func testGetStatusWithRealCLI() async throws {
    // This test is disabled by default
    // Enable it manually if you want to test with a real Tailscale installation
    let service = TailscaleService()

    guard await service.isAvailable() else {
      throw XCTSkip("Tailscale not installed")
    }

    let status = try await service.getStatus()
    #expect(!status.hostname.isEmpty)
    #expect(!status.ip.isEmpty)
    print("Real Tailscale status: \(status.hostname), \(status.ip), online: \(status.online)")
  }

  @Test("listDevices works with real Tailscale CLI", .enabled(if: false))
  func testListDevicesWithRealCLI() async throws {
    // This test is disabled by default
    // Enable it manually if you want to test with a real Tailscale installation
    let service = TailscaleService()

    guard await service.isAvailable() else {
      throw XCTSkip("Tailscale not installed")
    }

    let devices = try await service.listDevices()
    print("Real Tailscale devices: \(devices.count)")

    for device in devices.prefix(3) {
      print("  - \(device.hostname) (\(device.ip)) - \(device.os)")
    }
  }
}

// MARK: - XCTSkip Error for Integration Tests

/// Error to skip tests when prerequisites are not met
struct XCTSkip: Error, CustomStringConvertible {
  let message: String

  init(_ message: String) {
    self.message = message
  }

  var description: String {
    "Test skipped: \(message)"
  }
}
