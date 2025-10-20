import Foundation

/// Errors that can occur when interacting with Tailscale
public enum TailscaleError: LocalizedError, Sendable {
  /// Tailscale command execution failed
  case commandFailed(String)

  /// Tailscale command execution failed with system error
  case executionFailed(String)

  /// Invalid IP address returned from Tailscale
  case invalidIP(String)

  /// Invalid output from Tailscale command
  case invalidOutput

  /// Tailscale is not installed on the system
  case notInstalled

  /// Tailscale is not connected to a network
  case notConnected

  public var errorDescription: String? {
    switch self {
    case .commandFailed(let message):
      return "Tailscale command failed: \(message)"
    case .executionFailed(let message):
      return "Failed to execute Tailscale command: \(message)"
    case .invalidIP(let ip):
      return "Invalid Tailscale IP address: \(ip)"
    case .invalidOutput:
      return "Invalid output from Tailscale command"
    case .notInstalled:
      return "Tailscale is not installed on this system"
    case .notConnected:
      return "Tailscale is not connected to a network"
    }
  }

  public var recoverySuggestion: String? {
    switch self {
    case .commandFailed, .executionFailed:
      return
        "Check that Tailscale is running and you are logged in. Run 'tailscale status' in Terminal."
    case .invalidIP:
      return "Ensure Tailscale is connected to a network. Run 'tailscale up' to connect."
    case .invalidOutput:
      return "This may be a bug. Please report it with the Tailscale version you're using."
    case .notInstalled:
      return "Install Tailscale from https://tailscale.com/download"
    case .notConnected:
      return "Run 'tailscale up' to connect to your Tailscale network"
    }
  }
}
