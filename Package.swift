// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProcessWatch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ProcessWatch", targets: ["ProcessWatch"])
    ],
    targets: [
        .target(
            name: "ProcessWatchC",
            path: "Sources/ProcessWatchC",
            publicHeadersPath: "include",
            cSettings: [
                .define("_DARWIN_C_SOURCE")
            ]
        ),
        .executableTarget(
            name: "ProcessWatch",
            dependencies: ["ProcessWatchC"],
            path: "Sources/ProcessWatch"
        )
    ],
    swiftLanguageVersions: [.v5]
)
