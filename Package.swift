// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "InclUI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "inclui",
            targets: ["inclui"]
        ),
        .executable(
            name: "inclui-gui",
            targets: ["inclui-gui"]
        ),
        .plugin(
            name: "InclUIPlugin",
            targets: ["InclUIPlugin"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            exact: "602.0.0"
        ),
        .package(
            url: "https://github.com/swiftlang/swift-testing.git",
            revision: "swift-6.2.4-RELEASE"
        )
    ],
    targets: [
        .target(
            name: "InclUICore"
        ),
        .target(
            name: "InclUIAnalyzer",
            dependencies: [
                "InclUICore",
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax")
            ]
        ),
        .target(
            name: "InclUIReporter",
            dependencies: [
                "InclUICore"
            ]
        ),
        .executableTarget(
            name: "inclui",
            dependencies: [
                "InclUIAnalyzer",
                "InclUICore",
                "InclUIReporter"
            ],
            path: "Sources/InclUICLI"
        ),
        .executableTarget(
            name: "inclui-gui",
            dependencies: [
                "InclUIAnalyzer",
                "InclUICore",
                "InclUIReporter"
            ],
            path: "Sources/InclUIGUI"
        ),
        .plugin(
            name: "InclUIPlugin",
            capability: .buildTool(),
            dependencies: [
                "inclui"
            ]
        ),
        .testTarget(
            name: "InclUITests",
            dependencies: [
                "InclUIAnalyzer",
                "InclUICore",
                "InclUIReporter",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)
