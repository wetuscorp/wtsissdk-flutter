// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "wts_sdk",
    platforms: [.iOS(.v15)],
    products: [.library(name: "wts-sdk", targets: ["wts_sdk"])],
    dependencies: [
        .package(
            url: "https://github.com/wetuscorp/wtsissdk-swift.git",
            exact: "0.1.0-alpha.1"
        )
    ],
    targets: [
        .target(
            name: "wts_sdk",
            dependencies: [
                .product(name: "WtsSDK", package: "wtsissdk-swift")
            ]
        )
    ]
)
