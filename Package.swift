// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "macos_security_cnssi",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CNSSIWorkflow", targets: ["CNSSIWorkflow"]),
        .executable(name: "cnssi-baseline-generator", targets: ["cnssi-baseline-generator"]),
        .executable(name: "cnssi-merge", targets: ["cnssi-merge"])
    ],
    dependencies: [.package(path: "../ComplianceKit")],
    targets: [
        .target(name: "CNSSIWorkflow", dependencies: [
            .product(name: "ComplianceKitCore", package: "compliancekit"),
            .product(name: "ComplianceKitPersistence", package: "compliancekit")
        ]),
        .executableTarget(name: "cnssi-baseline-generator", dependencies: ["CNSSIWorkflow"],
                          swiftSettings: [.defaultIsolation(MainActor.self)]),
        .executableTarget(name: "cnssi-merge", dependencies: ["CNSSIWorkflow"],
                          swiftSettings: [.defaultIsolation(MainActor.self)])
    ]
)
