import AppKit
import CoreFoundation
import PickerCore

@MainActor
enum RexAppearance {
    static func apply() {
        let domain = "com.superlogical.rex" as CFString
        CFPreferencesAppSynchronize(domain)
        func preference(_ key: String) -> Any? {
            CFPreferencesCopyAppValue(key as CFString, domain)
        }
        let override = ProcessInfo.processInfo.environment["REX_PICKER_APPEARANCE"]
        NSApp.appearance = nil
        let followsDarkSystem = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let configured = override ?? preference("Workspace.appearance") as? String ?? "system"
        let mode = configured == "dark" || configured != "light" && followsDarkSystem ? "dark" : "light"
        NSApp.appearance = NSAppearance(named: mode == "dark" ? .darkAqua : .aqua)
        PickerStyle.theme = nil
        if let id = preference("Workspace.\(mode)ThemeID") as? String,
           let data = preference("Workspace.customThemes") as? Data {
            PickerStyle.theme = try? RexTheme.selected(from: data, id: id, appearance: mode)
        }
    }
}

extension RexTheme.Color {
    var native: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}
