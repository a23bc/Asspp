//
//  DownloadView.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/11.
//

import SwiftUI

struct DownloadView: View {
    @ObservedObject private var vm = Downloads.this

    #if os(iOS)
        @State private var importing = false
        @State private var importError: String?
        @State private var importedInstaller: Installer?
    #endif

    var body: some View {
        content
            .navigationTitle("Downloads")
            .inNavigationRoot()
        #if os(iOS)
            .fileImporter(
                isPresented: $importing,
                allowedContentTypes: ImportedPackage.pickerTypes,
                allowsMultipleSelection: false,
            ) { result in
                switch result {
                case let .success(urls):
                    guard let url = urls.first else {
                        logger.info("import: picker returned no file")
                        return
                    }
                    importPackage(at: url)
                case let .failure(error):
                    logger.error("import: picker failed \(StoreDiagnostics.errorSummary(error))")
                    importError = error.localizedDescription
                }
            }
            .sheet(item: $importedInstaller) {
                importedInstaller?.destroy()
                importedInstaller = nil
            } content: {
                InstallerView(installer: $0)
            }
            .alert("Import Failed", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } },
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
        #endif
    }

    /// An IPA downloaded with another tool still carries Apple's signature, so
    /// the local installer can serve it once it is inside app storage.
    #if os(iOS)
        private func importPackage(at url: URL) {
            logger.info("import: staging \(url.lastPathComponent)")
            do {
                let staged = try ImportedPackage.stage(from: url)
                logger.info("import: staged as \(staged.archive.software.bundleID) \(staged.archive.software.version)")
                Task { @MainActor in
                    do {
                        importedInstaller = try await Installer(archive: staged.archive, path: staged.url)
                    } catch {
                        logger.error("import: installer failed \(StoreDiagnostics.errorSummary(error))")
                        importError = error.localizedDescription
                    }
                }
            } catch {
                logger.error("import: staging failed \(StoreDiagnostics.errorSummary(error))")
                importError = error.localizedDescription
            }
        }
    #endif

    private var content: some View {
        Group {
            if vm.manifests.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No Downloads")
                        .font(.headline)
                    Text("Search for an app or add a download link to get started.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    NavigationLink(destination: AddDownloadView()) {
                        Text("Add Download")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Form {
                    packageList
                }
            }
        }
        .groupedFormStyle()
        .toolbar {
            #if os(iOS)
                ToolbarItem {
                    Button {
                        importing = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            #endif
            ToolbarItem {
                NavigationLink(destination: AddDownloadView()) {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private var packageList: some View {
        ForEach(vm.manifests, id: \.id) { req in
            PackageManifestRow(manifest: req)
        }
    }
}

private struct PackageManifestRow: View {
    @ObservedObject var manifest: PackageManifest
    @ObservedObject private var vm = Downloads.this

    var body: some View {
        NavigationLink(destination: PackageView(pkg: manifest)) {
            VStack(spacing: 8) {
                ArchivePreviewView(archive: manifest.package)
                SimpleProgress(progress: manifest.state.percent)
                    .animation(.interactiveSpringDefault, value: manifest.state.percent)
                HStack {
                    Text(manifest.hint)
                    Spacer()
                    Text(manifest.creation.formatted())
                }
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
            }
        }
        .contextMenu {
            let actions = vm.getAvailableActions(for: manifest)
            ForEach(actions, id: \.self) { action in
                let label = vm.getActionLabel(for: action)
                Button(role: label.isDestructive ? .destructive : .none) {
                    vm.performDownloadAction(for: manifest, action: action)
                } label: {
                    Label(label.title, systemImage: label.systemImage)
                }
            }
        }
    }
}

extension PackageManifest {
    var hint: String {
        if let error = state.error {
            return error
        }
        return switch state.status {
        case .pending:
            String(localized: "Pending...")
        case .downloading:
            [
                String(Int(state.percent * 100)) + "%",
                state.speed.isEmpty ? "" : state.speed + "/s",
            ]
            .compactMap(\.self)
            .joined(separator: " ")
        case .paused:
            String(localized: "Paused")
        case .completed:
            String(localized: "Completed")
        case .failed:
            String(localized: "Failed")
        }
    }
}
