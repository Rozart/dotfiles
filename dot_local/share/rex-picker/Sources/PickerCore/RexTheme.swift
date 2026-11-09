import Foundation

public struct RexTheme: Decodable, Sendable {
    public struct Color: Decodable, Sendable {
        public let red: Double
        public let green: Double
        public let blue: Double
        public let alpha: Double
        public let colorSpace: String

        public var isValid: Bool {
            colorSpace == "srgb" && [red, green, blue, alpha].allSatisfy { $0.isFinite && (0...1).contains($0) }
        }
    }

    public struct Palette: Decodable, Sendable {
        public let background: Color
        public let foreground: Color
        public let selectionBackground: Color
        public let selectionForeground: Color

        public var isValid: Bool {
            [background, foreground, selectionBackground, selectionForeground].allSatisfy(\.isValid)
        }
    }

    public let id: String
    public let name: String
    public let appearance: String
    public let palette: Palette

    public static func selected(from data: Data, id: String, appearance: String) throws -> RexTheme? {
        try JSONDecoder().decode([RexTheme].self, from: data).first {
            $0.id == id && $0.appearance == appearance && $0.palette.isValid
        }
    }
}
