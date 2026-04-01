import Foundation
import SwiftUI

@Observable
final class AppController {
    var windowManager = WindowManager()
    var pasteStackViewModel = PasteStackViewModel()
    var settingsViewModel: SettingsViewModel
    var historyViewModel: HistoryViewModel?
    var searchViewModel: SearchViewModel?
    var collectionViewModel: CollectionViewModel?
    var initError: String?

    private var container: DependencyContainer?
    private var hotkeyManager: HotkeyManager?
    private var cleanupService: SecurityService?

    init() {
        let svm = SettingsViewModel()
        settingsViewModel = svm

        do {
            let c = try DependencyContainer()
            container = c

            let hvm = HistoryViewModel(
                storageService: c.storageService,
                clipboardService: c.clipboardService,
                eventBus: c.eventBus
            )
            hvm.dismissAction = { [weak self] in
                self?.windowManager.hide()
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
            searchViewModel = searchVm

            collectionViewModel = CollectionViewModel(storageService: c.storageService)

            pasteStackViewModel.configure(clipboardService: c.clipboardService)
            pasteStackViewModel.dismissAction = { [weak self] in
                self?.windowManager.hide()
            }

            svm.onClearAllHistory = { [weak hvm] in
                try? await c.storageService.deleteAll()
                await hvm?.loadInitial()
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
        } catch {
            initError = error.localizedDescription
        }
    }

    private func setupHotkey() {
        let hk = HotkeyManager { [weak self] in
            self?.togglePanel()
        }
        hotkeyManager = hk
        Task { await hk.register() }
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
}
