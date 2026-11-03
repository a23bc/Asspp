//
//  ImportedIPAOpener.swift
//  Asspp
//

import Combine
import Foundation

/// Shared entry point for installs that start outside the download list,
/// whether the file came from the picker or from Files → Share → Open in Asspp.
@MainActor
final class ImportedIPAOpener: ObservableObject {
    static let shared = ImportedIPAOpener()

    @Published var installer: Installer?
    @Published var failure: String?

    private init() {}

    /// SwiftUI hands picker and URL callbacks to nonisolated closures, so the
    /// entry points stay nonisolated and hop to the main actor themselves.
    nonisolated func open(url: URL) {
        Task { @MainActor in
            logger.info("import: staging \(url.lastPathComponent)")
            let staged: ImportedPackage.Staged
            do {
                staged = try ImportedPackage.stage(from: url)
            } catch {
                logger.error("import: staging failed \(StoreDiagnostics.errorSummary(error))")
                failure = error.localizedDescription
                return
            }
            logger.info("import: staged as \(staged.archive.software.bundleID) \(staged.archive.software.version)")
            do {
                installer = try await Installer(archive: staged.archive, path: staged.url)
            } catch {
                logger.error("import: installer failed \(StoreDiagnostics.errorSummary(error))")
                failure = error.localizedDescription
            }
        }
    }

    nonisolated func dismissInstaller() {
        Task { @MainActor in
            installer?.destroy()
            installer = nil
        }
    }
}
