import Cocoa
import FlutterMacOS

// MARK: - PopoverPanel
class PopoverPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - StatusBarController
class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var panel: PopoverPanel
    private var eventMonitor: Any?
    
    init(_ panel: PopoverPanel) {
        self.panel = panel
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            if let image = NSImage(named: "TrayIcon") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "CM"
            }
            button.action = #selector(togglePanel(_:))
            button.target = self
        }
    }
    
    @objc func togglePanel(_ sender: AnyObject?) {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }
    
    func showPanel() {
        guard let button = statusItem.button else { return }
        
        // 버튼 위치 계산
        let buttonRect = button.window?.convertToScreen(button.convert(button.bounds, to: nil)) ?? .zero
        let panelSize = panel.frame.size
        
        // 패널 위치: 버튼 아래 중앙
        let x = buttonRect.midX - panelSize.width / 2
        let y = buttonRect.minY - panelSize.height - 5
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // 외부 클릭 시 닫기
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self = self, self.panel.isVisible {
                // 패널 외부 클릭인지 확인
                let clickLocation = event.locationInWindow
                if !self.panel.frame.contains(NSEvent.mouseLocation) {
                    self.hidePanel()
                }
            }
        }
    }
    
    func hidePanel() {
        panel.orderOut(nil)
        
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

// MARK: - AppDelegate
@main
class AppDelegate: FlutterAppDelegate {
    var statusBarController: StatusBarController?
    var panel: PopoverPanel!
    
    override func applicationDidFinishLaunching(_ notification: Notification) {
        // 중복 실행 방지
        let bundleId = Bundle.main.bundleIdentifier ?? "com.example.claudeMonitorFlutter"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        if runningApps.count > 1 {
            NSApp.terminate(nil)
            return
        }
        
        guard let window = mainFlutterWindow,
              let flutterViewController = window.contentViewController as? FlutterViewController else {
            return
        }
        
        RegisterGeneratedPlugins(registry: flutterViewController)
        
        // NSPanel 생성 (팝오버 스타일)
        let contentRect = NSRect(x: 0, y: 0, width: 320, height: 400)
        panel = PopoverPanel(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentViewController = flutterViewController
        
        // 모서리 둥글게
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 10
        panel.contentView?.layer?.masksToBounds = true
        
        statusBarController = StatusBarController(panel)
        
        window.close()
        NSApp.setActivationPolicy(.accessory)
    }
    
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
