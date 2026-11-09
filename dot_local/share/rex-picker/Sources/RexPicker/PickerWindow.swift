import AppKit
import PickerCore

@MainActor
enum PickerStyle {
    static let panelSize = NSSize(width: 680, height: 480)
    static let minimumSize = NSSize(width: 480, height: 300)
    static let padding: CGFloat = 16
    static let rowHeight: CGFloat = 50
    static let lineSpacing: CGFloat = 2
    static let numberWidth: CGFloat = 38
    static let numberFont = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
    static let titleFont = NSFont.systemFont(ofSize: 14, weight: .medium)
    static let contextFont = NSFont.systemFont(ofSize: 11)
    static let footerFont = NSFont.systemFont(ofSize: 11)
    static let searchSize: CGFloat = 20
    static var theme: RexTheme?
    static var background: NSColor { theme?.palette.background.native ?? .windowBackgroundColor }
    static var foreground: NSColor { theme?.palette.foreground.native ?? .labelColor }
    static var secondary: NSColor {
        theme == nil ? .secondaryLabelColor : foreground.blended(withFraction: 0.25, of: background) ?? foreground
    }
    static var selectionBackground: NSColor { theme?.palette.selectionBackground.native ?? .selectedContentBackgroundColor }

    static var selectionForeground: NSColor {
        if let color = theme?.palette.selectionForeground { return color.native }
        guard let color = selectionBackground.usingColorSpace(.deviceRGB) else {
            return .alternateSelectedControlTextColor
        }
        let components = [color.redComponent, color.greenComponent, color.blueComponent].map {
            $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4)
        }
        let luminance = components[0] * 0.2126 + components[1] * 0.7152 + components[2] * 0.0722
        return luminance > 0.179 ? .black : .white
    }
}

final class PickerWindow: NSPanel {
    let search = NSSearchField()
    let table = NSTableView()
    let footer = NSTextField(labelWithString: "")
    let progress = NSProgressIndicator()

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    init() {
        super.init(contentRect: NSRect(origin: .zero, size: PickerStyle.panelSize),
                            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                            backing: .buffered, defer: false)
        title = "Rex Picker"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isFloatingPanel = true
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        minSize = PickerStyle.minimumSize
        backgroundColor = PickerStyle.background

        let content = PickerBackground()
        content.wantsLayer = true
        contentView = content
        search.placeholderString = "Search machines, sessions, tabs…"
        search.font = .systemFont(ofSize: PickerStyle.searchSize)
        search.sendsSearchStringImmediately = true
        search.sendsWholeSearchString = false
        search.setAccessibilityLabel("Search machines, sessions, and tabs")

        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("destination")))
        table.headerView = nil
        table.rowHeight = PickerStyle.rowHeight
        table.style = .plain
        table.allowsEmptySelection = false
        table.setAccessibilityLabel("Rex destinations")
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false

        footer.stringValue = "Loading destinations…"
        footer.font = PickerStyle.footerFont
        footer.textColor = PickerStyle.secondary
        footer.maximumNumberOfLines = 2
        footer.lineBreakMode = .byTruncatingTail
        footer.setAccessibilityLabel("Picker status")
        progress.style = .spinning
        progress.controlSize = .small
        progress.isDisplayedWhenStopped = false

        for view in [search, scroll, footer, progress] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        let pad = PickerStyle.padding
        NSLayoutConstraint.activate([
            search.topAnchor.constraint(equalTo: content.safeAreaLayoutGuide.topAnchor, constant: pad),
            search.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: pad),
            search.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -pad),
            scroll.topAnchor.constraint(equalTo: search.bottomAnchor, constant: pad),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -pad),
            footer.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: pad),
            footer.trailingAnchor.constraint(equalTo: progress.leadingAnchor, constant: -pad),
            footer.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -pad),
            progress.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -pad),
            progress.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            progress.widthAnchor.constraint(equalToConstant: PickerStyle.padding),
            progress.heightAnchor.constraint(equalToConstant: PickerStyle.padding)
        ])
    }

    func applyTheme() {
        backgroundColor = PickerStyle.background
        table.backgroundColor = PickerStyle.background
        search.isBezeled = true
        search.drawsBackground = true
        search.backgroundColor = PickerStyle.background
        search.textColor = PickerStyle.foreground
        search.focusRingType = .none
        search.placeholderAttributedString = NSAttributedString(
            string: search.placeholderString ?? "",
            attributes: [.foregroundColor: PickerStyle.secondary, .font: NSFont.systemFont(ofSize: PickerStyle.searchSize)])
        if let editor = search.currentEditor() as? NSTextView {
            editor.backgroundColor = PickerStyle.background
            editor.textColor = PickerStyle.foreground
            editor.insertionPointColor = PickerStyle.foreground
            editor.selectedTextAttributes = [.backgroundColor: PickerStyle.selectionBackground,
                                             .foregroundColor: PickerStyle.selectionForeground]
        }
        footer.textColor = PickerStyle.secondary
        contentView?.needsDisplay = true
        table.reloadData()
    }

    required init?(coder: NSCoder) { nil }
}

private final class PickerBackground: NSView {
    override var wantsUpdateLayer: Bool { true }

    override func updateLayer() {
        layer?.backgroundColor = PickerStyle.background.cgColor
    }
}
