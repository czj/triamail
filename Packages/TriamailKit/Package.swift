// swift-tools-version: 6.0
import PackageDescription

// Logique de Triamail sans interface : testable avec `swift test`, sans lancer l'app.
// Deliberately without the app's approachable concurrency: a nonisolated `async` function here
// runs off its caller's actor, so network, decoding and keychain work never lands on the main actor.
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
