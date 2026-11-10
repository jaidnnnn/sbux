// swift-tools-version:5.9
// Only used to unit-test the shared logic with `swift test`.
// The apps themselves are built from project.yml (see README).
import PackageDescription

let package = Package(
    name: "LiftLogCore",
    targets: [
        .target(name: "LiftLogCore", path: "Shared"),
        .testTarget(name: "LiftLogCoreTests", dependencies: ["LiftLogCore"], path: "Tests/LiftLogCoreTests"),
    ]
)
