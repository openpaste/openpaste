import Foundation
import SwiftUI

@Observable
final class AppController {
    var windowManager = WindowManager()
    var pasteStackViewModel = PasteStackViewModel()
    var settingsViewModel: SettingsViewModel
    var updaterService: UpdaterServiceProtocol
    var feedbackRouter: FeedbackRouterProtocol = FeedbackRouter()
    var historyViewModel: HistoryViewModel?
    var searchViewModel: SearchViewModel?
    var collectionViewModel: CollectionViewModel?
    var initError: String?
    var showOnboarding: Bool

    private var container: DependencyContainer?
    private var hotkeyManager: HotkeyManager?
    private var cleanupService: SecurityService?
    private var onboardingWindowManager: OnboardingWindowManager?
    private var pasteInterceptor: PasteInterceptor?
    private var screenSharingDetector: ScreenSharingDetector?
    private let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    init() {
        let svm = SettingsViewModel()
        settingsViewModel = svm
        showOnboarding = isRunningTests ? false : OnboardingViewModel.shouldShowOnboarding
        updaterService = isRunningTests ? DisabledUpdaterService() : UpdaterService()

        guard !isRunningTests else { return }

        do {
            let c = try DependencyContainer()
            container = c
            feedbackRouter = c.feedbackRouter

            let hvm = HistoryViewModel(
                storageService: c.storageService,
                clipboardService: c.clipboardService,
                eventBus: c.eventBus
            )
            hvm.dismissAction = { [weak self] in
                self?.windowManager.hide()
            }
            hvm.reactivatePreviousApp = { [weak self] in
                self?.windowManager.reactivatePreviousApp()
            }
            hvm.previousAppBundleId = { [weak self] in
                self?.windowManager.previousApp?.bundleIdentifier
            }
            historyViewModel = hvm

            let searchVm = SearchViewModel(
                searchService: c.searchService,
                storageService: c.storageService,
                clipboardService: c.clipboardService
            )
            searchVm.dismissAction = { [weak self] in
                self?.windowManager.hide()
            }
            searchVm.reactivatePreviousApp = { [weak self] in
                self?.windowManager.reactivatePreviousApp()
            }
            searchVm.previousAppBundleId = { [weak self] in
                self?.windowManager.previousApp?.bundleIdentifier
            }
            searchViewModel = searchVm

            collectionViewModel = CollectionViewModel(storageService: c.storageService)

            pasteStackViewModel.configure(clipboardService: c.clipboardService)
            pasteStackViewModel.dismissAction = { [weak self] in
                self?.windowManager.hide()
            }
            pasteStackViewModel.reactivatePreviousApp = { [weak self] in
                self?.windowManager.reactivatePreviousApp()
            }
            pasteStackViewModel.previousAppBundleId = { [weak self] in
                self?.windowManager.previousApp?.bundleIdentifier
            }

            svm.onClearAllHistory = { [weak hvm] in
                try? await c.storageService.deleteAll()
                await hvm?.loadInitial()
            }
            svm.storageService = c.storageService
            svm.syncService = c.syncService
            svm.eventBus = c.eventBus
            svm.startSyncObserver()

            if AppDelegate.consumePendingRemoteNotification() {
                Task {
                    await c.syncService.triggerManualSync()
                    await svm.refreshSyncInfo()
                }
            }

            Task {
                await c.syncService.start()
                await svm.refreshSyncInfo()
            }

            let cleanup = SecurityService(
                detector: c.securityService as! SensitiveContentDetector,
                storageService: c.storageService
            )
            cleanupService = cleanup

            Task {
                await c.clipboardService.startMonitoring()
            }
            Task { @MainActor in
                cleanup.startCleanupTimer()
            }

            setupHotkey()
            setupPasteInterceptor()
            setupScreenSharingDetector()
        } catch {
            initError = error.localizedDescription
        }

        // Listen for onboarding trigger from AppDelegate
        NotificationCenter.default.addObserver(
            forName: AppDelegate.showOnboardingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showOnboardingIfNeeded()
            }
        }

        NotificationCenter.default.addObserver(
            forName: AppDelegate.didReceiveRemoteNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            _ = AppDelegate.consumePendingRemoteNotification()
            guard let self, let c = self.container else { return }
            Task {
                await c.syncService.triggerManualSync()
                await self.settingsViewModel.refreshSyncInfo()
            }
        }
    }

    private func setupHotkey() {
        let hk = HotkeyManager { [weak self] in
            self?.togglePanel()
        }
        hotkeyManager = hk
        Task { await hk.register() }
    }

    private func setupPasteInterceptor() {
        let interceptor = PasteInterceptor()
        pasteInterceptor = interceptor

        interceptor.start { [weak self] in
            guard let self, self.pasteStackViewModel.isActive else { return }
            // Set reentrancy guard before pasting to avoid ⌘V feedback loop
            interceptor.isSynthesizingPaste = true
            Task {
                await self.pasteStackViewModel.pasteNext()
                interceptor.isSynthesizingPaste = false
            }
        }

        // Sync paste stack state to enable/disable ⌘V interception
        Task { @MainActor in
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.pasteInterceptor?.isPasteStackActive = self.pasteStackViewModel.isActive
            }
        }
    }

    private func setupScreenSharingDetector() {
        let detector = ScreenSharingDetector()
        screenSharingDetector = detector

        Task { @MainActor in
            detector.startMonitoring { [weak self] in
                self?.windowManager.hide()
            }
        }
    }

    func togglePanel() {
        guard let hvm = historyViewModel,
              let svm = searchViewModel else { return }
        let pvm = pasteStackViewModel
        let cvm = collectionViewModel
        windowManager.toggle {
            ContentView(
                historyViewModel: hvm,
                searchViewModel: svm,
                pasteStackViewModel: pvm,
                collectionViewModel: cvm
            )
        }
    }

    @MainActor
    func showOnboardingIfNeeded() {
        guard showOnboarding else { return }
        let owm = OnboardingWindowManager()
        onboardingWindowManager = owm
        owm.show { [weak self] in
            self?.showOnboarding = false
            self?.onboardingWindowManager = nil
            // Re-register hotkey with potentially new key combo
            Task { @MainActor in
                self?.hotkeyManager?.unregister()
                self?.setupHotkey()
            }
        }
    }
}
