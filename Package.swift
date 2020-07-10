// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "PixelMerger",
    platforms: [
        .iOS(.v11),
        .macOS(.v10_13),
    ],
    products: [
        .library(name: "PixelMerger", targets: ["PixelMerger"])
    ],
    dependencies: [
        .package(url: "https://github.com/hexagons/PixelKit.git", from: "1.1.5")
    ],
    targets: [
        .target(name: "PixelMerger", dependencies: ["PixelKit"])
    ]
)
