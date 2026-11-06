import AppKit
import PreviewAICore
import SwiftUI

/// A floating, non-activating panel: it takes keyboard focus (Esc, shortcuts) without making
/// PreviewAI the active app, so Finder keeps its selection and stays frontmost.
final class SummaryPanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}

@MainActor
final class SummaryPanelController {
    let model: PanelModel
    private var panel: SummaryPanel?
    private static let defaultSize = NSSize(width: 560, height: 460)

    init(model: PanelModel) {
        self.model = model
        model.onClose = { [weak self] in self?.close() }
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        position(panel)
        panel.makeKeyAndOrderFront(nil)
    }

    /// Closing tears the panel down completely, so an idle app holds no view hierarchy or
    /// summary text. Re-creating it on the next show takes a few milliseconds.
    func close() {
        model.session.close()
        guard let panel else { return }
        self.panel = nil
        panel.orderOut(nil)
        panel.contentView = nil
    }

    private func makePanel() -> SummaryPanel {
        let panel = SummaryPanel(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.borderless, .nonactivatingPanel, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.minSize = NSSize(width: 420, height: 300)
        panel.animationBehavior = .utilityWindow
        panel.onCancel = { [weak self] in self?.close() }

        let hosting = NSHostingView(rootView: SummaryView(model: model))
        hosting.sizingOptions = []
        panel.contentView = Self.backgroundView(containing: hosting)
        return panel
    }

    /// Liquid Glass on macOS 26, a vibrant popover material before that.
    private static func backgroundView(containing content: NSView) -> NSView {
        let radius: CGFloat = 18
        let frame = NSRect(origin: .zero, size: defaultSize)
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView(frame: frame)
            glass.cornerRadius = radius
            // Don't rely on the glass view to size its content.
            content.frame = glass.bounds
            content.autoresizingMask = [.width, .height]
            glass.contentView = content
            return glass
        }
        let effect = NSVisualEffectView(frame: frame)
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        // A layer corner radius doesn't clip a behind-window blur; a mask image does.
        effect.maskImage = roundedMask(radius: radius)
        content.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            content.topAnchor.constraint(equalTo: effect.topAnchor),
            content.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        return effect
    }

    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    /// Centered (slightly high, like Quick Look) on the screen that has the mouse.
    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + visible.height * 0.05
        )
        panel.setFrameOrigin(origin)
    }
}
