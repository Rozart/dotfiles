import Foundation

public struct Destination: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable {
        case machine = "Machine"
        case session = "Session"
        case tab = "Tab"
    }

    public let host: String?
    public let hostLabel: String
    public let sessionId: String?
    public let sessionLabel: String?
    public let windowId: String?
    public let title: String
    public let kind: Kind
    public let unavailableReason: String?

    public var id: String {
        [host ?? "", kind.rawValue, sessionId ?? "", windowId ?? ""].joined(separator: "|")
    }

    public var context: String {
        [kind.rawValue, hostLabel, kind == .tab ? sessionLabel : nil]
            .compactMap { $0 }.joined(separator: " · ")
    }

    public var searchText: String {
        [title, hostLabel, sessionLabel ?? "", kind.rawValue].joined(separator: " ")
    }

    public init(host: String?, hostLabel: String, sessionId: String?, sessionLabel: String?,
                windowId: String? = nil, title: String, kind: Kind, unavailableReason: String? = nil) {
        self.host = host
        self.hostLabel = hostLabel
        self.sessionId = sessionId
        self.sessionLabel = sessionLabel
        self.windowId = windowId
        self.title = title
        self.kind = kind
        self.unavailableReason = unavailableReason
    }
}

public enum FuzzySearch {
    public static func score(_ query: String, in text: String) -> Int? {
        let tokens = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .split(whereSeparator: { $0.isWhitespace })
        let characters = Array(text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current))
        var total = 0
        for token in tokens {
            let needle = Array(token)
            var previous = Array(repeating: Int.min / 4, count: characters.count)
            for (offset, character) in needle.enumerated() {
                var current = Array(repeating: Int.min / 4, count: characters.count)
                var bestEarlier = Int.min / 4
                for index in characters.indices {
                    if index > 0 {
                        bestEarlier = max(bestEarlier, previous[index - 1] + index - 1)
                    }
                    guard characters[index] == character else { continue }
                    let boundary = index == 0 || !characters[index - 1].isLetter && !characters[index - 1].isNumber
                    let bonus = 10 + (boundary ? 12 : 0)
                    if offset == 0 {
                        current[index] = bonus - index
                    } else {
                        let consecutive = index > 0 ? previous[index - 1] + 18 : Int.min / 4
                        current[index] = max(consecutive, bestEarlier - index) + bonus
                    }
                }
                previous = current
            }
            guard let best = previous.max(), best > Int.min / 8 else { return nil }
            total += best
        }
        return total
    }

    public static func ranked(_ destinations: [Destination], query: String) -> [Destination] {
        destinations.compactMap { destination -> (Destination, Int)? in
            guard let contextScore = score(query, in: destination.searchText) else { return nil }
            let titleBonus = score(query, in: destination.title).map { max(0, $0) + 30 } ?? 0
            return (destination, contextScore + (query.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : titleBonus))
        }.sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            if ($0.0.unavailableReason == nil) != ($1.0.unavailableReason == nil) {
                return $0.0.unavailableReason == nil
            }
            return $0.0.searchText.localizedStandardCompare($1.0.searchText) == .orderedAscending
        }.map { $0.0 }
    }
}
