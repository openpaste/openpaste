import Foundation
import AppKit
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
    private let isUITestMode: Bool = {
        #if DEBUG
        ProcessInfo.processInfo.environment["OPENPASTE_UI_TEST_MODE"] == "1"
        #else
        false
        #endif
    }()

    init() {
        let svm = SettingsViewModel()
        settingsViewModel = svm

        let isTestLike = isRunningTests || isUITestMode
        showOnboarding = isTestLike ? false : OnboardingViewModel.shouldShowOnboarding
        updaterService = isTestLike ? DisabledUpdaterService() : UpdaterService()

        guard !isRunningTests || isUITestMode else { return }

        do {
            let c = try DependencyContainer(uiTestMode: isUITestMode)
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

            if !isUITestMode {
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
            }

            let cleanup = SecurityService(
                detector: c.securityService as! SensitiveContentDetector,
                storageService: c.storageService
            )
            cleanupService = cleanup

            if !isUITestMode {
                Task {
                    await c.clipboardService.startMonitoring()
                }
                Task { @MainActor in
                    cleanup.startCleanupTimer()
                }

                setupHotkey()
                setupPasteInterceptor()
                setupScreenSharingDetector()
            } else {
                configureDefaultsForUITests()
                Task {
                    await seedAndOpenPanelIfNeeded(container: c)
                }
            }
        } catch {
            initError = error.localizedDescription
            #if DEBUG
            NSLog("OpenPaste init error: %@", String(describing: error))
            #endif
        }

        guard !isUITestMode else { return }

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

    private var uiTestEnvironment: [String: String] {
        ProcessInfo.processInfo.environment
    }

    private var shouldSeedImageForUITests: Bool {
        isUITestMode && uiTestEnvironment["OPENPASTE_UI_TEST_SEED_IMAGE"] == "1"
    }

    private var shouldOpenPanelForUITests: Bool {
        isUITestMode && uiTestEnvironment["OPENPASTE_UI_TEST_OPEN_PANEL"] == "1"
    }

    private func configureDefaultsForUITests() {
        // Override preferences in-memory (non-persistent) so UI tests don't leak settings.
        let overrides: [String: Any] = [
            Constants.windowPositionModeKey: "center",
            Constants.showShortcutHintsKey: false,
        ]
        UserDefaults.standard.setVolatileDomain(overrides, forName: "OpenPasteUITestOverrides")
        UserDefaults.standard.register(defaults: overrides)
    }

    private func seedAndOpenPanelIfNeeded(container: DependencyContainer) async {
        if shouldSeedImageForUITests {
            await seedTestImageItem(storageService: container.storageService)
        }
        if shouldOpenPanelForUITests {
            await MainActor.run {
                guard !self.windowManager.isVisible else { return }
                self.togglePanel()
            }
        }
    }

    private func seedTestImageItem(storageService: StorageServiceProtocol) async {
        guard let data = Self.makeUITestTIFFData(width: 80, height: 60) else { return }

        let hash = ContentHasher().hash(data)
        let item = ClipboardItem(
            type: .image,
            content: data,
            sourceApp: AppInfo(bundleId: "dev.tuanle.OpenPaste.uitests", name: "UI Tests", iconPath: nil),
            contentHash: hash
        )

        try? await storageService.save(item)
    }

    private static func makeUITestTIFFData(width: Int, height: Int) -> Data? {
        guard width > 0, height > 0 else { return nil }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
            let bitmap = rep.bitmapData
        else {
            return nil
        }

        let bytesPerRow = rep.bytesPerRow
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                bitmap[offset + 0] = UInt8((x * 255) / max(width - 1, 1))
                bitmap[offset + 1] = UInt8((y * 255) / max(height - 1, 1))
                bitmap[offset + 2] = 0
                bitmap[offset + 3] = 255
            }
        }

        return rep.tiffRepresentation
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
