// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Pressly",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Pressly",
            path: "Sources/Pressly",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("EventKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("ApplicationServices"),
            ]
        )
    ]
)
