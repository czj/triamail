// swift-tools-version: 6.0
import PackageDescription

// Logique de Triamail sans interface : testable avec `swift test`, sans lancer l'app.
let package = Package(
    name: "TriamailKit",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "TriamailKit", targets: ["TriamailKit"]),
    ],
    targets: [
        .target(name: "TriamailKit"),
        .testTarget(name: "TriamailKitTests", dependencies: ["TriamailKit"]),
    ]
)
