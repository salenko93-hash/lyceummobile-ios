// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LyceumMobileCore",
    platforms: [.macOS(.v12), .iOS(.v16)],
    products: [.library(name: "LyceumMobileCore", targets: ["LyceumMobileCore"])],
    targets: [
        .target(name: "LyceumMobileCore", path: "LyceumMobile/Core"),
        .testTarget(name: "ScheduleCoreTests", dependencies: ["LyceumMobileCore"],
                    path: "Tests/ScheduleCoreTests")
    ]
)
