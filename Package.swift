// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WhatFileIsThis",
    defaultLocalization: "en",
    platforms: [
        .macOS("27.0")
    ],
    products: [
        .executable(name: "WhatFileIsThis", targets: ["WhatFileIsThis"])
    ],
    targets: [
        .executableTarget(
            name: "WhatFileIsThis",
            path: "Sources/WhatFileIsThis",
            resources: [.process("Resources")]
        )
    ],
    swiftLanguageVersions: [.v5]
)
