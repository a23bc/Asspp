//
//  AppStore.swift
//  Asspp
//
//  Created by 秋星桥 on 2024/7/11.
//

import ApplePackage
import Combine
import Foundation

@MainActor
class AppStore: ObservableObject {
    @PublishedPersist(
        key: "Accounts",
        defaultValue: [],
        keychain: "wiki.qaq.Asspp.Accounts",
    )
    var accounts: [UserAccount]

    @PublishedPersist(
        key: "DeviceIdentifier",
        defaultValue: "",
        keychain: "wiki.qaq.Asspp.DeviceIdentifier",
    )
    var deviceIdentifier: String

    @PublishedPersist(key: "DemoMode", defaultValue: false)
    var demoMode: Bool

    /// Assigns the identifier and mirrors it into ApplePackage, which reads it
    /// for every store request.
    func setDeviceIdentifier(_ value: String) {
        deviceIdentifier = value
        ApplePackage.Configuration.deviceIdentifier = value
    }

    static let this = AppStore()

    static func normalizedDeviceIdentifier(_ value: String) -> String? {
        let identifier = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
        guard identifier.utf8.count == 12,
              identifier.utf8.allSatisfy({ (48 ... 57).contains($0) || (65 ... 70).contains($0) }),
              !["020000000000", "000000000000", "FFFFFFFFFFFF"].contains(identifier)
        else { return nil }
        return identifier
    }

    private init() {
        // Preserve identifiers used by existing accounts until the user edits them.
        if deviceIdentifier.isEmpty || (accounts.isEmpty && Self.normalizedDeviceIdentifier(deviceIdentifier) == nil) {
            if let systemIdentifier = (try? ApplePackage.DeviceIdentifier.system()).flatMap(Self.normalizedDeviceIdentifier) {
                setDeviceIdentifier(systemIdentifier)
                logger.info("obtained system device identifier")
            } else {
                logger.info("using a generated device identifier")
                var randomIdentifier = ApplePackage.DeviceIdentifier.random()
                while Self.normalizedDeviceIdentifier(randomIdentifier) == nil {
                    randomIdentifier = ApplePackage.DeviceIdentifier.random()
                }
                setDeviceIdentifier(randomIdentifier)
            }
        }
        ApplePackage.Configuration.deviceIdentifier = deviceIdentifier
    }

    @discardableResult
    func save(email: String, account: ApplePackage.Account) throws -> UserAccount {
        logger.info("saving account for user")
        let account = UserAccount(account: account)
        let updatedAccounts = (accounts.filter { $0.account.email != email } + [account])
            .sorted { $0.account.email < $1.account.email }
        do {
            try _accounts.setAndSave(updatedAccounts)
            objectWillChange.send()
        } catch {
            throw AccountStorageError()
        }
        return account
    }

    private struct AccountStorageError: LocalizedError {
        var errorDescription: String? {
            String(localized: "Unable to save the account to Keychain. Check the app's code signing and Keychain access, then try again.")
        }
    }

    func delete(id: UserAccount.ID) {
        logger.info("deleting account id: \(id)")
        accounts = accounts.filter { $0.id != id }
    }

    var possibleRegions: Set<String> {
        Set(accounts.compactMap { ApplePackage.Configuration.countryCode(for: $0.account.store) })
    }

    func eligibleAccounts(for region: String) -> [UserAccount] {
        accounts.filter { ApplePackage.Configuration.countryCode(for: $0.account.store) == region }
    }

    nonisolated func withAccount<T>(id: String, _ body: (inout UserAccount) async throws -> T) async throws -> T {
        guard var account = await accounts.first(where: { $0.id == id }) else {
            throw AuthenticationError.accountNotFound
        }
        let result = try await body(&account)
        let updatedAccount = account
        // Re-resolve by id: the accounts array may have been mutated (added,
        // removed, re-sorted) during the await, so the original index is stale.
        await MainActor.run {
            if let idx = accounts.firstIndex(where: { $0.id == id }) {
                accounts[idx] = updatedAccount
            }
        }
        return result
    }
}
