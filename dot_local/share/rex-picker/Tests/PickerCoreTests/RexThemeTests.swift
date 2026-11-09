import Foundation
import Testing
@testable import PickerCore

private func themes(red: Double = 0.2) -> Data {
    let color = #"{"red":RED,"green":0.3,"blue":0.4,"alpha":1,"colorSpace":"srgb"}"#
        .replacingOccurrences(of: "RED", with: String(red))
    return Data("""
    [{"id":"light","name":"Hikari","appearance":"light","palette":{
    "background":\(color),"foreground":\(color),
    "selectionBackground":\(color),"selectionForeground":\(color)}},
    {"id":"dark","name":"Shusia","appearance":"dark","palette":{
    "background":\(color),"foreground":\(color),
    "selectionBackground":\(color),"selectionForeground":\(color)}}]
    """.utf8)
}

@Test func selectsExactRexThemeAndAppearance() throws {
    #expect(try RexTheme.selected(from: themes(), id: "dark", appearance: "dark")?.name == "Shusia")
    #expect(try RexTheme.selected(from: themes(), id: "light", appearance: "light")?.name == "Hikari")
    #expect(try RexTheme.selected(from: themes(), id: "dark", appearance: "light") == nil)
    #expect(try RexTheme.selected(from: themes(), id: "missing", appearance: "dark") == nil)
}

@Test func rejectsInvalidThemeChannelsAndMalformedData() throws {
    #expect(try RexTheme.selected(from: themes(red: 1.1), id: "light", appearance: "light") == nil)
    #expect(throws: (any Error).self) {
        try RexTheme.selected(from: Data("invalid".utf8), id: "light", appearance: "light")
    }
}
