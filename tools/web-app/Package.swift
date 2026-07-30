// swift-tools-version:5.9
// dev-only: lets you open tools/web-app/ in xcode (or `swift build`) to edit the
// wrapper with autocomplete/debugging. the real /Applications/*.app bundles are
// still built by web-app.swift (swiftc) on `mise run deploy`, this package dont
// touch that.
import PackageDescription

let package = Package(
    name: "WebAppHost",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "WebAppHost",
            path: ".",
            // every .swift here is a host source, except the builder script. that
            // one is standalone and not part of the host binary. (Package.swift
            // itself is excluded by swiftpm, README.md only because swiftpm warns
            // about stray files.) a new .swift that is NOT host code has to be
            // named twice: here, and in web-app.swift's `notHost` for the real build.
            exclude: ["web-app.swift", "README.md"]
        ),
    ]
)
