import Foundation

public struct SessionList: Decodable, Sendable {
    public let sessions: [RexSession]
}

public struct RexSession: Decodable, Sendable {
    public let sessionId: String
    public let label: String?
}

public struct WindowList: Decodable, Sendable {
    public let windows: [RexWindow]
}

public struct RexWindow: Decodable, Sendable {
    public let windowId: String
    public let label: String?
    public let focusedBlockId: String?

    public var hasCustomLabel: Bool {
        guard let label, !label.isEmpty else { return false }
        return label != "Window " + windowId.suffix(8)
    }

    public func displayTitle(terminalTitle: String?) -> String {
        if hasCustomLabel, let label { return label }
        let title = terminalTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? label ?? String(windowId.suffix(8)) : title
    }
}

public struct TerminalTitle: Decodable, Sendable {
    public let title: String
}

public struct ClientList: Decodable, Sendable {
    public let clients: [RexClient]

    public func app(label: String? = nil) throws -> RexClient {
        let matches = clients.filter {
            $0.info?.kind == "app" && $0.info?.platform == "macos"
                && $0.connectionState != "lost" && (label == nil || $0.info?.label == label)
        }
        guard matches.count == 1, let client = matches.first else {
            throw PickerError.message(label.map {
                "Expected one Rex client named \($0); found \(matches.count). Open this host in Rex first."
            } ?? "Expected one local macOS Rex client; found \(matches.count).")
        }
        return client
    }
}

public struct RexClient: Decodable, Sendable {
    public struct Info: Decodable, Sendable {
        public let kind: String?
        public let platform: String?
        public let label: String?
    }
    public let clientId: String
    public let info: Info?
    public let connectionState: String?
    public let sessionIds: [String]?
}

public struct HostList: Decodable, Sendable {
    public struct Entry: Decodable, Sendable {
        public struct Host: Decodable, Sendable {
            public let label: String?
            public let endpoints: [String]?
        }
        public let host: Host
    }
    public let hosts: [Entry]

    public var uniqueLabels: [String] {
        var seen = Set<String>()
        var labels: [String] = []
        for entry in hosts {
            guard let label = entry.host.label, !label.isEmpty else { continue }
            let key = entry.host.endpoints?.first.map(Self.normalizedEndpoint) ?? label
            if seen.insert(key).inserted { labels.append(label) }
        }
        return labels
    }

    static func normalizedEndpoint(_ endpoint: String) -> String {
        if let url = URL(string: endpoint), url.scheme == "unix" {
            return url.path.removingPercentEncoding ?? url.path
        }
        return endpoint
    }
}

public enum PickerError: LocalizedError, Sendable {
    case message(String)

    public var errorDescription: String? {
        switch self {
        case .message(let message): message
        }
    }
}

public enum RexJSON {
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: data)
    }
}
