// swift-tools-version:5.3
import PackageDescription
let package = Package(
    name: "mParticle-Localytics",
    platforms: [ .iOS(.v9) ],
    products: [
        .library(
            name: "mParticle-Localytics",
            targets: ["mParticle_Localytics"]),
    ],
    dependencies: [
      .package(name: "mParticle-Apple-SDK",
               url: "https://github.com/mParticle/mparticle-apple-sdk",
               .upToNextMajor(from: "8.22.0")),
      .package(name: "Localytics",
               url: "https://github.com/localytics/Localytics-swiftpm",
               .upToNextMajor(from: "6.3.0")),
    ],
    targets: [
        .target(
            name: "mParticle_Localytics",
            dependencies: ["mParticle-Apple-SDK", "Localytics"],
            path: "mParticle-Localytics",
            exclude: ["Info.plist"],
            resources: [.process("PrivacyInfo.xcprivacy")],
            publicHeadersPath: "."
        ),
    ]
)
