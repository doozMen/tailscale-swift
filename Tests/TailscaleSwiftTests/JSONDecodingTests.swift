import Foundation
import Testing

@testable import TailscaleSwift

/// Tests for JSON decoding and response parsing
/// Verifies that all JSON structures are correctly decoded
@Suite("JSON Decoding Tests")
struct JSONDecodingTests {

  // MARK: - Valid JSON Decoding Tests

  @Test("decodes minimal valid status JSON")
  func testDecodeMinimalJSON() throws {
    let json = """
      {
        "Self": {
          "PublicKey": "key:abc123",
          "HostName": "test.ts.net"
        },
        "Peer": {
          "key:abc123": {
            "HostName": "test.ts.net",
            "Online": true,
            "TailscaleIPs": ["100.64.1.2"],
            "OS": "macOS"
          }
        }
      }
      """

    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    let response = try decoder.decode(TailscaleStatusResponse.self, from: data)

    #expect(response.`self`.publicKey == "key:abc123")
    #expect(response.`self`.hostName == "test.ts.net")
    #expect(response.peer.count == 1)
  }

  @Test("decodes status JSON with multiple peers")
  func testDecodeMultiplePeers() throws {
    let json = """
      {
        "Self": {
          "PublicKey": "key:self",
          "HostName": "my-device.ts.net"
        },
        "Peer": {
          "key:self": {
            "HostName": "my-device.ts.net",
            "Online": true,
            "TailscaleIPs": ["100.64.1.1"],
            "OS": "macOS"
          },
          "key:peer1": {
            "HostName": "peer1.ts.net",
            "Online": true,
            "TailscaleIPs": ["100.64.1.2"],
            "OS": "linux"
          },
          "key:peer2": {
            "HostName": "peer2.ts.net",
            "Online": false,
            "TailscaleIPs": ["100.64.1.3", "fd7a::1"],
            "OS": "windows"
          }
        }
      }
      """

    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    let response = try decoder.decode(TailscaleStatusResponse.self, from: data)

    #expect(response.peer.count == 3)
    #expect(response.peer["key:peer1"]?.hostName == "peer1.ts.net")
    #expect(response.peer["key:peer2"]?.online == false)
    #expect(response.peer["key:peer2"]?.tailscaleIPs.count == 2)
  }

  @Test("decodes peer with multiple IP addresses")
  func testDecodeMultipleIPs() throws {
    let json = """
      {
        "Self": {
          "PublicKey": "key:self",
          "HostName": "test.ts.net"
        },
        "Peer": {
          "key:self": {
            "HostName": "test.ts.net",
            "Online": true,
            "TailscaleIPs": ["100.64.1.1", "fd7a:115c:a1e0::1"],
            "OS": "macOS"
          }
        }
      }
      """

    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    let response = try decoder.decode(TailscaleStatusResponse.self, from: data)

    let selfPeer = response.peer["key:self"]
    #expect(selfPeer?.tailscaleIPs.count == 2)
    #expect(selfPeer?.tailscaleIPs[0] == "100.64.1.1")
    #expect(selfPeer?.tailscaleIPs[1] == "fd7a:115c:a1e0::1")
  }

  @Test("decodes peer with empty IP array")
  func testDecodeEmptyIPArray() throws {
    let json = """
      {
        "Self": {
          "PublicKey": "key:self",
          "HostName": "test.ts.net"
        },
        "Peer": {
          "key:self": {
            "HostName": "test.ts.net",
            "Online": false,
            "TailscaleIPs": [],
            "OS": "macOS"
          }
        }
      }
      """

    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    let response = try decoder.decode(TailscaleStatusResponse.self, from: data)

    let selfPeer = response.peer["key:self"]
    #expect(selfPeer?.tailscaleIPs.isEmpty == true)
  }

  @Test("decodes different OS values")
  func testDecodeDifferentOS() throws {
    let osValues = ["macOS", "linux", "windows", "iOS", "android", "freebsd"]

    for os in osValues {
      let json = """
        {
          "Self": {
            "PublicKey": "key:self",
            "HostName": "test.ts.net"
          },
          "Peer": {
            "key:self": {
              "HostName": "test.ts.net",
              "Online": true,
              "TailscaleIPs": ["100.64.1.1"],
              "OS": "\(os)"
            }
          }
        }
        """

      let data = json.data(using: .utf8)!
      let decoder = JSONDecoder()
      let response = try decoder.decode(TailscaleStatusResponse.self, from: data)

      #expect(response.peer["key:self"]?.os == os)
    }
  }

  // MARK: - Invalid JSON Tests

  @Test("throws error on malformed JSON")
  func testMalformedJSON() {
    let json = "{ not valid json }"

    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()

    #expect(throws: Error.self) {
      try decoder.decode(TailscaleStatusResponse.self, from: data)
    }
  }

  @Test("throws error on missing Self field")
  func testMissingSelfField() {
    let json = """
      {
        "Peer": {
          "key:peer1": {
            "HostName": "peer1.ts.net",
            "Online": true,
            "TailscaleIPs": ["100.64.1.1"],
            "OS": "linux"
          }
        }
      }
      """

    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()

    #expect(throws: Error.self) {
      try decoder.decode(TailscaleStatusResponse.self, from: data)
    }
  }

  @Test("throws error on missing Peer field")
  func testMissingPeerField() {
    let json = """
      {
        "Self": {
          "PublicKey": "key:self",
          "HostName": "test.ts.net"
        }
      }
      """

    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()

    #expect(throws: Error.self) {
      try decoder.decode(TailscaleStatusResponse.self, from: data)
    }
  }

  @Test("throws error on missing required peer fields")
  func testMissingPeerFields() {
    // Missing Online field
    let json = """
      {
        "Self": {
          "PublicKey": "key:self",
          "HostName": "test.ts.net"
        },
        "Peer": {
          "key:self": {
            "HostName": "test.ts.net",
            "TailscaleIPs": ["100.64.1.1"],
            "OS": "macOS"
          }
        }
      }
      """

    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()

    #expect(throws: Error.self) {
      try decoder.decode(TailscaleStatusResponse.self, from: data)
    }
  }

  @Test("throws error on wrong field types")
  func testWrongFieldTypes() {
    // Online is a string instead of bool
    let json = """
      {
        "Self": {
          "PublicKey": "key:self",
          "HostName": "test.ts.net"
        },
        "Peer": {
          "key:self": {
            "HostName": "test.ts.net",
            "Online": "true",
            "TailscaleIPs": ["100.64.1.1"],
            "OS": "macOS"
          }
        }
      }
      """

    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()

    #expect(throws: Error.self) {
      try decoder.decode(TailscaleStatusResponse.self, from: data)
    }
  }

  // MARK: - Edge Case JSON Tests

  @Test("decodes empty peer dictionary")
  func testEmptyPeerDictionary() throws {
    let json = """
      {
        "Self": {
          "PublicKey": "key:self",
          "HostName": "test.ts.net"
        },
        "Peer": {}
      }
      """

    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    let response = try decoder.decode(TailscaleStatusResponse.self, from: data)

    #expect(response.peer.isEmpty)
  }

  @Test("decodes hostnames with special characters")
  func testHostnamesWithSpecialCharacters() throws {
    let hostnames = [
      "my-device.ts.net",
      "device_01.ts.net",
      "192-168-1-1.ts.net",
      "user-macbook-pro-2023.ts.net",
    ]

    for hostname in hostnames {
      let json = """
        {
          "Self": {
            "PublicKey": "key:self",
            "HostName": "\(hostname)"
          },
          "Peer": {
            "key:self": {
              "HostName": "\(hostname)",
              "Online": true,
              "TailscaleIPs": ["100.64.1.1"],
              "OS": "macOS"
            }
          }
        }
        """

      let data = json.data(using: .utf8)!
      let decoder = JSONDecoder()
      let response = try decoder.decode(TailscaleStatusResponse.self, from: data)

      #expect(response.`self`.hostName == hostname)
    }
  }

  @Test("decodes public keys with various formats")
  func testPublicKeyFormats() throws {
    let publicKeys = [
      "key:abc123",
      "key:0123456789abcdef",
      "key:very-long-public-key-with-many-characters-and-numbers-12345",
    ]

    for publicKey in publicKeys {
      let json = """
        {
          "Self": {
            "PublicKey": "\(publicKey)",
            "HostName": "test.ts.net"
          },
          "Peer": {
            "\(publicKey)": {
              "HostName": "test.ts.net",
              "Online": true,
              "TailscaleIPs": ["100.64.1.1"],
              "OS": "macOS"
            }
          }
        }
        """

      let data = json.data(using: .utf8)!
      let decoder = JSONDecoder()
      let response = try decoder.decode(TailscaleStatusResponse.self, from: data)

      #expect(response.`self`.publicKey == publicKey)
    }
  }

  @Test("handles JSON with extra whitespace and formatting")
  func testJSONWithExtraWhitespace() throws {
    let json = """


      {
        "Self":    {
          "PublicKey":   "key:self"  ,
          "HostName":  "test.ts.net"
        }  ,
        "Peer": {
          "key:self": {
            "HostName":    "test.ts.net",
            "Online":  true  ,
            "TailscaleIPs": [  "100.64.1.1"  ],
            "OS": "macOS"
          }
        }
      }


      """

    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    let response = try decoder.decode(TailscaleStatusResponse.self, from: data)

    #expect(response.`self`.publicKey == "key:self")
    #expect(response.`self`.hostName == "test.ts.net")
  }

  @Test("decodes very long hostname")
  func testVeryLongHostname() throws {
    let longHostname = String(repeating: "very-long-hostname-segment-", count: 10) + "device.ts.net"
    let json = """
      {
        "Self": {
          "PublicKey": "key:self",
          "HostName": "\(longHostname)"
        },
        "Peer": {
          "key:self": {
            "HostName": "\(longHostname)",
            "Online": true,
            "TailscaleIPs": ["100.64.1.1"],
            "OS": "macOS"
          }
        }
      }
      """

    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    let response = try decoder.decode(TailscaleStatusResponse.self, from: data)

    #expect(response.`self`.hostName == longHostname)
  }

  @Test("decodes many IP addresses for single peer")
  func testManyIPAddresses() throws {
    let ips = (1...10).map { "100.64.1.\($0)" }
    let ipsJSON = ips.map { "\"\($0)\"" }.joined(separator: ", ")

    let json = """
      {
        "Self": {
          "PublicKey": "key:self",
          "HostName": "test.ts.net"
        },
        "Peer": {
          "key:self": {
            "HostName": "test.ts.net",
            "Online": true,
            "TailscaleIPs": [\(ipsJSON)],
            "OS": "macOS"
          }
        }
      }
      """

    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()
    let response = try decoder.decode(TailscaleStatusResponse.self, from: data)

    #expect(response.peer["key:self"]?.tailscaleIPs.count == 10)
  }

  // MARK: - Case Sensitivity Tests

  @Test("case-sensitive field names are required")
  func testCaseSensitiveFields() {
    // Lowercase "self" instead of "Self"
    let json = """
      {
        "self": {
          "PublicKey": "key:self",
          "HostName": "test.ts.net"
        },
        "Peer": {
          "key:self": {
            "HostName": "test.ts.net",
            "Online": true,
            "TailscaleIPs": ["100.64.1.1"],
            "OS": "macOS"
          }
        }
      }
      """

    let data = json.data(using: .utf8)!
    let decoder = JSONDecoder()

    #expect(throws: Error.self) {
      try decoder.decode(TailscaleStatusResponse.self, from: data)
    }
  }
}
