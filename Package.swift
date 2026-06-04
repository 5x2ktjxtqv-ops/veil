// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Veil",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Veil", targets: ["Veil"])
    ],
    targets: [
        .executableTarget(name: "Veil"),
        .testTarget(
            name: "VeilTests",
            dependencies: ["Veil"]
        )
    ]
)
