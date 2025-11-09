# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TailscaleSwift is a Swift Package Manager library providing a modern Swift interface to Tailscale VPN mesh networking. It wraps the Tailscale CLI (`/usr/bin/tailscale`) using Swift's Subprocess library to provide type-safe, async/await-based access to Tailscale functionality.

**Key Architecture Principles:**
- **Actor-based concurrency**: `TailscaleService` is an actor for thread-safe CLI execution
- **Swift 6.0 strict concurrency**: Enabled via `.enableUpcomingFeature("StrictConcurrency")`
- **Subprocess wrapper pattern**: All Tailscale CLI commands executed via `Subprocess.run()`
- **JSON parsing**: Parses `tailscale status --json` output into Swift types (`TailscaleStatusResponse`, `SelfNode`, `Peer`)
- **Zero external dependencies**: Only Apple's swift-log and swift-subprocess

## Build & Test Commands

**Build the package:**
```bash
swift build
```

**Run tests:**
```bash
swift test
```

**Format code (Swift 6 built-in formatter):**
```bash
swift format lint -s -p -r Sources Tests Package.swift
swift format format -p -r -i Sources Tests Package.swift
```

**Build for Linux (if testing cross-platform):**
```bash
~/.swiftly/bin/swiftly run build --swift-sdk x86_64-swift-linux-musl
```

## Architecture Details

### Core Components

1. **TailscaleService.swift** (actor):
   - Main API surface with async methods: `getIP()`, `getStatus()`, `listDevices()`
   - Private `executeCommand(arguments:)` method wraps all Subprocess calls
   - 1MB output limit for subprocess results
   - Comprehensive logging via swift-log

2. **TailscaleError.swift** (enum):
   - Sendable error types with `LocalizedError` conformance
   - Provides `errorDescription` and `recoverySuggestion` for user-facing messages

3. **Data Models**:
   - `TailscaleStatus`: Public-facing status struct
   - `TailscaleDevice`: Represents network peers
   - `TailscaleStatusResponse`, `SelfNode`, `Peer`: Internal JSON decoding types

### Subprocess Execution Pattern

All CLI interaction follows this pattern:
```swift
let result = try await Subprocess.run(
  .name(tailscalePath),
  arguments: .init(executablePathOverride: nil, remainingValues: arguments),
  output: .string(limit: 1024 * 1024),
  error: .string(limit: 1024 * 1024)
)
```

### Platform Requirements

- **Platforms**: macOS 15.0+, iOS 17.0+
- **Swift**: 6.0 (strict concurrency enabled)
- **Runtime dependency**: Tailscale must be installed at `/usr/bin/tailscale` or `/usr/local/bin/tailscale`

## Development Roadmap

**Phase 1 (Current)**: CLI wrapper with Subprocess
**Phase 2 (Future)**: Embedded `libtailscale.a` static library with NetworkExtension integration (see Issue #1)

When working on Phase 2, refer to the tailscale-integration-specialist agent for libtailscale embedding patterns.

## Common Patterns

**Adding new Tailscale commands:**
1. Add public async method to `TailscaleService`
2. Call `executeCommand(arguments: [...])` with appropriate CLI args
3. Parse output (JSON or plain text)
4. Return typed Swift model (must be `Sendable`)
5. Add appropriate `TailscaleError` cases if needed

**Testing requirements:**
- Use Swift Testing framework (not XCTest)
- Tests must handle actor isolation properly
- Mock Tailscale CLI responses where possible (subprocess execution makes real CLI calls)
