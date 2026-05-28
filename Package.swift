// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OYMarqueeView",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "OYMarqueeView",
            targets: ["OYMarqueeView"]
        )
    ],
    targets: [
        .target(
            name: "OYMarqueeView",
            path: "OYMarqueeView",
            sources: [
                "OYMarqueeView.swift",
                "DataStructure/LinkQueue.swift"
            ]
        ),
        .testTarget(
            name: "OYMarqueeViewTests",
            dependencies: ["OYMarqueeView"],
            path: "Tests/OYMarqueeViewTests"
        )
    ],
    swiftLanguageModes: [
        .v5,
        .v6
    ]
)
