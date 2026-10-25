// swift-tools-version:6.0
import Foundation
import PackageDescription

let infoPlist = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Sources/calsyn-cli/Info.plist")
    .path

let package = Package(
    name: "calsyn",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "calsyn", targets: ["calsyn-cli"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0"),
    ],
    targets: [
        .target(
            name: "CalsynCore",
            dependencies: [.product(name: "Yams", package: "Yams")]
        ),
        .executableTarget(
            name: "calsyn-cli",
            dependencies: ["CalsynCore"],
            exclude: ["Info.plist"],
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", infoPlist]),
            ]
        ),
        .testTarget(
            name: "CalsynCoreTests",
            dependencies: ["CalsynCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
