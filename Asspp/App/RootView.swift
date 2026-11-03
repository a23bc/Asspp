//
//  RootView.swift
//  Asspp
//

#if !os(macOS)
    import SwiftUI

    /// Hosts the tab bar and the import sheet together, so an import started
    /// from any tab presents the installer above the tabs.
    struct RootView: View {
        @ObservedObject private var opener = ImportedIPAOpener.shared

        var body: some View {
            Group {
                if #available(iOS 26.0, *) {
                    NewMainView()
                } else {
                    MainView()
                }
            }
            .onOpenURL { opener.open(url: $0) }
            .sheet(item: $opener.installer) {
                opener.dismissInstaller()
            } content: {
                InstallerView(installer: $0)
            }
            .alert("Import Failed", isPresented: Binding(
                get: { opener.failure != nil },
                set: { if !$0 { opener.failure = nil } },
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(opener.failure ?? "")
            }
        }
    }
#endif
