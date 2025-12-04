// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "InvoiceGenerator",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "InvoiceGenerator",
            targets: ["InvoiceGenerator"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "InvoiceGenerator",
            dependencies: []),
        .testTarget(
            name: "InvoiceGeneratorTests",
            dependencies: ["InvoiceGenerator"]),
    ]
)
