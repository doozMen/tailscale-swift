import Foundation
import Logging

@testable import TailscaleSwift

/// Mock Tailscale service for testing
/// This allows us to inject mock command responses without executing actual subprocess calls
actor MockTailscaleService {
  private var mockResponses: [String: Result<String, Error>] = [:]
  private let logger: Logger?

  init(logger: Logger? = nil) {
    self.logger = logger
  }

  /// Configure a mock response for a specific command
  func setMockResponse(for command: String, response: Result<String, Error>) {
    mockResponses[command] = response
  }

  /// Execute a mocked command
  func executeCommand(arguments: [String]) async throws -> String {
    let commandKey = arguments.joined(separator: " ")

    guard let mockResponse = mockResponses[commandKey] else {
      throw TailscaleError.commandFailed("No mock configured for: \(commandKey)")
    }

    switch mockResponse {
    case .success(let output):
      return output
    case .failure(let error):
      throw error
    }
  }

  // MARK: - TailscaleService Methods (Mocked)

  func getIP() async throws -> String {
    logger?.debug("Getting Tailscale IP address (mocked)")

    let output = try await executeCommand(arguments: ["ip", "-4"])
    let ip = output.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !ip.isEmpty, ip.starts(with: "100.") else {
      throw TailscaleError.invalidIP(ip)
    }

    logger?.info("Tailscale IP retrieved (mocked)", metadata: ["ip": .string(ip)])
    return ip
  }

  func getHostname() async throws -> String {
    logger?.debug("Getting Tailscale hostname (mocked)")

    let status = try await getStatus()
    return status.hostname
  }

  func getStatus() async throws -> TailscaleStatus {
    logger?.debug("Getting Tailscale status (mocked)")

    let output = try await executeCommand(arguments: ["status", "--json"])

    guard let data = output.data(using: .utf8) else {
      throw TailscaleError.invalidOutput
    }

    let decoder = JSONDecoder()
    let statusResponse = try decoder.decode(TailscaleStatusResponse.self, from: data)

    let selfNode = statusResponse.`self`
    let selfPeer = statusResponse.peer[selfNode.publicKey]

    let status = TailscaleStatus(
      hostname: selfNode.hostName,
      ip: selfPeer?.tailscaleIPs.first ?? "",
      online: selfPeer?.online ?? false,
      peerCount: statusResponse.peer.count - 1
    )

    logger?.info(
      "Tailscale status retrieved (mocked)",
      metadata: [
        "hostname": .string(status.hostname),
        "ip": .string(status.ip),
        "online": .string(String(status.online)),
      ])

    return status
  }

  func listDevices() async throws -> [TailscaleDevice] {
    logger?.debug("Listing Tailscale devices (mocked)")

    let output = try await executeCommand(arguments: ["status", "--json"])

    guard let data = output.data(using: .utf8) else {
      throw TailscaleError.invalidOutput
    }

    let decoder = JSONDecoder()
    let statusResponse = try decoder.decode(TailscaleStatusResponse.self, from: data)

    let selfPublicKey = statusResponse.`self`.publicKey

    let devices = statusResponse.peer.compactMap { (publicKey, peer) -> TailscaleDevice? in
      guard publicKey != selfPublicKey else { return nil }

      return TailscaleDevice(
        id: publicKey,
        hostname: peer.hostName,
        ip: peer.tailscaleIPs.first ?? "",
        online: peer.online,
        os: peer.os
      )
    }

    logger?.info(
      "Tailscale devices listed (mocked)", metadata: ["count": .string(String(devices.count))])
    return devices
  }
}
