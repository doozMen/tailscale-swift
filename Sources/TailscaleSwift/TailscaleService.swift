import Foundation
import Logging
import Subprocess

/// Actor-based Tailscale service that wraps the Tailscale CLI
///
/// This service provides a Swift-native interface to Tailscale functionality,
/// including getting the Tailscale IP, checking status, and managing the connection.
///
/// **Requirements**:
/// - Tailscale must be installed on the system (`/usr/bin/tailscale` or `/usr/local/bin/tailscale`)
/// - User must be logged into a Tailscale network
///
/// **Usage**:
/// ```swift
/// let service = TailscaleService(logger: logger)
/// let ip = try await service.getIP()
/// let status = try await service.getStatus()
/// ```
@available(macOS 15.0, iOS 17.0, *)
public actor TailscaleService {
  private let logger: Logger?
  private let tailscalePath: String

  /// Initialize Tailscale service
  /// - Parameters:
  ///   - tailscalePath: Path to tailscale binary (default: `/usr/bin/tailscale`)
  ///   - logger: Optional logger for debugging
  public init(tailscalePath: String = "/usr/bin/tailscale", logger: Logger? = nil) {
    self.tailscalePath = tailscalePath
    self.logger = logger
  }

  /// Get the Tailscale IPv4 address for this device
  /// - Returns: Tailscale IP address (e.g., "100.x.x.x")
  /// - Throws: `TailscaleError` if Tailscale is not running or command fails
  public func getIP() async throws -> String {
    logger?.debug("Getting Tailscale IP address")

    let output = try await executeCommand(arguments: ["ip", "-4"])
    let ip = output.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !ip.isEmpty, ip.starts(with: "100.") else {
      throw TailscaleError.invalidIP(ip)
    }

    logger?.info("Tailscale IP retrieved", metadata: ["ip": .string(ip)])
    return ip
  }

  /// Get the Tailscale hostname for this device
  /// - Returns: Tailscale hostname (e.g., "my-mac.tailnet-name.ts.net")
  /// - Throws: `TailscaleError` if command fails
  public func getHostname() async throws -> String {
    logger?.debug("Getting Tailscale hostname")

    let status = try await getStatus()
    return status.hostname
  }

  /// Get comprehensive Tailscale status
  /// - Returns: `TailscaleStatus` with connection details
  /// - Throws: `TailscaleError` if command fails
  public func getStatus() async throws -> TailscaleStatus {
    logger?.debug("Getting Tailscale status")

    let output = try await executeCommand(arguments: ["status", "--json"])

    guard let data = output.data(using: .utf8) else {
      throw TailscaleError.invalidOutput
    }

    let decoder = JSONDecoder()
    let statusResponse = try decoder.decode(TailscaleStatusResponse.self, from: data)

    // Find self in the peer list
    let selfNode = statusResponse.`self`
    let selfPeer = statusResponse.peer[selfNode.publicKey]

    let status = TailscaleStatus(
      hostname: selfNode.hostName,
      ip: selfPeer?.tailscaleIPs.first ?? "",
      online: selfPeer?.online ?? false,
      peerCount: statusResponse.peer.count - 1  // Exclude self
    )

    logger?.info(
      "Tailscale status retrieved",
      metadata: [
        "hostname": .string(status.hostname),
        "ip": .string(status.ip),
        "online": .string(String(status.online)),
      ])

    return status
  }

  /// Check if Tailscale is installed and available
  /// - Returns: `true` if Tailscale CLI is available
  public func isAvailable() async -> Bool {
    let fileManager = FileManager.default
    return fileManager.fileExists(atPath: tailscalePath)
      || fileManager.fileExists(atPath: "/usr/local/bin/tailscale")
  }

  /// Check if Tailscale is connected to a network
  /// - Returns: `true` if connected and running
  public func isConnected() async -> Bool {
    do {
      let status = try await getStatus()
      return status.online
    } catch {
      return false
    }
  }

  /// List all devices in the Tailscale network
  /// - Returns: Array of `TailscaleDevice`
  /// - Throws: `TailscaleError` if command fails
  public func listDevices() async throws -> [TailscaleDevice] {
    logger?.debug("Listing Tailscale devices")

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

    logger?.info("Tailscale devices listed", metadata: ["count": .string(String(devices.count))])
    return devices
  }

  // MARK: - Private Helpers

  private func executeCommand(arguments: [String]) async throws -> String {
    logger?.debug(
      "Executing tailscale command",
      metadata: [
        "command": .string(([tailscalePath] + arguments).joined(separator: " "))
      ])

    do {
      // Execute the command using Subprocess
      // 1MB limit for output (should be enough for tailscale status --json)
      let outputLimit = 1024 * 1024

      let result = try await Subprocess.run(
        .name(tailscalePath),
        arguments: .init(executablePathOverride: nil, remainingValues: arguments),
        output: .string(limit: outputLimit),
        error: .string(limit: outputLimit)
      )

      // Check exit status
      guard result.terminationStatus.isSuccess else {
        let errorOutput = result.standardError ?? "Unknown error"

        logger?.error(
          "Tailscale command failed",
          metadata: [
            "status": .string(String(describing: result.terminationStatus)),
            "error": .string(errorOutput),
          ])
        throw TailscaleError.commandFailed(errorOutput)
      }

      // Extract stdout
      guard let output = result.standardOutput else {
        throw TailscaleError.invalidOutput
      }

      return output
    } catch let error as TailscaleError {
      throw error
    } catch {
      throw TailscaleError.executionFailed(error.localizedDescription)
    }
  }
}

// MARK: - Supporting Types

/// Tailscale connection status
public struct TailscaleStatus: Sendable {
  public let hostname: String
  public let ip: String
  public let online: Bool
  public let peerCount: Int

  public init(hostname: String, ip: String, online: Bool, peerCount: Int) {
    self.hostname = hostname
    self.ip = ip
    self.online = online
    self.peerCount = peerCount
  }
}

/// Represents a device in the Tailscale network
public struct TailscaleDevice: Sendable, Identifiable {
  public let id: String
  public let hostname: String
  public let ip: String
  public let online: Bool
  public let os: String

  public init(id: String, hostname: String, ip: String, online: Bool, os: String) {
    self.id = id
    self.hostname = hostname
    self.ip = ip
    self.online = online
    self.os = os
  }
}

// MARK: - Internal JSON Decoding

struct TailscaleStatusResponse: Codable {
  let `self`: SelfNode
  let peer: [String: Peer]

  enum CodingKeys: String, CodingKey {
    case `self` = "Self"
    case peer = "Peer"
  }
}

struct SelfNode: Codable {
  let publicKey: String
  let hostName: String

  enum CodingKeys: String, CodingKey {
    case publicKey = "PublicKey"
    case hostName = "HostName"
  }
}

struct Peer: Codable {
  let hostName: String
  let online: Bool
  let tailscaleIPs: [String]
  let os: String

  enum CodingKeys: String, CodingKey {
    case hostName = "HostName"
    case online = "Online"
    case tailscaleIPs = "TailscaleIPs"
    case os = "OS"
  }
}
