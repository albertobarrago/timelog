// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TimelogCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TimelogCore", targets: ["TimelogCore"]),
        .library(name: "TimelogSync", targets: ["TimelogSync"])
    ],
    dependencies: [
        .package(url: "https://github.com/orlandos-nl/MongoKitten.git", from: "7.9.0")
    ],
    targets: [
        .target(
            name: "TimelogCore",
            dependencies: [],
            path: "Sources/TimelogCore",
            swiftSettings: [.swiftLanguageVersion(.v5)]
        ),
        .target(
            name: "TimelogSync",
            dependencies: [
                "TimelogCore",
                .product(name: "MongoKitten", package: "MongoKitten", condition: .when(platforms: [.macOS]))
            ],
            path: "Sources/TimelogSync",
            swiftSettings: [.swiftLanguageVersion(.v5)]
        )
    ]
)
