//
//  AccountView.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/11.
//

import ApplePackage
import SwiftUI

struct AccountView: View {
    @ObservedObject private var vm = AppStore.this
    @State private var addAccount = false
    @State private var selectedID: AppStore.UserAccount.ID?
    #if os(macOS)
        @State private var navigationPath = NavigationPath()
    #endif

    var body: some View {
        #if os(macOS)
            macOSBody
        #else
            iOSBody
        #endif
    }

    #if os(macOS)
        private var macOSBody: some View {
            NavigationStack(path: $navigationPath) {
                Group {
                    if vm.accounts.isEmpty {
                        ContentUnavailableView(
                            label: {
                                Label("No Accounts", systemImage: "person.crop.circle.badge.questionmark")
                            },
                            description: {
                                Text("Add an Apple ID to start downloading IPA packages.")
                            },
                            actions: {
                                Button("Add Account") { addAccount.toggle() }
                            },
                        )
                        .padding()
                    } else {
                        accountsTable
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationDestination(for: AppStore.UserAccount.ID.self) { id in
                    AccountDetailView(accountId: id)
                }
                .navigationTitle("Accounts")
                .toolbar { macToolbar }
            }
            .sheet(isPresented: $addAccount) {
                AddAccountView()
                    .frame(minWidth: 480, idealWidth: 520, minHeight: 340, idealHeight: 380)
            }
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }

        private var accountsTable: some View {
            Table(vm.accounts, selection: $selectedID) {
                TableColumn("Email") { account in
                    Text(account.account.email)
                        .redacted(reason: .placeholder, isEnabled: vm.demoMode)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .width(min: 240, ideal: 400, max: .infinity)

                TableColumn("Region") { account in
                    Text(account.account.store)
                }
                .width(min: 72, ideal: 88, max: 100)

                TableColumn("Storefront") { account in
                    Text(ApplePackage.Configuration.countryCode(for: account.account.store) ?? String(localized: "Unknown"))
                }
                .width(min: 56, ideal: 64, max: 80)

                TableColumn("") { account in
                    Button {
                        navigationPath.append(account.id)
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.borderless)
                }
                .width(32)
            }
            .contextMenu(forSelectionType: AppStore.UserAccount.ID.self) { ids in
                if let id = ids.first {
                    Button("View Details") {
                        navigationPath.append(id)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        private var footer: some View {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.title3)
                Text("Accounts are stored securely in your Keychain and can be removed at any time from the detail view.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }

        @ToolbarContentBuilder
        private var macToolbar: some ToolbarContent {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addAccount.toggle()
                } label: {
                    Label("Add Account", systemImage: "plus")
                }
            }
        }
    #endif

    #if !os(macOS)
        private var iOSBody: some View {
            Group {
                if vm.accounts.isEmpty {
                    emptyState
                } else {
                    accountList
                }
            }
            .navigationTitle("Accounts")
            .toolbar {
                ToolbarItem {
                    Button {
                        addAccount.toggle()
                    } label: {
                        Label("Add Account", systemImage: "plus")
                    }
                }
            }
            .inNavigationRoot()
            .sheet(isPresented: $addAccount) {
                AddAccountView()
                    .inNavigationRoot()
            }
        }

        private var accountList: some View {
            Form {
                Section {
                    ForEach(vm.accounts) { account in
                        NavigationLink(destination: AccountDetailView(accountId: account.id)) {
                            HStack {
                                Text(account.account.email)
                                    .redacted(reason: .placeholder, isEnabled: vm.demoMode)
                                Spacer()
                                Text(ApplePackage.Configuration.countryCode(for: account.account.store) ?? account.account.store)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Apple IDs")
                } footer: {
                    Text("Your accounts are saved in your Keychain and will be synced across devices with the same iCloud account signed in.")
                }
            }
            .groupedFormStyle()
        }

        private var emptyState: some View {
            VStack(spacing: 12) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No Accounts")
                    .font(.headline)
                Text("Add an Apple ID to start downloading IPA packages.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Add Account") { addAccount.toggle() }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    #endif
}
