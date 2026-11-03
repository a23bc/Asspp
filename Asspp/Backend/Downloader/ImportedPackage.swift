//
//  ImportedPackage.swift
//  Asspp
//

import ApplePackage
import Foundation
import ZIPFoundation

/// Stages a store-signed IPA that was downloaded elsewhere so the built-in
/// OTA installer can serve it. The manifest only needs the bundle identity,
/// which the package carries in its own Info.plist.
enum ImportedPackage {
    struct Staged {
        let url: URL
        let archive: AppStore.AppPackage
    }

    enum Failure: LocalizedError {
        case notPackage
        case noAppBundle
        case missingIdentifier

        var errorDescription: String? {
            switch self {
            case .notPackage:
                String(localized: "The selected file is not an IPA package.")
            case .noAppBundle:
                String(localized: "This package has no app bundle under Payload/.")
            case .missingIdentifier:
                String(localized: "The app bundle is missing its bundle identifier.")
            }
        }
    }

    private static let directory = documentsDirectory.appendingPathComponent("Imported")

    static func stage(from source: URL) throws -> Staged {
        // The picker grants access only for this call, so the copy must happen
        // before the scope is released.
        let scoped = source.startAccessingSecurityScopedResource()
        defer {
            if scoped { source.stopAccessingSecurityScopedResource() }
        }

        guard source.pathExtension.lowercased() == "ipa" else { throw Failure.notPackage }
        let info = try mainInfoPlist(of: source)
        guard let bundleID = info["CFBundleIdentifier"] as? String, !bundleID.isEmpty else {
            throw Failure.missingIdentifier
        }
        let name = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? source.deletingPathExtension().lastPathComponent
        let version = (info["CFBundleShortVersionString"] as? String)
            ?? (info["CFBundleVersion"] as? String)
            ?? "0"

        let folder = directory
            .appendingPathComponent(bundleID)
            .appendingPathComponent(version)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent("\(UUID().uuidString).ipa")
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: source, to: destination)

        let software = ApplePackage.Software(
            id: .random(),
            bundleID: bundleID,
            name: name,
            version: version,
            artistName: "",
            sellerName: "",
            description: "",
            averageUserRating: 0,
            userRatingCount: 0,
            artworkUrl: "",
            screenshotUrls: [],
            minimumOsVersion: info["MinimumOSVersion"] as? String ?? "",
            releaseDate: "",
            formattedPrice: "",
            primaryGenreName: "",
        )
        return Staged(url: destination, archive: AppStore.AppPackage(software: software))
    }

    private static func mainInfoPlist(of package: URL) throws -> [String: Any] {
        let archive = try Archive(url: package, accessMode: .read)
        guard let entry = archive.first(where: { StoreDownloadProtocol.isMainInfoPlist($0.path) }) else {
            throw Failure.noAppBundle
        }
        let scratch = temporaryDirectory
            .appendingPathComponent("ImportedInfoPlist")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: scratch.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        defer { try? FileManager.default.removeItem(at: scratch) }
        _ = try archive.extract(entry, to: scratch)
        guard let plist = try? PropertyListSerialization.propertyList(
            from: Data(contentsOf: scratch),
            format: nil,
        ) as? [String: Any] else { throw Failure.noAppBundle }
        return plist
    }
}
