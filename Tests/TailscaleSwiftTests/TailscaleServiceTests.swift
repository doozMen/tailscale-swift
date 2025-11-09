import Foundation
import Testing

@testable import TailscaleSwift

/// Comprehensive tests for TailscaleService
/// Tests cover: successful operations, error handling, edge cases, and actor isolation
@Suite("TailscaleService Tests")
struct TailscaleServiceTests {

  // MARK: - Test Data

  static let validIP = "100.64.1.2"
  static let validHostname = "test-mac.tailnet.ts.net"
  static let selfPublicKey = "key:self123"
  static let peerPublicKey1 = "key:peer456"
  static let peerPublicKey2 = "key:peer789"

  /// Sample valid Tailscale status JSON response
  static func validStatusJSON(
    hostname: String = validHostname,
    ip: String = validIP,
    online: Bool = true,
    includePeers: Bool = true
  ) -> String {
    var peers = """
      "\(selfPublicKey)": {
        "HostName": "\(hostname)",
        "Online": \(online),
        "TailscaleIPs": ["\(ip)"],
        "OS": "macOS"
      }
      """

    if includePeers {
      peers += """
        ,
        "\(peerPublicKey1)": {
          "HostName": "peer1.tailnet.ts.net",
          "Online": true,
          "TailscaleIPs": ["100.64.1.3"],
          "OS": "linux"
        },
        "\(peerPublicKey2)": {
          "HostName": "peer2.tailnet.ts.net",
          "Online": false,
          "TailscaleIPs": ["100.64.1.4"],
          "OS": "windows"
        }
        """
    }

    return """
      {
        "Self": {
          "PublicKey": "\(selfPublicKey)",
          "HostName": "\(hostname)"
        },
        "Peer": {
          \(peers)
        }
      }
      """
  }

  // MARK: - getIP() Tests

  @Test("getIP returns valid IP address")
  func testGetIPSuccess() async throws {
    let service = MockTailscaleService()
    await service.setMockResponse(
      for: "ip -4",
      response: .success("100.64.1.2\n")
    )

    let ip = try await service.getIP()
    #expect(ip == "100.64.1.2")
  }

  @Test("getIP handles IP without trailing newline")
  func testGetIPNoNewline() async throws {
    let service = MockTailscaleService()
    await service.setMockResponse(
      for: "ip -4",
      response: .success("100.64.1.2")
    )

    let ip = try await service.getIP()
    #expect(ip == "100.64.1.2")
  }

  @Test("getIP handles IP with extra whitespace")
  func testGetIPWithWhitespace() async throws {
    let service = MockTailscaleService()
    await service.setMockResponse(
      for: "ip -4",
      response: .success("  100.64.1.2  \n")
    )

    let ip = try await service.getIP()
    #expect(ip == "100.64.1.2")
  }

  @Test("getIP throws on invalid IP (not starting with 100.)")
  func testGetIPInvalidPrefix() async throws {
    let service = MockTailscaleService()
    await service.setMockResponse(
      for: "ip -4",
      response: .success("192.168.1.1")
    )

    await #expect(throws: TailscaleError.self) {
      try await service.getIP()
    }
  }

  @Test("getIP throws on empty output")
  func testGetIPEmptyOutput() async throws {
    let service = MockTailscaleService()
    await service.setMockResponse(
      for: "ip -4",
      response: .success("")
    )

    await #expect(throws: TailscaleError.self) {
      try await service.getIP()
    }
  }

  @Test("getIP throws on command failure")
  func testGetIPCommandFailure() async throws {
    let service = MockTailscaleService()
    await service.setMockResponse(
      for: "ip -4",
      response: .failure(TailscaleError.commandFailed("Tailscale not running"))
    )

    await #expect(throws: TailscaleError.self) {
      try await service.getIP()
    }
  }

  // MARK: - getHostname() Tests

  @Test("getHostname returns valid hostname")
  func testGetHostnameSuccess() async throws {
    let service = MockTailscaleService()
    let statusJSON = Self.validStatusJSON()
    await service.setMockResponse(
      for: "status --json",
      response: .success(statusJSON)
    )

    let hostname = try await service.getHostname()
    #expect(hostname == Self.validHostname)
  }

  @Test("getHostname propagates status errors")
  func testGetHostnameFailure() async throws {
    let service = MockTailscaleService()
    await service.setMockResponse(
      for: "status --json",
      response: .failure(TailscaleError.commandFailed("Status unavailable"))
    )

    await #expect(throws: TailscaleError.self) {
      try await service.getHostname()
    }
  }

  // MARK: - getStatus() Tests

  @Test("getStatus returns valid status with peers")
  func testGetStatusSuccessWithPeers() async throws {
    let service = MockTailscaleService()
    let statusJSON = Self.validStatusJSON()
    await service.setMockResponse(
      for: "status --json",
      response: .success(statusJSON)
    )

    let status = try await service.getStatus()
    #expect(status.hostname == Self.validHostname)
    #expect(status.ip == Self.validIP)
    #expect(status.online == true)
    #expect(status.peerCount == 2)  // 2 peers (excluding self)
  }

  @Test("getStatus returns valid status without peers")
  func testGetStatusSuccessWithoutPeers() async throws {
    let service = MockTailscaleService()
    let statusJSON = Self.validStatusJSON(includePeers: false)
    await service.setMockResponse(
      for: "status --json",
      response: .success(statusJSON)
    )

    let status = try await service.getStatus()
    #expect(status.hostname == Self.validHostname)
    #expect(status.ip == Self.validIP)
    #expect(status.online == true)
    #expect(status.peerCount == 0)  // No peers
  }

  @Test("getStatus handles offline status")
  func testGetStatusOffline() async throws {
    let service = MockTailscaleService()
    let statusJSON = Self.validStatusJSON(online: false)
    await service.setMockResponse(
      for: "status --json",
      response: .success(statusJSON)
    )

    let status = try await service.getStatus()
    #expect(status.online == false)
  }

  @Test("getStatus throws on invalid JSON")
  func testGetStatusInvalidJSON() async throws {
    let service = MockTailscaleService()
    await service.setMockResponse(
      for: "status --json",
      response: .success("not valid json")
    )

    await #expect(throws: Error.self) {
      try await service.getStatus()
    }
  }

  @Test("getStatus throws on command failure")
  func testGetStatusCommandFailure() async throws {
    let service = MockTailscaleService()
    await service.setMockResponse(
      for: "status --json",
      response: .failure(TailscaleError.commandFailed("Status unavailable"))
    )

    await #expect(throws: TailscaleError.self) {
      try await service.getStatus()
    }
  }

  @Test("getStatus handles missing self peer in peer list")
  func testGetStatusMissingSelfPeer() async throws {
    let service = MockTailscaleService()
    // JSON with self node but missing from peer list
    let statusJSON = """
      {
        "Self": {
          "PublicKey": "key:missing",
          "HostName": "test.tailnet.ts.net"
        },
        "Peer": {}
      }
      """
    await service.setMockResponse(
      for: "status --json",
      response: .success(statusJSON)
    )

    let status = try await service.getStatus()
    #expect(status.hostname == "test.tailnet.ts.net")
    #expect(status.ip == "")  // No IP when self peer is missing
    #expect(status.online == false)  // Offline when self peer is missing
  }

  // MARK: - listDevices() Tests

  @Test("listDevices returns all peers excluding self")
  func testListDevicesSuccess() async throws {
    let service = MockTailscaleService()
    let statusJSON = Self.validStatusJSON()
    await service.setMockResponse(
      for: "status --json",
      response: .success(statusJSON)
    )

    let devices = try await service.listDevices()
    #expect(devices.count == 2)

    // Verify peer 1
    let peer1 = devices.first { $0.id == Self.peerPublicKey1 }
    #expect(peer1 != nil)
    #expect(peer1?.hostname == "peer1.tailnet.ts.net")
    #expect(peer1?.ip == "100.64.1.3")
    #expect(peer1?.online == true)
    #expect(peer1?.os == "linux")

    // Verify peer 2
    let peer2 = devices.first { $0.id == Self.peerPublicKey2 }
    #expect(peer2 != nil)
    #expect(peer2?.hostname == "peer2.tailnet.ts.net")
    #expect(peer2?.ip == "100.64.1.4")
    #expect(peer2?.online == false)
    #expect(peer2?.os == "windows")
  }

  @Test("listDevices returns empty array when no peers")
  func testListDevicesNoPeers() async throws {
    let service = MockTailscaleService()
    let statusJSON = Self.validStatusJSON(includePeers: false)
    await service.setMockResponse(
      for: "status --json",
      response: .success(statusJSON)
    )

    let devices = try await service.listDevices()
    #expect(devices.isEmpty)
  }

  @Test("listDevices excludes self from device list")
  func testListDevicesExcludesSelf() async throws {
    let service = MockTailscaleService()
    let statusJSON = Self.validStatusJSON()
    await service.setMockResponse(
      for: "status --json",
      response: .success(statusJSON)
    )

    let devices = try await service.listDevices()
    let selfDevice = devices.first { $0.id == Self.selfPublicKey }
    #expect(selfDevice == nil)
  }

  @Test("listDevices throws on invalid JSON")
  func testListDevicesInvalidJSON() async throws {
    let service = MockTailscaleService()
    await service.setMockResponse(
      for: "status --json",
      response: .success("invalid json")
    )

    await #expect(throws: Error.self) {
      try await service.listDevices()
    }
  }

  @Test("listDevices throws on command failure")
  func testListDevicesCommandFailure() async throws {
    let service = MockTailscaleService()
    await service.setMockResponse(
      for: "status --json",
      response: .failure(TailscaleError.commandFailed("Command failed"))
    )

    await #expect(throws: TailscaleError.self) {
      try await service.listDevices()
    }
  }

  // MARK: - Edge Case Tests

  @Test("handles large JSON output (near 1MB limit)")
  func testLargeJSONOutput() async throws {
    let service = MockTailscaleService()

    // Create a large JSON with many peers (simulating a large network)
    var peerEntries: [String] = []
    peerEntries.append(
      """
      "\(Self.selfPublicKey)": {
        "HostName": "\(Self.validHostname)",
        "Online": true,
        "TailscaleIPs": ["\(Self.validIP)"],
        "OS": "macOS"
      }
      """)

    // Add 1000 peers to create large output
    for i in 1...1000 {
      peerEntries.append(
        """
        "key:peer\(i)": {
          "HostName": "peer\(i).tailnet.ts.net",
          "Online": \(i % 2 == 0),
          "TailscaleIPs": ["100.64.\(i / 256).\(i % 256)"],
          "OS": "linux"
        }
        """)
    }

    let largeJSON = """
      {
        "Self": {
          "PublicKey": "\(Self.selfPublicKey)",
          "HostName": "\(Self.validHostname)"
        },
        "Peer": {
          \(peerEntries.joined(separator: ",\n"))
        }
      }
      """

    await service.setMockResponse(
      for: "status --json",
      response: .success(largeJSON)
    )

    let devices = try await service.listDevices()
    #expect(devices.count == 1000)
  }

  @Test("handles peers with empty IP arrays")
  func testPeersWithEmptyIPArrays() async throws {
    let service = MockTailscaleService()
    let statusJSON = """
      {
        "Self": {
          "PublicKey": "\(Self.selfPublicKey)",
          "HostName": "\(Self.validHostname)"
        },
        "Peer": {
          "\(Self.selfPublicKey)": {
            "HostName": "\(Self.validHostname)",
            "Online": true,
            "TailscaleIPs": ["\(Self.validIP)"],
            "OS": "macOS"
          },
          "key:peer1": {
            "HostName": "peer1.tailnet.ts.net",
            "Online": true,
            "TailscaleIPs": [],
            "OS": "linux"
          }
        }
      }
      """

    await service.setMockResponse(
      for: "status --json",
      response: .success(statusJSON)
    )

    let devices = try await service.listDevices()
    #expect(devices.count == 1)
    #expect(devices[0].ip == "")  // Empty IP when array is empty
  }

  @Test("handles special characters in hostnames")
  func testSpecialCharactersInHostname() async throws {
    let service = MockTailscaleService()
    let hostnameWithSpecialChars = "test-mac_01.my-tailnet.ts.net"
    let statusJSON = Self.validStatusJSON(hostname: hostnameWithSpecialChars)
    await service.setMockResponse(
      for: "status --json",
      response: .success(statusJSON)
    )

    let status = try await service.getStatus()
    #expect(status.hostname == hostnameWithSpecialChars)
  }
}
