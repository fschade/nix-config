// swift-tools-version:5.9
// Dev-only: lets you open tools/web-app/ in Xcode (or `swift build`) to edit the
// wrapper with autocomplete/debugging. The real /Applications/*.app bundles are
// still built by tools/web-app/web-app.swift (swiftc) during `mise run deploy`;
// this package doesn't touch that. web-app.swift (the builder) is excluded — it's
// a standalone script, not part of the host binary.
import PackageDescription

let package = Package(
    name: "WebAppHost",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "WebAppHost",
            path: ".",
            // every .swift here is a host source except the builder script; the
            // README/dmg backdrop etc. aren't target inputs
            exclude: ["web-app.swift", "README.md"]
        ),
    ]
)
