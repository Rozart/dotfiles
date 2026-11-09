import Foundation

public struct HostSnapshot: Sendable {
    public let host: String?
    public let destinations: [Destination]
    public let warning: String?
}

public struct RexService: Sendable {
    public let executable: String

    public init(executable: String) {
        self.executable = executable
    }

    public func run(_ arguments: [String], host: String? = nil) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["--timeout", "4s", "--autostart=false"] + (host.map { ["-S", $0] } ?? []) + arguments
        var environment = ProcessInfo.processInfo.environment
        for key in ["REX_CLIENT", "REX_SESSION", "REX_BLOCK", "REX_SERVER"] {
            environment.removeValue(forKey: key)
        }
        process.environment = environment
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        process.standardInput = FileHandle.nullDevice
        let errorReader = ErrorReader()
        try process.run()
        let stderrFinished = DispatchGroup()
        stderrFinished.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errorReader.append(errors.fileHandleForReading.readDataToEndOfFile())
            stderrFinished.leave()
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        stderrFinished.wait()
        guard process.terminationStatus == 0 else {
            let message = String(data: errorReader.data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw PickerError.message(message.isEmpty ? "Rex exited with status \(process.terminationStatus)." : message)
        }
        return data
    }

    public func localClient() throws -> RexClient {
        try RexJSON.decode(ClientList.self, from: run(["client", "ls", "--json"])).app()
    }

    public func hosts() throws -> [String] {
        try RexJSON.decode(HostList.self, from: run(["hosts", "--json"])).uniqueLabels
    }

    public func snapshot(host: String?, localLabel: String) -> HostSnapshot {
        let hostLabel = host ?? localLabel
        do {
            let clients = try RexJSON.decode(ClientList.self, from: run(["client", "ls", "--json"], host: host))
            let client = try clients.app(label: localLabel)
            let sessions = try RexJSON.decode(SessionList.self, from: run(["ls", "--json"], host: host)).sessions
            let first = sessions.first { client.sessionIds?.contains($0.sessionId) == true } ?? sessions.first
            var destinations = [Destination(host: host, hostLabel: hostLabel, sessionId: first?.sessionId,
                                            sessionLabel: first?.label, title: hostLabel, kind: .machine,
                                            unavailableReason: first == nil ? "This host has no sessions. Create a session in Rex first." : nil)]
            var warnings: [String] = []
            for session in sessions {
                let label = session.label ?? String(session.sessionId.suffix(8))
                destinations.append(Destination(host: host, hostLabel: hostLabel, sessionId: session.sessionId,
                                                sessionLabel: label, title: label, kind: .session))
                do {
                    let windows = try RexJSON.decode(WindowList.self, from: run(
                        ["window", "ls", "-s", session.sessionId, "--json"], host: host)).windows
                    destinations += windows.map {
                        Destination(host: host, hostLabel: hostLabel, sessionId: session.sessionId,
                                    sessionLabel: label, windowId: $0.windowId,
                                    title: tabTitle($0, sessionId: session.sessionId, host: host), kind: .tab)
                    }
                } catch {
                    warnings.append("\(label): \(error.localizedDescription)")
                }
            }
            return HostSnapshot(host: host, destinations: destinations,
                                warning: warnings.isEmpty ? nil : warnings.joined(separator: "\n"))
        } catch {
            return HostSnapshot(host: host, destinations: [
                Destination(host: host, hostLabel: hostLabel, sessionId: nil, sessionLabel: nil,
                            title: hostLabel, kind: .machine, unavailableReason: error.localizedDescription)
            ], warning: "\(hostLabel): \(error.localizedDescription)")
        }
    }

    private func tabTitle(_ window: RexWindow, sessionId: String, host: String?) -> String {
        guard !window.hasCustomLabel, let blockId = window.focusedBlockId else {
            return window.displayTitle(terminalTitle: nil)
        }
        let title = try? RexJSON.decode(TerminalTitle.self, from: run(
            ["block", "call", "-s", sessionId, "-b", blockId, "title"], host: host))
        return window.displayTitle(terminalTitle: title?.title)
    }

    public func activate(_ destination: Destination, localLabel: String) throws {
        if let reason = destination.unavailableReason { throw PickerError.message(reason) }
        guard let sessionId = destination.sessionId else { throw PickerError.message("No session is available on this host.") }
        let clients = try RexJSON.decode(ClientList.self, from: run(["client", "ls", "--json"], host: destination.host))
        let client = try clients.app(label: localLabel)
        var arguments = ["-C", client.clientId, "do", "session.select", "session_id=\(sessionId)", "--json"]
        if let windowId = destination.windowId { arguments.append("window_id=\(windowId)") }
        _ = try run(arguments, host: destination.host)
    }
}

private final class ErrorReader: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(data)
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
