// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TimelogCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TimelogCore", targets: ["TimelogCore"])
    ],
    targets: [
        .target(
            name: "TimelogCore",
            path: "Sources/TimelogCore"
        )
    ]
)
