// Copyright © 2021 Lautsprecher Teufel GmbH. All rights reserved.

import Combine
import Foundation
import FoundationExtensions
import Helper

public typealias PackageRepository = (package: ResolvedPackageV2, repository: GitHubRepository)
public typealias PackageLicense = (package: ResolvedPackageV2, license: GitHubLicense)

public func extractPackageGitHubRepositories(from spmFile: ResolvedPackageContentV2) -> [PackageRepository] {
    spmFile.pins.compactMap { spmPackage in
        guard let repository = githubRepository(from: spmPackage.location).value else {
            print("Ignoring project \(spmPackage.identity) because we don't know how to fetch the license from it")
            return nil
        }

        return PackageRepository(package: spmPackage, repository: repository)
    }
}

public func fetchGithubLicenses(
    packageRepositories: [PackageRepository],
    githubClientID: String?,
    githubClientSecret: String?
) -> Reader<(Request, Decoder<GitHubLicense>), Publishers.Promise<[PackageLicense], GeneratePlistError>> {
    Reader { requester, decoder in
        Publishers.Promise.zip(
            packageRepositories.map { packageRepository in
                githubLicensingAPI(
                    repository: packageRepository.repository,
                    githubClientID: githubClientID,
                    githubClientSecret: githubClientSecret
                )
                .inject((requester, decoder))
                .map { license in PackageLicense(package: packageRepository.package, license: license) }
            }
        )
    }
}

public func cocoaPodsModel(packageLicenses: [PackageLicense]) -> Reader<Request, Publishers.Promise<CocoaPodsPlist, GeneratePlistError>> {
    Reader { requester in
        Publishers.Promise.zip(
            packageLicenses.map { packageLicense in
                downloadGitHubLicenseFile(url: packageLicense.license.downloadUrl)
                    .inject(requester)
                    .map { footerText in
                        CocoaPodsPlist.Item(title: packageLicense.package.identity, license: packageLicense.license.licenseName, footerText: footerText)
                    }
            }
        )
        .map(CocoaPodsPlist.init)
    }
}
