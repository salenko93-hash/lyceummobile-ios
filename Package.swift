// swift-tools-version: 5.9
import PackageDescription

// Linux-testable core. These same source files compile into the iOS app.
let package = Package(
    name: "LyceumMobileCore",
    products: [.library(name: "LyceumMobileCore", targets: ["LyceumMobileCore"])],
    targets: [
        .target(name: "LyceumMobileCore", path: "LyceumMobile/Core"),
        .testTarget(name: "ScheduleCoreTests", dependencies: ["LyceumMobileCore"],
                    path: "Tests/ScheduleCoreTests")
    ]
)
