// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RatingHelper",
    defaultLocalization: "ru",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "RatingHelper",
            targets: ["RatingHelper"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "RatingHelper",
            dependencies: [],
            path: "Sources/RatingHelper"
        )
    ]
)
