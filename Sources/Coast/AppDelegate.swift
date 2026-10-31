import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings()
    private lazy var engine = ScrollEngine(settings: settings)
    private var statusItem: NSStatusItem!
    private var permissionTimer: Timer?

    private let enabledItem = NSMenuItem(title: "Smooth Scrolling", action: #selector(toggleEnabled), keyEquivalent: "")
    private let reverseItem = NSMenuItem(title: "Reverse Wheel Direction", action: #selector(toggleReverse), keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
    private let permissionItem = NSMenuItem(title: "Grant Accessibility Access…", action: #selector(openAccessibility), keyEquivalent: "")
    private var speedRow: SliderRow!
    private var glideRow: SliderRow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Self.menuBarIcon()
        statusItem.button?.toolTip = "Coast"
        statusItem.menu = buildMenu()

        if !engine.start() {
            // First launch: ask macOS for permission, then wait for it.
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                guard let self, AXIsProcessTrusted(), self.engine.start() else { return }
                self.permissionTimer?.invalidate()
                self.permissionTimer = nil
                self.refresh()
            }
        }
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        for item in [enabledItem, reverseItem, loginItem, permissionItem] { item.target = self }

        speedRow = SliderRow(title: "Speed", range: Settings.speedRange, value: settings.speed,
                             format: { String(format: "%.1f×", $0) }) { [weak self] in self?.settings.speed = $0 }
        glideRow = SliderRow(title: "Glide", range: Settings.glideRange, value: settings.glide,
                             format: { String(format: "%.2fs", $0) }) { [weak self] in self?.settings.glide = $0 }

        menu.addItem(permissionItem)
        menu.addItem(enabledItem)
        menu.addItem(reverseItem)
        menu.addItem(.separator())
        menu.addItem(speedRow.menuItem)
        menu.addItem(glideRow.menuItem)
        menu.addItem(.separator())
        menu.addItem(loginItem)
        let about = NSMenuItem(title: "About Coast", action: #selector(openAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(NSMenuItem(title: "Quit Coast", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    func menuWillOpen(_ menu: NSMenu) { refresh() }

    private func refresh() {
        enabledItem.state = settings.enabled ? .on : .off
        reverseItem.state = settings.reverse ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        permissionItem.isHidden = engine.isRunning
        statusItem.button?.appearsDisabled = !settings.enabled || !engine.isRunning
        speedRow.value = settings.speed
        glideRow.value = settings.glide
    }

    @objc private func toggleEnabled() {
        settings.enabled.toggle()
        refresh()
    }

    @objc private func toggleReverse() {
        settings.reverse.toggle()
        refresh()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Couldn't change Open at Login"
            alert.runModal()
        }
        refresh()
    }

    @objc private func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func openAbout() {
        NSWorkspace.shared.open(URL(string: "https://github.com/metaskills/coast")!)
    }

    private static func menuBarIcon() -> NSImage? {
        if let image = Bundle.main.image(forResource: "MenuBarIcon") {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }
        return NSImage(systemSymbolName: "computermouse", accessibilityDescription: "Coast")
    }
}
