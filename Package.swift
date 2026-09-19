// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WhatFileIsThis",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "WhatFileIsThis", targets: ["WhatFileIsThis"])
    ],
    targets: [
        .executableTarget(
            name: "WhatFileIsThis",
            path: "Sources/WhatFileIsThis"
        )
    ],
    swiftLanguageVersions: [.v5]
)
