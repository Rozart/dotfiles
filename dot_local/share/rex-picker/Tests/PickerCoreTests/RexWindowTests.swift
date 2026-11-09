import Foundation
import Testing
@testable import PickerCore

@Test func generatedWindowLabelsUseTheTerminalTitle() throws {
    let data = Data(#"{"window_id":"window:12345678","label":"Window 12345678","focused_block_id":"block:one"}"#.utf8)
    let window = try RexJSON.decode(RexWindow.self, from: data)
    #expect(!window.hasCustomLabel)
    #expect(window.focusedBlockId == "block:one")
    #expect(window.displayTitle(terminalTitle: "  Pi · work · idle\n") == "Pi · work · idle")
    #expect(window.displayTitle(terminalTitle: "") == "Window 12345678")
    #expect(window.displayTitle(terminalTitle: nil) == "Window 12345678")
}

@Test func customTabNamesTakePriorityOverTerminalTitles() throws {
    let data = Data(#"{"window_id":"window:12345678","label":"logs"}"#.utf8)
    let window = try RexJSON.decode(RexWindow.self, from: data)
    #expect(window.hasCustomLabel)
    #expect(window.focusedBlockId == nil)
    #expect(window.displayTitle(terminalTitle: "shell") == "logs")
}
