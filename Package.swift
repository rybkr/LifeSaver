// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LifeSaverCore",
    products: [.library(name: "LifeSaverCore", targets: ["LifeSaverCore"])],
    targets: [
        .target(name: "LifeSaverCore", path: "LifeSaver/Core"),
        .testTarget(name: "LifeSaverCoreTests", dependencies: ["LifeSaverCore"])
    ]
)
