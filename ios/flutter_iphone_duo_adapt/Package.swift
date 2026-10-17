// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "flutter_iphone_duo_adapt",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "flutter-iphone-duo-adapt", targets: ["flutter_iphone_duo_adapt"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "flutter_iphone_duo_adapt",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            cSettings: [
                .headerSearchPath("include/flutter_iphone_duo_adapt")
            ]
        )
    ]
)
