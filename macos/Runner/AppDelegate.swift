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
        
        // NSPanel 생성 (borderless 팝업 스타일)
        let contentRect = NSRect(x: 0, y: 0, width: 280, height: 400)
        panel = PopoverPanel(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isMovableByWindowBackground = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        // NSVisualEffectView (.menu 스타일, 둥근 모서리)
        let visualEffect = NSVisualEffectView(frame: contentRect)
        visualEffect.material = .menu
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 10
        visualEffect.layer?.masksToBounds = true
        visualEffect.alphaValue = 0.95
        visualEffect.autoresizingMask = [.width, .height]

        // Flutter 뷰를 VisualEffect 위에 배치
        let flutterView = flutterViewController.view
        flutterView.frame = visualEffect.bounds
        flutterView.autoresizingMask = [.width, .height]
        visualEffect.addSubview(flutterView)

        panel.contentView = visualEffect

        // Flutter 렌더링 표면 투명 처리
        DispatchQueue.main.async {
            self.makeFlutterViewTransparent(flutterView)
        }
        
        statusBarController = StatusBarController(panel)
        
        window.close()
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func makeFlutterViewTransparent(_ view: NSView) {
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.layer?.backgroundColor = CGColor.clear
        for subview in view.subviews {
            subview.wantsLayer = true
            subview.layer?.isOpaque = false
            subview.layer?.backgroundColor = CGColor.clear
            if let metalLayer = subview.layer as? CAMetalLayer {
                metalLayer.isOpaque = false
                metalLayer.backgroundColor = CGColor.clear
            }
            makeFlutterViewTransparent(subview)
        }
    }

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
