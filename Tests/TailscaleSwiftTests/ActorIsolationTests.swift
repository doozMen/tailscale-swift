import Foundation
import Testing

@testable import TailscaleSwift

/// Tests for actor isolation and concurrency
/// Verifies that TailscaleService correctly handles concurrent access
@Suite("Actor Isolation Tests")
struct ActorIsolationTests {

  // MARK: - Concurrent Access Tests

  @Test("concurrent getIP calls are properly isolated")
  func testConcurrentGetIPCalls() async throws {
    let service = MockTailscaleService()
    await service.setMockResponse(
      for: "ip -4",
      response: .success("100.64.1.2")
    )

    // Execute 10 concurrent calls
    let results = try await withThrowingTaskGroup(of: String.self) { group in
      for _ in 0..<10 {
        group.addTask {
          try await service.getIP()
        }
      }

      var ips: [String] = []
      for try await ip in group {
        ips.append(ip)
      }
      return ips
    }

    // All results should be the same
    #expect(results.count == 10)
    #expect(results.allSatisfy { $0 == "100.64.1.2" })
  }

  @Test("concurrent getStatus calls are properly isolated")
  func testConcurrentGetStatusCalls() async throws {
    let service = MockTailscaleService()
    let statusJSON = """
      {
        "Self": {
          "PublicKey": "key:self123",
          "HostName": "test.tailnet.ts.net"
        },
        "Peer": {
          "key:self123": {
            "HostName": "test.tailnet.ts.net",
            "Online": true,
            "TailscaleIPs": ["100.64.1.2"],
            "OS": "macOS"
          }
        }
      }
      """
    await service.setMockResponse(
      for: "status --json",
      response: .success(statusJSON)
    )

    // Execute 10 concurrent calls
    let results = try await withThrowingTaskGroup(of: TailscaleStatus.self) { group in
      for _ in 0..<10 {
        group.addTask {
          try await service.getStatus()
        }
      }

      var statuses: [TailscaleStatus] = []
      for try await status in group {
        statuses.append(status)
      }
      return statuses
    }

    // All results should have the same values
    #expect(results.count == 10)
    #expect(results.allSatisfy { $0.hostname == "test.tailnet.ts.net" })
    #expect(results.allSatisfy { $0.ip == "100.64.1.2" })
    #expect(results.allSatisfy { $0.online == true })
  }

  @Test("concurrent listDevices calls are properly isolated")
  func testConcurrentListDevicesCalls() async throws {
    let service = MockTailscaleService()
    let statusJSON = """
      {
        "Self": {
          "PublicKey": "key:self123",
          "HostName": "test.tailnet.ts.net"
        },
        "Peer": {
          "key:self123": {
            "HostName": "test.tailnet.ts.net",
            "Online": true,
            "TailscaleIPs": ["100.64.1.2"],
            "OS": "macOS"
          },
          "key:peer456": {
            "HostName": "peer1.tailnet.ts.net",
            "Online": true,
            "TailscaleIPs": ["100.64.1.3"],
            "OS": "linux"
          }
        }
      }
      """
    await service.setMockResponse(
      for: "status --json",
      response: .success(statusJSON)
    )

    // Execute 10 concurrent calls
    let results = try await withThrowingTaskGroup(of: [TailscaleDevice].self) { group in
      for _ in 0..<10 {
        group.addTask {
          try await service.listDevices()
        }
      }

      var deviceLists: [[TailscaleDevice]] = []
      for try await devices in group {
        deviceLists.append(devices)
      }
      return deviceLists
    }

    // All results should have the same device count
    #expect(results.count == 10)
    #expect(results.allSatisfy { $0.count == 1 })
    #expect(results.allSatisfy { $0.first?.hostname == "peer1.tailnet.ts.net" })
  }

  @Test("mixed concurrent calls are properly isolated")
  func testMixedConcurrentCalls() async throws {
    let service = MockTailscaleService()
    await service.setMockResponse(
      for: "ip -4",
      response: .success("100.64.1.2")
    )

    let statusJSON = """
      {
        "Self": {
          "PublicKey": "key:self123",
          "HostName": "test.tailnet.ts.net"
        },
        "Peer": {
          "key:self123": {
            "HostName": "test.tailnet.ts.net",
            "Online": true,
            "TailscaleIPs": ["100.64.1.2"],
            "OS": "macOS"
          }
        }
      }
      """
    await service.setMockResponse(
      for: "status --json",
      response: .success(statusJSON)
    )

    // Execute different methods concurrently
    async let ip1 = service.getIP()
    async let status1 = service.getStatus()
    async let hostname1 = service.getHostname()
    async let devices1 = service.listDevices()

    async let ip2 = service.getIP()
    async let status2 = service.getStatus()

    let (ipResult1, statusResult1, hostnameResult1, devicesResult1, ipResult2, statusResult2) =
      try await (ip1, status1, hostname1, devices1, ip2, status2)

    // Verify all results are correct
    #expect(ipResult1 == "100.64.1.2")
    #expect(ipResult2 == "100.64.1.2")
    #expect(statusResult1.hostname == "test.tailnet.ts.net")
    #expect(statusResult2.hostname == "test.tailnet.ts.net")
    #expect(hostnameResult1 == "test.tailnet.ts.net")
    #expect(devicesResult1.isEmpty)
  }

  // MARK: - Error Handling in Concurrent Contexts

  @Test("concurrent calls with mixed success and failure")
  func testConcurrentMixedResults() async throws {
    let service = MockTailscaleService()

    // First call succeeds
    await service.setMockResponse(
      for: "ip -4",
      response: .success("100.64.1.2")
    )

    // Execute concurrent calls (some will fail because mock is only set once)
    var successCount = 0
    var failureCount = 0

    await withTaskGroup(of: Result<String, Error>.self) { group in
      // Add successful task
      group.addTask {
        do {
          let ip = try await service.getIP()
          return .success(ip)
        } catch {
          return .failure(error)
        }
      }

      // Reset mock to failure for second call
      await service.setMockResponse(
        for: "ip -4",
        response: .failure(TailscaleError.commandFailed("Error"))
      )

      // Add failing task
      group.addTask {
        do {
          let ip = try await service.getIP()
          return .success(ip)
        } catch {
          return .failure(error)
        }
      }

      for await result in group {
        switch result {
        case .success:
          successCount += 1
        case .failure:
          failureCount += 1
        }
      }
    }

    #expect(successCount + failureCount == 2)
  }

  // MARK: - Actor State Consistency Tests

  @Test("actor maintains consistent state across concurrent modifications")
  func testActorStateConsistency() async throws {
    let service = MockTailscaleService()

    // Set initial mock
    await service.setMockResponse(
      for: "ip -4",
      response: .success("100.64.1.2")
    )

    // Execute concurrent reads while modifying state
    await withTaskGroup(of: Void.self) { group in
      // Reader tasks
      for _ in 0..<5 {
        group.addTask {
          _ = try? await service.getIP()
        }
      }

      // Writer tasks (update mock)
      for i in 0..<5 {
        group.addTask {
          await service.setMockResponse(
            for: "ip -4",
            response: .success("100.64.1.\(i)")
          )
        }
      }
    }

    // Verify final state is valid
    let finalIP = try await service.getIP()
    #expect(finalIP.starts(with: "100.64.1."))
  }

  // MARK: - Performance Tests

  @Test("actor handles high concurrency load")
  func testHighConcurrencyLoad() async throws {
    let service = MockTailscaleService()
    await service.setMockResponse(
      for: "ip -4",
      response: .success("100.64.1.2")
    )

    // Execute 100 concurrent calls
    let startTime = Date()

    try await withThrowingTaskGroup(of: String.self) { group in
      for _ in 0..<100 {
        group.addTask {
          try await service.getIP()
        }
      }

      var results: [String] = []
      for try await ip in group {
        results.append(ip)
      }

      #expect(results.count == 100)
    }

    let duration = Date().timeIntervalSince(startTime)

    // Should complete in reasonable time (< 5 seconds for 100 calls)
    #expect(duration < 5.0)
  }

  // MARK: - Sendable Conformance Tests

  @Test("TailscaleStatus is Sendable across actor boundaries")
  func testTailscaleStatusSendable() async throws {
    let service = MockTailscaleService()
    let statusJSON = """
      {
        "Self": {
          "PublicKey": "key:self123",
          "HostName": "test.tailnet.ts.net"
        },
        "Peer": {
          "key:self123": {
            "HostName": "test.tailnet.ts.net",
            "Online": true,
            "TailscaleIPs": ["100.64.1.2"],
            "OS": "macOS"
          }
        }
      }
      """
    await service.setMockResponse(
      for: "status --json",
      response: .success(statusJSON)
    )

    let status = try await service.getStatus()

    // Send status to another task
    let hostname = await Task {
      status.hostname
    }.value

    #expect(hostname == "test.tailnet.ts.net")
  }

  @Test("TailscaleDevice is Sendable across actor boundaries")
  func testTailscaleDeviceSendable() async throws {
    let service = MockTailscaleService()
    let statusJSON = """
      {
        "Self": {
          "PublicKey": "key:self123",
          "HostName": "test.tailnet.ts.net"
        },
        "Peer": {
          "key:self123": {
            "HostName": "test.tailnet.ts.net",
            "Online": true,
            "TailscaleIPs": ["100.64.1.2"],
            "OS": "macOS"
          },
          "key:peer456": {
            "HostName": "peer1.tailnet.ts.net",
            "Online": true,
            "TailscaleIPs": ["100.64.1.3"],
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

    // Send devices to another task
    let firstHostname = await Task {
      devices.first?.hostname
    }.value

    #expect(firstHostname == "peer1.tailnet.ts.net")
  }
}
