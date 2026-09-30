// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "UnixLifeCore",
    products: [.library(name: "UnixLifeCore", targets: ["UnixLifeCore"])],
    targets: [
        .target(name: "UnixLifeCore", path: "UnixLife/Core"),
        .testTarget(name: "UnixLifeCoreTests", dependencies: ["UnixLifeCore"])
    ]
)
