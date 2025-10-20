// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "TailscaleSwift",
  platforms: [.macOS(.v15), .iOS(.v17)],
  products: [
    .library(
      name: "TailscaleSwift",
      targets: ["TailscaleSwift"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "0.1.0"),
  ],
  targets: [
    .target(
      name: "TailscaleSwift",
      dependencies: [
        .product(name: "Logging", package: "swift-log"),
        .product(name: "Subprocess", package: "swift-subprocess"),
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .testTarget(
      name: "TailscaleSwiftTests",
      dependencies: ["TailscaleSwift"]
    ),
  ]
)
