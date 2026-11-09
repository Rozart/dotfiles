import Foundation

public struct NumberedTab: Sendable {
    public let number: Int
    public let destination: Destination
}

public struct NumberedTabs: Sendable {
    public let rows: [NumberedTab]

    public init(destinations: [Destination]) {
        rows = destinations.filter { $0.kind == .tab }.enumerated().map {
            NumberedTab(number: $0.offset + 1, destination: $0.element)
        }
    }

    public func matching(_ query: String) -> [NumberedTab] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return rows }
        if let number = Int(trimmed), trimmed.utf8.allSatisfy({ (48...57).contains($0) }) {
            return rows.filter { $0.number == number }
        }
        let lookup = Dictionary(uniqueKeysWithValues: rows.map { ($0.destination.id, $0) })
        return FuzzySearch.ranked(rows.map(\.destination), query: trimmed).compactMap { lookup[$0.id] }
    }

    public func immediateSelection(_ input: String) -> Destination? {
        guard input.utf8.count == 1, let digit = input.utf8.first, (49...57).contains(digit) else { return nil }
        return rows.first { $0.number == Int(digit - 48) }?.destination
    }

    public func number(for destination: Destination) -> Int? {
        rows.first { $0.destination.id == destination.id }?.number
    }
}
