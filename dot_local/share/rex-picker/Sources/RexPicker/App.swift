import AppKit
import PickerCore

private enum PickerMode {
    case search
    case numberedTabs
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate,
                         NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private var statusItem: NSStatusItem!
    private var panel: PickerWindow!
    private var search: NSSearchField { panel.search }
    private var table: NSTableView { panel.table }
    private var footer: NSTextField { panel.footer }
    private var progress: NSProgressIndicator { panel.progress }
    private var destinations: [Destination] = []
    private var matches: [Destination] = []
    private var localLabel = ""
    private var service: RexService?
    private var refreshTask: Task<Void, Never>?
    private var refreshId = UUID()
    private var warnings: [String] = []
    private var loading = false
    private var activating = false
    private var mode: PickerMode = .search
    private var numberedTabs = NumberedTabs(destinations: [])

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        createMenu()
        createPanel()
        if let output = ProcessInfo.processInfo.environment["REX_PICKER_RENDER"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [self] in
                if matches.count > 1 {
                    let editor = NSTextView()
                    table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                    _ = control(search, textView: editor, doCommandBy: #selector(NSResponder.moveDown(_:)))
                    precondition(table.selectedRow == 1)
                    _ = control(search, textView: editor, doCommandBy: #selector(NSResponder.moveUp(_:)))
                    precondition(table.selectedRow == 0)
                }
                search.stringValue = ProcessInfo.processInfo.environment["REX_PICKER_QUERY"] ?? ""
                filter(resetSelection: true)
                panel.contentView?.layoutSubtreeIfNeeded()
                if let view = panel.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: bitmap)
                    try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: output))
                }
                print("visible=\(panel.isVisible) key=\(panel.isKeyWindow) rows=\(matches.count) selected=\(table.selectedRow) theme=\(PickerStyle.theme?.name ?? "system") mode=\(mode) frame=\(panel.frame)")
                NSApp.terminate(nil)
            }
        }
        do {
            service = RexService(executable: try findRex())
            if ProcessInfo.processInfo.environment["REX_PICKER_MODE"] == "tabs" || CommandLine.arguments.contains("--tabs") {
                mode = .numberedTabs
            }
            DispatchQueue.main.async { [self] in present(mode: mode) }
        } catch {
            present(mode: mode)
            showError(error.localizedDescription)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPicker(nil)
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.last, url.scheme == "rex-picker", ["tabs", "search"].contains(url.host) else { return }
        let requestedMode: PickerMode = url.host == "tabs" ? .numberedTabs : .search
        if panel == nil { mode = requestedMode } else { present(mode: requestedMode) }
    }

    private func findRex() throws -> String {
        if let override = ProcessInfo.processInfo.environment["REX_PICKER_CLI"],
           FileManager.default.isExecutableFile(atPath: override) {
            return override
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            home + "/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex",
            "/opt/homebrew/bin/rex", "/usr/local/bin/rex", home + "/.local/bin/rex"
        ]
        guard let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw PickerError.message("Rex CLI not found. Install Rex or launch with REX_PICKER_CLI set to its executable.")
        }
        return path
    }

    private func createMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "Rex Picker")
        let menu = NSMenu()
        let open = menu.addItem(withTitle: "Open Rex Picker", action: #selector(showPicker(_:)), keyEquivalent: "")
        open.target = self
        let tabs = menu.addItem(withTitle: "Go to Tab Number", action: #selector(showNumberedTabs(_:)), keyEquivalent: "")
        tabs.target = self
        let refresh = menu.addItem(withTitle: "Refresh Destinations", action: #selector(refreshFromMenu(_:)), keyEquivalent: "")
        refresh.target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit Rex Picker", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        statusItem.menu = menu
    }

    private func createPanel() {
        panel = PickerWindow()
        panel.delegate = self
        search.delegate = self
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(activateSelection(_:))
    }

    @objc private func showPicker(_ sender: Any?) {
        present(mode: .search)
    }

    @objc private func showNumberedTabs(_ sender: Any?) {
        present(mode: .numberedTabs)
    }

    private func present(mode requestedMode: PickerMode) {
        let changedMode = mode != requestedMode
        mode = requestedMode
        RexAppearance.apply()
        search.placeholderString = mode == .numberedTabs ? "Go to tab — press 1–9, or search…" : "Search machines, sessions, tabs…"
        panel.title = mode == .numberedTabs ? "Rex — Go to Tab" : "Rex Picker"
        if changedMode { search.stringValue = "" }
        panel.applyTheme()
        if !panel.isVisible {
            let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main
            if let frame = screen?.visibleFrame {
                panel.setFrameOrigin(NSPoint(x: frame.midX - panel.frame.width / 2,
                                              y: frame.maxY - panel.frame.height - frame.height * 0.12))
            }
            search.stringValue = ""
            filter()
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(search)
        panel.applyTheme()
        filter()
        if !loading { refresh() }
    }

    @objc private func refreshFromMenu(_ sender: Any?) {
        present(mode: mode)
        if !loading { refresh() }
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func refresh() {
        guard let service else { return }
        refreshTask?.cancel()
        let generation = UUID()
        refreshId = generation
        warnings = []
        loading = true
        progress.startAnimation(nil)
        filter()
        refreshTask = Task {
            do {
                let bootstrap = try await Task.detached {
                    let client = try service.localClient()
                    guard let label = client.info?.label, !label.isEmpty else {
                        throw PickerError.message("The local Rex client has no label. Give this Mac a unique Rex client label first.")
                    }
                    return (label, try service.hosts())
                }.value
                guard refreshId == generation, !Task.isCancelled else { return }
                localLabel = bootstrap.0
                let hosts = [nil] + bootstrap.1.map(Optional.some)
                var snapshots = Array<HostSnapshot?>(repeating: nil, count: hosts.count)
                await withTaskGroup(of: (Int, HostSnapshot).self) { group in
                    for (index, host) in hosts.enumerated() {
                        group.addTask {
                            (index, service.snapshot(host: host, localLabel: bootstrap.0))
                        }
                    }
                    for await (index, snapshot) in group {
                        guard refreshId == generation, !Task.isCancelled else { continue }
                        snapshots[index] = snapshot
                        destinations = snapshots.compactMap { $0 }.flatMap(\.destinations)
                        warnings = snapshots.compactMap { $0?.warning }
                        if mode == .search { filter() }
                    }
                }
                guard refreshId == generation else { return }
                numberedTabs = NumberedTabs(destinations: destinations)
                loading = false
                progress.stopAnimation(nil)
                filter()
            } catch {
                guard refreshId == generation else { return }
                loading = false
                progress.stopAnimation(nil)
                showError(error.localizedDescription)
            }
        }
    }

    func controlTextDidChange(_ notification: Notification) {
        filter(resetSelection: true)
        if mode == .numberedTabs, !loading, !activating,
           let destination = numberedTabs.immediateSelection(search.stringValue),
           let index = matches.firstIndex(where: { $0.id == destination.id }) {
            table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            activateSelection(nil)
        }
    }

    private func filter(resetSelection: Bool = false) {
        let selectedId = !resetSelection && matches.indices.contains(table.selectedRow) ? matches[table.selectedRow].id : nil
        matches = mode == .numberedTabs
            ? (loading ? [] : numberedTabs.matching(search.stringValue).map(\.destination))
            : FuzzySearch.ranked(destinations, query: search.stringValue)
        table.reloadData()
        if !matches.isEmpty {
            let index = selectedId.flatMap { id in matches.firstIndex { $0.id == id } } ?? 0
            table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }
        updateFooter()
    }

    private func updateFooter() {
        if activating { footer.stringValue = "Switching in Rex…"; return }
        let resultCount = "\(matches.count) \(matches.count == 1 ? "result" : "results")"
        let warningCount = "\(warnings.count) host \(warnings.count == 1 ? "warning" : "warnings")"
        if loading {
            footer.stringValue = mode == .numberedTabs ? "Loading numbered tabs…" : "Refreshing… \(resultCount) · ↑↓ Navigate · ↵ Switch · Esc Close"
        } else if matches.isEmpty {
            footer.stringValue = mode == .numberedTabs ? "No matching tabs. Try a tab name or number."
                : destinations.isEmpty ? "No destinations available. Open Rex and refresh." : "No matches. Try a machine, session, or tab name."
        } else {
            let instructions = mode == .numberedTabs ? "1–9 Switch · ↑↓ Navigate · ↵ Open · Esc Close" : "↑↓ Navigate · ↵ Switch · Esc Close"
            footer.stringValue = "\(resultCount) · \(instructions)" +
                (warnings.isEmpty ? "" : " · \(warningCount)")
        }
        footer.toolTip = warnings.joined(separator: "\n")
    }

    func numberOfRows(in tableView: NSTableView) -> Int { matches.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        DestinationCell(destination: matches[row], number: mode == .numberedTabs ? numberedTabs.number(for: matches[row]) : nil)
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        DestinationRow()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(1)
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(-1)
        case #selector(NSResponder.insertNewline(_:)):
            activateSelection(nil)
        case #selector(NSResponder.cancelOperation(_:)):
            panel.orderOut(nil)
        default:
            return false
        }
        return true
    }

    private func moveSelection(_ offset: Int) {
        guard !matches.isEmpty else { return }
        let index = max(0, min(matches.count - 1, table.selectedRow + offset))
        table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        table.scrollRowToVisible(index)
    }

    @objc private func activateSelection(_ sender: Any?) {
        guard !activating, mode != .numberedTabs || !loading,
              let service, matches.indices.contains(table.selectedRow) else { return }
        let destination = matches[table.selectedRow]
        activating = true
        search.isEnabled = false
        progress.startAnimation(nil)
        updateFooter()
        let label = localLabel
        Task {
            do {
                try await Task.detached { try service.activate(destination, localLabel: label) }.value
                panel.orderOut(nil)
                NSRunningApplication.runningApplications(withBundleIdentifier: "com.superlogical.rex")
                    .first?.activate()
                activating = false
                search.isEnabled = true
                if !loading { progress.stopAnimation(nil) }
            } catch {
                activating = false
                search.isEnabled = true
                if !loading { progress.stopAnimation(nil) }
                showError(error.localizedDescription)
                panel.makeFirstResponder(search)
            }
        }
    }

    private func showError(_ message: String) {
        footer.stringValue = message.replacingOccurrences(of: "\n", with: " ")
        footer.toolTip = message
        NSAccessibility.post(element: footer, notification: .valueChanged)
    }

}

@main
enum RexPickerApp {
    static func main() {
        if CommandLine.arguments.contains("--diagnose") {
            diagnose()
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }

    static func diagnose() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let service = RexService(executable: ProcessInfo.processInfo.environment["REX_PICKER_CLI"] ??
            home + "/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex")
        do {
            let client = try service.localClient()
            guard let label = client.info?.label else { throw PickerError.message("Missing local client label.") }
            for host in [nil] + (try service.hosts()).map(Optional.some) {
                let snapshot = service.snapshot(host: host, localLabel: label)
                for destination in snapshot.destinations {
                    print("\(destination.kind.rawValue)\t\(destination.title)\t\(destination.context)\t\(destination.unavailableReason ?? "ready")")
                }
                if let warning = snapshot.warning { print("WARNING\t\(warning)") }
            }
        } catch {
            FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
            exit(1)
        }
    }
}
