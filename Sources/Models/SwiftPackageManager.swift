// Copyright © 2021 Lautsprecher Teufel GmbH. All rights reserved.

import Foundation
import FoundationExtensions
import Helper

// MARK: V2

public struct ResolvedPackageContentV2: Decodable {
    let pins: [ResolvedPackageV2]
    let version: Int

    public init(pins: [ResolvedPackageV2], version: Int) {
        self.pins = pins
        self.version = version
    }
}

public struct ResolvedPackageV2: Decodable {
    let identity: String
    let location: URL
    let state: ResolvedPackageState

    public init(identity: String, location: URL, state: ResolvedPackageState) {
        self.identity = identity
        self.location = location
        self.state = state
    }
}

public extension ResolvedPackageContentV2 {
    func ignoring(packages ignore: [String]) -> ResolvedPackageContentV2 {
        if ignore.count == 0 { return self }
        return ResolvedPackageContentV2(
                pins: pins.filter { pin in
                    !ignore.contains(pin.identity)
                },
            version: version
        )
    }
}

// MARK: V1

// public struct ResolvedPackageContent: Decodable {
//     let object: ResolvedPackageObject
//     let version: Int
    
//     public init(object: ResolvedPackageObject, version: Int) {
//         self.object = object
//         self.version = version
//     }
// }

// public extension ResolvedPackageContent {
//     func ignoring(packages ignore: [String]) -> ResolvedPackageContent {
//         if ignore.count == 0 { return self }
//         return ResolvedPackageContent(
//             object: ResolvedPackageObject(
//                 pins: object.pins.filter { pin in
//                     !ignore.contains(pin.package)
//                 }
//             ),
//             version: version
//         )
//     }
// }

// public struct ResolvedPackageObject: Decodable {
//     let pins: [ResolvedPackage]

//     public init(pins: [ResolvedPackage]) {
//         self.pins = pins
//     }
// }

// public struct ResolvedPackage: Decodable {
//     let package: String
//     let repositoryURL: URL
//     let state: ResolvedPackageState
    
//     public init(package: String, repositoryURL: URL, state: ResolvedPackageState) {
//         self.package = package
//         self.repositoryURL = repositoryURL
//         self.state = state
//     }
// }

public struct ResolvedPackageState: Decodable {
    let branch: String?
    let revision: String?
    let version: String?

    public init(
        branch: String? = nil,
        revision: String? = nil,
        version: String? = nil
    ) {
        self.branch = branch
        self.revision = revision
        self.version = version
    }
}

public func packageResolvedFile(from workspacePath: String) -> Reader<PathExists, Result<URL, GeneratePlistError>> {
    Reader { pathExists in
        let (exists, isDirectory) = pathExists(workspacePath)
        guard exists else { return .failure(.workspacePathDoesNotExist) }
        guard isDirectory else { return .failure(.workspacePathIsNotAFolder) }

        let workspaceURL = URL(fileURLWithPath: workspacePath, isDirectory: true)
        let packageResolved = workspaceURL
            .appendingPathComponent("xcshareddata", isDirectory: true)
            .appendingPathComponent("swiftpm", isDirectory: true)
            .appendingPathComponent("Package.resolved", isDirectory: false)

        guard pathExists(packageResolved.path) == (exists: true, isDirectory: false) else {
            return .failure(.swiftPackageNotPresent)
        }

        return .success(packageResolved)
    }
}

public func readSwiftPackageResolvedJson(url: URL) -> Reader<Decoder<ResolvedPackageContentV2>, Result<ResolvedPackageContentV2, GeneratePlistError>> {
    Reader { decoder in
        Result { try Data(contentsOf: url) }
            .mapError(GeneratePlistError.swiftPackageCannotBeOpen)
            .flatMap { decoder($0).mapError(GeneratePlistError.swiftPackageJsonCannotBeDecoded) }
    }
}
