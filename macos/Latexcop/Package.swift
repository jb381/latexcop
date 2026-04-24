// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Latexcop",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Latexcop"
        )
    ]
)
