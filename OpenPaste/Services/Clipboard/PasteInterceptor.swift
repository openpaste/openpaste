import Foundation
import CoreGraphics
import AppKit

final class PasteInterceptor: @unchecked Sendable {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isActive = false
    private var onPasteIntercepted: (() -> Void)?
    /// Reentrancy guard: set true while synthesizing a paste to avoid infinite loop
    var isSynthesizingPaste: Bool = false
    
    var isPasteStackActive: Bool = false {
        didSet {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: isPasteStackActive)
            }
        }
    }
    
    func start(onPasteIntercepted: @escaping () -> Void) {
        guard eventTap == nil else { return }
        self.onPasteIntercepted = onPasteIntercepted
        
        guard AXIsProcessTrusted() else {
            print("[PasteInterceptor] Accessibility permission not granted")
            return
        }
        
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, _, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let interceptor = Unmanaged<PasteInterceptor>.fromOpaque(refcon).takeUnretainedValue()
                return interceptor.handleEvent(event)
            },
            userInfo: refcon
        ) else {
            print("[PasteInterceptor] Failed to create event tap - check Accessibility permission")
            return
        }
        
        eventTap = tap
        // Start disabled until paste stack is activated
        CGEvent.tapEnable(tap: tap, enable: false)
        
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        isActive = true
    }
    
    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        eventTap = nil
        runLoopSource = nil
        isActive = false
    }
    
    private func handleEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isPasteStackActive, !isSynthesizingPaste else {
            return Unmanaged.passUnretained(event)
        }
        
        let flags = event.flags.intersection(.maskCommand)
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        
        // ⌘V = Command + keycode 9
        let shiftPresent = event.flags.contains(.maskShift)
        if flags.contains(.maskCommand) && keycode == 9 && !shiftPresent {
            DispatchQueue.main.async { [weak self] in
                self?.onPasteIntercepted?()
            }
            return nil // swallow the event
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    deinit {
        stop()
    }
}
