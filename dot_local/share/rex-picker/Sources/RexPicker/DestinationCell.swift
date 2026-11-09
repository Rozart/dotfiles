import AppKit
import PickerCore

final class DestinationRow: NSTableRowView {
    override var isSelected: Bool {
        didSet {
            for cell in subviews.compactMap({ $0 as? DestinationCell }) {
                cell.setSelected(isSelected)
            }
        }
    }

    override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)
        (subview as? DestinationCell)?.setSelected(isSelected)
    }

    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        PickerStyle.selectionBackground.setFill()
        bounds.fill()
    }
}

final class DestinationCell: NSTableCellView {
    private let title: NSTextField
    private let context: NSTextField
    private let unavailable: Bool
    private let badge: NSTextField
    private var selected = false

    init(destination: Destination, number: Int? = nil) {
        badge = NSTextField(labelWithString: number.map(String.init) ?? "")
        title = NSTextField(labelWithString: destination.title)
        context = NSTextField(labelWithString: destination.context +
            (destination.unavailableReason == nil ? "" : " · Unavailable"))
        unavailable = destination.unavailableReason != nil
        super.init(frame: .zero)
        title.font = PickerStyle.titleFont
        context.font = PickerStyle.contextFont
        title.lineBreakMode = .byTruncatingTail
        context.lineBreakMode = .byTruncatingTail
        let stack = NSStackView(views: [title, context])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = PickerStyle.lineSpacing
        badge.font = PickerStyle.numberFont
        badge.alignment = .right
        let row = NSStackView(views: number == nil ? [stack] : [badge, stack])
        row.orientation = .horizontal
        row.spacing = PickerStyle.padding
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        if number != nil { badge.widthAnchor.constraint(equalToConstant: PickerStyle.numberWidth).isActive = true }
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: PickerStyle.padding),
            row.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -PickerStyle.padding),
            row.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        textField = title
        toolTip = destination.unavailableReason ?? destination.context
        setAccessibilityLabel((number.map { "Tab \($0), " } ?? "") + destination.title + ", " + destination.context)
        updateColors()
    }

    required init?(coder: NSCoder) { nil }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet { updateColors() }
    }

    func setSelected(_ value: Bool) {
        selected = value
        updateColors()
    }

    private func updateColors() {
        if selected {
            title.textColor = PickerStyle.selectionForeground
            context.textColor = PickerStyle.selectionForeground
            badge.textColor = PickerStyle.selectionForeground
        } else {
            title.textColor = unavailable ? PickerStyle.secondary : PickerStyle.foreground
            context.textColor = PickerStyle.secondary
            badge.textColor = PickerStyle.secondary
        }
    }
}
