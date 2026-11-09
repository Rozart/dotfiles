import Foundation
import Testing
@testable import PickerCore

@Test func subsequenceMatching() {
    #expect(FuzzySearch.score("dvst", in: "dev-station") != nil)
    #expect(FuzzySearch.score("dvsx", in: "dev-station") == nil)
    #expect(FuzzySearch.score("zz", in: "z") == nil)
    #expect(FuzzySearch.score("", in: "") == 0)
}

@Test func tokensAndUnicode() {
    #expect(FuzzySearch.score("logs dev", in: "dev-station api logs") != nil)
    #expect(FuzzySearch.score("CAFE", in: "café") != nil)
    #expect(FuzzySearch.score("😀", in: "work 😀") != nil)
}

@Test func rankingFavorsConsecutiveAndBoundaries() {
    #expect(FuzzySearch.score("api", in: "api")! > FuzzySearch.score("api", in: "a-long-project-index")!)
    #expect(FuzzySearch.score("log", in: "logs")! > FuzzySearch.score("log", in: "catalog")!)
}

@Test func searchesHostAndSessionContext() {
    let tab = Destination(host: "dev-station", hostLabel: "dev-station", sessionId: "s",
                          sessionLabel: "api", windowId: "w", title: "logs", kind: .tab)
    #expect(FuzzySearch.ranked([tab], query: "dvst lg").map(\.id) == [tab.id])
    #expect(FuzzySearch.ranked([tab], query: "missing").isEmpty)
}

@Test func stableDestinationIdentity() {
    let first = Destination(host: "a", hostLabel: "a", sessionId: "s", sessionLabel: "api", title: "api", kind: .session)
    let second = Destination(host: "b", hostLabel: "b", sessionId: "s", sessionLabel: "api", title: "api", kind: .session)
    #expect(first.id != second.id)
}

@Test func decodesRexFixturesAndDeduplicatesUnixHosts() throws {
    let data = Data(#"{"hosts":[{"host":{"label":"dev","endpoints":["/tmp/dev.sock"]}},{"host":{"label":"dev.sock","endpoints":["unix:///tmp/dev.sock"]}},{"host":{"label":"other","endpoints":["https://other"]}}]}"#.utf8)
    #expect(try RexJSON.decode(HostList.self, from: data).uniqueLabels == ["dev", "other"])
    let sessions = Data(#"{"sessions":[{"session_id":"session:one","label":"api"}]}"#.utf8)
    #expect(try RexJSON.decode(SessionList.self, from: sessions).sessions.first?.sessionId == "session:one")
}

@Test func neverTargetsAnotherMacOrDisconnectedClient() throws {
    let data = Data(#"{"clients":[{"client_id":"one","info":{"kind":"app","platform":"macos","label":"this-mac"}},{"client_id":"two","info":{"kind":"app","platform":"macos","label":"other-mac"}},{"client_id":"old","connection_state":"lost","info":{"kind":"app","platform":"macos","label":"this-mac"}}]}"#.utf8)
    let list = try RexJSON.decode(ClientList.self, from: data)
    #expect(try list.app(label: "this-mac").clientId == "one")
    #expect(throws: PickerError.self) { try list.app() }
    #expect(throws: PickerError.self) { try list.app(label: "missing") }
}
