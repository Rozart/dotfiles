import Testing
@testable import PickerCore

private func tab(_ number: Int, host: String = "local") -> Destination {
    Destination(host: host, hostLabel: host, sessionId: "s", sessionLabel: "api",
                windowId: "w\(number)", title: "tab \(number)", kind: .tab)
}

@Test func tabNumbersPreserveDiscoveryOrder() {
    let session = Destination(host: nil, hostLabel: "local", sessionId: "s", sessionLabel: "api",
                              title: "api", kind: .session)
    let tabs = NumberedTabs(destinations: [session, tab(2), tab(1), tab(3, host: "remote")])
    #expect(tabs.rows.map(\.number) == [1, 2, 3])
    #expect(tabs.rows.map(\.destination.title) == ["tab 2", "tab 1", "tab 3"])
    #expect(tabs.number(for: tab(1)) == 2)
}

@Test func filteringDoesNotRenumberTabs() {
    let tabs = NumberedTabs(destinations: (1...12).map { tab($0) })
    #expect(tabs.matching("12").map(\.number) == [12])
    #expect(tabs.matching("tab 12").map(\.number) == [12])
    #expect(tabs.matching("").map(\.number) == Array(1...12))
    #expect(tabs.matching("missing").isEmpty)
    #expect(tabs.matching("0").isEmpty)
}

@Test func singleDigitsSwitchImmediatelyButOtherInputDoesNot() {
    let tabs = NumberedTabs(destinations: (1...12).map { tab($0) })
    #expect(tabs.immediateSelection("9")?.windowId == "w9")
    for input in ["0", "10", "12", "１", " 1", "1 ", "a", ""] {
        #expect(tabs.immediateSelection(input) == nil)
    }
    #expect(NumberedTabs(destinations: [tab(1)]).immediateSelection("9") == nil)
}
