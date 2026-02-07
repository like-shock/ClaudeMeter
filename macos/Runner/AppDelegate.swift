import Cocoa
import FlutterMacOS

// MARK: - StatusBarController
class StatusBarController {
    private var statusBar: NSStatusBar
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    
    init(_ popover: NSPopover) {
        self.popover = popover
        statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem.button {
            // Use template image for menu bar
            if let image = NSImage(named: "TrayIcon") {
                image.isTemplate = true
                button.image = image
            } else {
                // Fallback: use text
                button.title = "CM"
            }
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            hidePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    func showPopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func hidePopover(_ sender: AnyObject?) {
        popover.performClose(sender)
    }
}

// MARK: - AppDelegate
@main
class AppDelegate: FlutterAppDelegate {
    var statusBarController: StatusBarController?
    var popover = NSPopover()
    
    override init() {
        super.init()
        popover.behavior = .transient
    }
    
    override func applicationDidFinishLaunching(_ notification: Notification) {
        guard let window = mainFlutterWindow,
              let flutterViewController = window.contentViewController as? FlutterViewController else {
            return
        }
        
        RegisterGeneratedPlugins(registry: flutterViewController)
        
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.contentViewController = flutterViewController
        
        statusBarController = StatusBarController(popover)
        
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
