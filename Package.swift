// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SpatialMediaKit",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "spatial-media-kit-tool", targets: ["SpatialMediaKitTool"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
  ],
  targets: [
    .executableTarget(
      name: "SpatialMediaKitTool",
      dependencies: [
        "SpatialMediaKit",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]),
    .target(
      name: "SpatialMediaKit",
      dependencies: ["SpatialMediaKitObjC"]),
    .target(
      name: "SpatialMediaKitObjC",
      publicHeadersPath: "headers"),
    .testTarget(
      name: "SpatialMediaKitTests",
      dependencies: ["SpatialMediaKit"],
      resources: [
        .copy("TestData/spatial_video.mov")
      ]
    ),
  ]
)
