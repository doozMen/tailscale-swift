# TailscaleSwift

A Swift Package Manager library providing a modern Swift interface to Tailscale VPN mesh networking.

## Overview

TailscaleSwift wraps the Tailscale CLI to provide type-safe, async/await-based access to Tailscale functionality from Swift applications. Perfect for macOS and iOS apps that need secure peer-to-peer connectivity.

## Features

- ✅ **Modern Swift API**: Async/await with Swift 6.0 strict concurrency
- ✅ **Actor-based**: Thread-safe with Swift actors
- ✅ **Type-safe**: Strongly typed Tailscale models (IP, status, devices)
- ✅ **Cross-platform**: macOS 15+ and iOS 17+
- ✅ **Zero dependencies**: Only uses Swift Subprocess and Logging
- ✅ **Comprehensive**: IP lookup, status checks, device listing

## Requirements

- **Swift**: 6.0 or later
- **Platforms**: macOS 15.0+, iOS 17.0+
- **Tailscale**: Must be installed and configured on the system
  - macOS: Install from [tailscale.com/download](https://tailscale.com/download)
  - iOS: Tailscale app from App Store

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/doozMen/tailscale-swift.git", from: "1.0.0")
]
```

Then add to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "TailscaleSwift", package: "tailscale-swift")
    ]
)
```

## Usage

### Basic Example

```swift
import TailscaleSwift
import Logging

let logger = Logger(label: "com.example.app")
let tailscale = TailscaleService(logger: logger)

// Get Tailscale IP
let ip = try await tailscale.getIP()
print("Tailscale IP: \(ip)")

// Check status
let status = try await tailscale.getStatus()
print("Hostname: \(status.hostname)")
print("Online: \(status.online)")
print("Peers: \(status.peerCount)")

// List devices in network
let devices = try await tailscale.listDevices()
for device in devices {
    print("\(device.hostname): \(device.ip) (\(device.online ? "online" : "offline"))")
}
```

### Check Availability

```swift
let tailscale = TailscaleService()

if await tailscale.isAvailable() {
    print("Tailscale is installed")
} else {
    print("Tailscale not found. Install from https://tailscale.com/download")
}

if await tailscale.isConnected() {
    print("Connected to Tailscale network")
} else {
    print("Not connected. Run 'tailscale up' to connect.")
}
```

### Actor Isolation

`TailscaleService` is an actor, so all methods are async and automatically isolated:

```swift
actor MyService {
    let tailscale = TailscaleService()

    func getServerIP() async throws -> String {
        return try await tailscale.getIP()
    }
}
```

## API Reference

### TailscaleService

```swift
public actor TailscaleService {
    /// Get Tailscale IPv4 address (e.g., "100.x.x.x")
    func getIP() async throws -> String

    /// Get Tailscale hostname (e.g., "my-mac.tailnet.ts.net")
    func getHostname() async throws -> String

    /// Get comprehensive status
    func getStatus() async throws -> TailscaleStatus

    /// Check if Tailscale CLI is installed
    func isAvailable() async -> Bool

    /// Check if connected to Tailscale network
    func isConnected() async -> Bool

    /// List all devices in the network
    func listDevices() async throws -> [TailscaleDevice]
}
```

### TailscaleStatus

```swift
public struct TailscaleStatus: Sendable {
    public let hostname: String
    public let ip: String
    public let online: Bool
    public let peerCount: Int
}
```

### TailscaleDevice

```swift
public struct TailscaleDevice: Sendable, Identifiable {
    public let id: String
    public let hostname: String
    public let ip: String
    public let online: Bool
    public let os: String
}
```

### TailscaleError

```swift
public enum TailscaleError: LocalizedError, Sendable {
    case commandFailed(String)
    case executionFailed(String)
    case invalidIP(String)
    case invalidOutput
    case notInstalled
    case notConnected
}
```

## How It Works

TailscaleSwift wraps the Tailscale CLI (`/usr/bin/tailscale`) using Swift's Subprocess library:

1. Executes `tailscale` commands (e.g., `tailscale ip -4`, `tailscale status --json`)
2. Parses JSON output into Swift types
3. Provides async/await interface with proper error handling
4. Actor isolation ensures thread safety

## Roadmap

### Phase 1 (Current): CLI Wrapper
- ✅ Wrap Tailscale CLI with Subprocess
- ✅ Async/await API
- ✅ Actor-based thread safety
- ✅ Swift 6.0 strict concurrency

### Phase 2 (Future): Embedded libtailscale
- ⏳ Build `libtailscale.a` static library
- ⏳ Embed into SPM package (no external dependency)
- ⏳ NetworkExtension integration for iOS
- ⏳ Auto-join tailnet on app startup

See [Issue #1](../../issues/1) for Phase 2 progress.

## Contributing

Contributions welcome! Please open an issue or pull request.

## License

MIT License - see LICENSE file for details.

## Related Projects

- **PromptPing**: AI terminal continuity using Tailscale - [github.com/doozMen/promptping](https://github.com/doozMen/promptping)
- **Tailscale**: Official Tailscale project - [github.com/tailscale/tailscale](https://github.com/tailscale/tailscale)

## Credits

Created by Stijn Willems ([@doozMen](https://github.com/doozMen))

Built for [PromptPing](https://github.com/doozMen/promptping) - AI Terminal Continuity
