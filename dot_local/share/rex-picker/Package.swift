// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RexPicker",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "RexPicker", targets: ["RexPicker"])],
    targets: [
        .target(name: "PickerCore"),
        .executableTarget(name: "RexPicker", dependencies: ["PickerCore"]),
        .testTarget(name: "PickerCoreTests", dependencies: ["PickerCore"])
    ]
)
