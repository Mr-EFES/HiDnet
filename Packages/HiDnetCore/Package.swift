// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HiDnetCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "HiDnetCore", targets: ["HiDnetCore"])],
    targets: [
        .target(name: "HiDnetCore"),
        .testTarget(name: "HiDnetCoreTests", dependencies: ["HiDnetCore"])
    ]
)
