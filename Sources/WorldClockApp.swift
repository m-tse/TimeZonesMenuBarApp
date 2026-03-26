import SwiftUI
import AppKit

@main
struct WorldClockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let store = TimezoneStore()
    private var isClosing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = makeGlobeAltIcon()
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 500)
        popover.behavior = .transient
        popover.animates = false
        popover.delegate = self

        let contentView = ContentView()
            .environmentObject(store)
            .background(VisualEffectBackground())

        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            fadeClosePopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        if isClosing { return true }
        fadeClosePopover()
        return false
    }

    private func fadeClosePopover() {
        guard !isClosing, let window = popover.contentViewController?.view.window else { return }
        isClosing = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            window.animator().alphaValue = 0
        }, completionHandler: {
            self.popover.performClose(nil)
            window.alphaValue = 1
            self.isClosing = false
        })
    }

    private func makeGlobeAltIcon() -> NSImage {
        let size: CGFloat = 18
        let s = size / 24.0

        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            NSColor.black.setStroke()

            func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
                NSPoint(x: x * s, y: y * s)
            }

            let circle = NSBezierPath(ovalIn: NSRect(x: 3 * s, y: 3 * s, width: 18 * s, height: 18 * s))
            circle.lineWidth = 1.5 * s
            circle.lineCapStyle = .round
            circle.lineJoinStyle = .round
            circle.stroke()

            let meridian = NSBezierPath(ovalIn: NSRect(x: 7.5 * s, y: 3 * s, width: 9 * s, height: 18 * s))
            meridian.lineWidth = 1.5 * s
            meridian.lineCapStyle = .round
            meridian.lineJoinStyle = .round
            meridian.stroke()

            let upper = NSBezierPath()
            upper.move(to: pt(4.157, 7.582))
            upper.curve(to: pt(19.843, 7.582),
                        controlPoint1: pt(6.26, 9.4),
                        controlPoint2: pt(9.0, 10.5))
            upper.lineWidth = 1.5 * s
            upper.lineCapStyle = .round
            upper.lineJoinStyle = .round
            upper.stroke()

            let lower = NSBezierPath()
            lower.move(to: pt(3.284, 14.253))
            lower.curve(to: pt(20.716, 14.253),
                        controlPoint1: pt(5.87, 15.685),
                        controlPoint2: pt(8.84, 16.5))
            lower.lineWidth = 1.5 * s
            lower.lineCapStyle = .round
            lower.lineJoinStyle = .round
            lower.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }
}
