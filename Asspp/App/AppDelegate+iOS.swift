//
//  AppDelegate+iOS.swift
//  Asspp
//

#if canImport(UIKit)
    import Combine
    import UIKit

    class AppDelegate: NSObject, UIApplicationDelegate {
        var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
        private var downloadObserver: AnyCancellable?

        func application(
            _: UIApplication,
            didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil,
        ) -> Bool {
            Task { @MainActor in
                self.observeDownloadCount()
            }
            return true
        }

        @MainActor
        private func observeDownloadCount() {
            updateIdleState()
            downloadObserver = Downloads.this.objectWillChange
                .sink { [weak self] _ in
                    // objectWillChange fires before the mutation lands, so read
                    // the count on the next main-actor turn.
                    Task { @MainActor in
                        self?.updateIdleState()
                    }
                }
        }

        @MainActor
        private func updateIdleState() {
            let count = Downloads.this.runningTaskCount
            UIApplication.shared.isIdleTimerDisabled = count > 0
            BackgroundAudioPlayer.shared.setActive(count > 0)
        }

        func applicationWillResignActive(_: UIApplication) {
            guard Downloads.this.runningTaskCount > 0 else { return }
            let task = UIApplication.shared.beginBackgroundTask(withName: "Downloads") {
                UIApplication.shared.endBackgroundTask(self.backgroundTaskIdentifier)
                self.backgroundTaskIdentifier = .invalid
            }
            backgroundTaskIdentifier = task
        }

        func applicationWillEnterForeground(_: UIApplication) {
            guard backgroundTaskIdentifier != .invalid else { return }
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
    }
#endif
