import AppKit
import SwiftUI
import ServiceManagement

final class PocketModel: ObservableObject {
    @Published var listeners: [Listener] = []
    @Published var query = ""
    @Published var scanning = false
    @Published var error: String?
    @Published var updated: Date?
    @Published var login = SMAppService.mainApp.status == .enabled
    @Published var selected: Listener?
    @Published var stopping = false
    @Published var showSystem = false
    var changed: (() -> Void)?
    var filtered: [Listener] {
        listeners.filter {
            (showSystem || !Listener.protected.contains($0.process.lowercased())) &&
            (query.isEmpty || "\($0.port) \($0.process) \($0.project) \($0.pid) \($0.directory)".localizedCaseInsensitiveContains(query))
        }
    }
    func refresh() {
        guard !scanning else { return }
        scanning = true
        DispatchQueue.global(qos: .utility).async {
            let result = Result { try PortDiscovery.scan() }
            DispatchQueue.main.async {
                self.scanning = false
                switch result {
                case .success(let items): self.listeners = items; self.updated = Date(); self.error = nil
                case .failure(let error): self.error = error.localizedDescription
                }
                self.changed?()
            }
        }
    }
    func stopSelected() {
        guard let item = selected, !stopping else { return }
        selected = nil; stopping = true
        DispatchQueue.global(qos: .utility).async {
            let result = Result { try PortDiscovery.stop(item) }
            DispatchQueue.main.async {
                self.stopping = false
                if case .failure(let error) = result { self.error = error.localizedDescription }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.refresh() }
            }
        }
    }
    func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
            login = SMAppService.mainApp.status == .enabled
        } catch { self.error = error.localizedDescription }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = PocketModel()
    let popover = NSPopover()
    var status: NSStatusItem!
    var timer: Timer?
    func applicationDidFinishLaunching(_ notification: Notification) {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if UserDefaults.standard.object(forKey: "NSStatusItem Preferred Position PortPocket") == nil {
            UserDefaults.standard.set(280, forKey: "NSStatusItem Preferred Position PortPocket")
        }
        status.autosaveName = "PortPocket"
        status.isVisible = true
        status.button?.image = NSImage(systemSymbolName: "externaldrive.connected.to.line.below", accessibilityDescription: "Port Pocket")
        status.button?.image?.isTemplate = true
        status.button?.target = self
        status.button?.action = #selector(toggle)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: PocketPanel(model: model))
        model.changed = { [weak self] in
            guard let self else { return }
            self.status.button?.toolTip = "Port Pocket · \(self.model.listeners.count) listening ports"
            if self.popover.isShown {
                DispatchQueue.main.async { self.positionPopover() }
            }
        }
        model.refresh()
        timer = Timer(timeInterval: 8, repeats: true) { [weak self] _ in
            if self?.popover.isShown == true { self?.model.refresh() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        if CommandLine.arguments.contains("--show-panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.toggle() }
        }
    }
    @objc func toggle() {
        if popover.isShown { popover.performClose(nil) }
        else if let button = status.button {
            model.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            DispatchQueue.main.async { self.positionPopover() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.positionPopover() }
        }
    }
    private func positionPopover() {
        guard popover.isShown, let window = popover.contentViewController?.view.window,
              let button = status.button, let barWindow = button.window,
              let screen = barWindow.screen else { return }
        let anchor = barWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let frame = window.frame
        let x = min(max(anchor.midX - frame.width / 2, screen.visibleFrame.minX + 8),
                    screen.visibleFrame.maxX - frame.width - 8)
        let top = min(anchor.minY, screen.visibleFrame.maxY) - 8
        window.setFrameOrigin(NSPoint(x: x, y: top - frame.height))
    }
}

if CommandLine.arguments.contains("--integration-test") {
    let server = Process()
    server.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    server.arguments = ["-m", "http.server", "0", "--bind", "127.0.0.1"]
    server.standardOutput = FileHandle.nullDevice
    server.standardError = FileHandle.nullDevice
    try server.run()
    defer { if server.isRunning { server.terminate() } }
    var listener: Listener?
    for _ in 0..<30 {
        listener = try PortDiscovery.scan().first { $0.pid == server.processIdentifier }
        if listener != nil { break }
        Thread.sleep(forTimeInterval: 0.1)
    }
    guard let listener else { fatalError("Test server was not discovered") }
    precondition(listener.canStop && !listener.executable.isEmpty && listener.port > 0)
    try PortDiscovery.stop(listener)
    for _ in 0..<30 {
        if !server.isRunning { break }
        Thread.sleep(forTimeInterval: 0.1)
    }
    precondition(!server.isRunning, "Graceful stop did not terminate the test server")
    let after = try PortDiscovery.scan()
    precondition(!after.contains { $0.pid == listener.pid })
    print("PASS: live test-server discovery, process identity, graceful stop, port release")
} else if CommandLine.arguments.contains("--self-test") {
    testPortParser()
} else if CommandLine.arguments.contains("--scan") {
    for item in try PortDiscovery.scan() { print("\(item.port)\t\(item.pid)\t\(item.process)\t\(item.project)") }
} else if let index = CommandLine.arguments.firstIndex(of: "--capture-preview"), CommandLine.arguments.count > index + 1 {
    _ = NSApplication.shared
    let directory = URL(fileURLWithPath: CommandLine.arguments[index + 1])
    for dark in [false, true] {
        let model = PocketModel()
        model.updated = Date()
        model.listeners = [
            Listener(pid: 1248, process: "node", uid: getuid(), port: 3000, addresses: ["*"], directory: "/Projects/studio-web"),
            Listener(pid: 2084, process: "node", uid: getuid(), port: 5173, addresses: ["127.0.0.1"], directory: "/Projects/pocket-site"),
            Listener(pid: 3192, process: "Python", uid: getuid(), port: 8000, addresses: ["127.0.0.1"], directory: "/Projects/ideas-api")]
        let view = NSHostingView(rootView: PocketPanel(model: model).environment(\.colorScheme, dark ? .dark : .light))
        view.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        view.frame = NSRect(origin: .zero, size: view.fittingSize)
        view.layoutSubtreeIfNeeded()
        let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
        view.cacheDisplay(in: view.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(dark ? "dark.png" : "light.png"))
    }
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
