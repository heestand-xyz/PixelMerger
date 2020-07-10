// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "PixelMerger",
    platforms: [
        .iOS(.v11),
        .macOS(.v10_13),
//        .tvOS(.v11)
    ],
    products: [
        .library(name: "PixelMerger", targets: ["PixelMerger"]),
    ],
    dependencies: [
//        .package(url: "https://github.com/hexagons/LiveValues.git", .exact("1.2.1")),
//        .package(url: "https://github.com/hexagons/RenderKit.git", .exact("0.4.6")),
        .package(url: "https://github.com/hexagons/PixelKit.git", from: "1.1.5"), // .exact("1.0.10")
    ],
    targets: [
        .target(name: "PixelMerger", dependencies: ["RenderKit", "PixelKit"])
    ]
)
