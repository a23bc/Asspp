//
//  ImportedPackage.swift
//  Asspp
//

import ApplePackage
import Foundation
import UniformTypeIdentifiers
import ZIPFoundation

/// Stages a store-signed IPA that was downloaded elsewhere so the built-in
/// OTA installer can serve it. The manifest only needs the bundle identity,
/// which the package carries in its own Info.plist.
enum ImportedPackage {
    /// `ipa` is not a declared system type, so a picker filtered to a narrow
    /// type dims matching files and taps on them do nothing. The identifier is
    /// declared in Info.plist as an imported type; data and item remain as a
    /// fallback for packages the system typed differently.
    static let pickerTypes: [UTType] = [
        UTType(importedAs: "com.apple.itunes.ipa"),
        UTType(filenameExtension: "ipa", conformingTo: .data) ?? .data,
        .data,
        .item,
    ]

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

    /// Imported packages are staged outside the download list, so they need
    /// their own accounting and removal path.
    static func stagedFiles() -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles],
        ) else { return [] }
        return enumerator.compactMap { item in
            guard let url = item as? URL, url.pathExtension == "ipa" else { return nil }
            return url
        }
    }

    static func stagedSize(files: [URL] = stagedFiles()) -> Int64 {
        files.reduce(Int64(0)) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
    }

    @discardableResult
    static func clearStaged() -> Int {
        var removed = 0
        for file in stagedFiles() {
            do {
                try FileManager.default.removeItem(at: file)
                removed += 1
            } catch {
                logger.error("failed to remove imported package: \(file.lastPathComponent)")
            }
        }
        return removed
    }
}
