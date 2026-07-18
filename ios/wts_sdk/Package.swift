// swift-tools-version: 5.9
import PackageDescription
import Foundation

let nativeSdkPath = ProcessInfo.processInfo.environment["WTS_SDK_SWIFT_PATH"]
let nativeSdkDependency: Package.Dependency = if let nativeSdkPath {
    .package(name: "wtsissdk-swift", path: nativeSdkPath)
} else {
    .package(
        url: "https://github.com/wetuscorp/wtsissdk-swift.git",
        exact: "0.4.0-alpha.1"
    )
}

let package = Package(
    name: "wts_sdk",
    platforms: [.iOS(.v15)],
    products: [.library(name: "wts-sdk", targets: ["wts_sdk"])],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        nativeSdkDependency,
    ],
    targets: [
        .target(
            name: "wts_sdk",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "WtsSDK", package: "wtsissdk-swift")
            ]
        )
    ]
)
