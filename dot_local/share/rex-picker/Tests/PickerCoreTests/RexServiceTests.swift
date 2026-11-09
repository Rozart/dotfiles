import Foundation
import Testing
@testable import PickerCore

private func withExecutable(_ source: String, run: (String) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let executable = directory.appendingPathComponent("rex-fixture")
    try Data(("#!/bin/sh\n" + source).utf8).write(to: executable)
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
    try run(executable.path)
}

@Test func commandArgumentsStaySeparateAndHostIsExplicit() throws {
    try withExecutable("printf '%s\\n' \"$@\"") { executable in
        let data = try RexService(executable: executable).run(["do", "session.select", "session_id=a;b"], host: "dev box")
        let arguments = String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
        #expect(arguments == ["--timeout", "4s", "--autostart=false", "-S", "dev box", "do", "session.select", "session_id=a;b"])
    }
}

@Test func drainsBothOutputStreams() throws {
    try withExecutable("i=0; while [ \"$i\" -lt 10000 ]; do printf 'output\\n'; printf 'error\\n' >&2; i=$((i+1)); done") { executable in
        let data = try RexService(executable: executable).run([])
        #expect(data.count == 70000)
    }
}

@Test func commandFailuresKeepTheirErrorMessage() throws {
    try withExecutable("printf 'Remote Control is off' >&2; exit 3") { executable in
        do {
            _ = try RexService(executable: executable).run([])
            Issue.record("Expected an error")
        } catch {
            #expect(error.localizedDescription == "Remote Control is off")
        }
    }
}

@Test func emptyErrorsStillExplainFailure() throws {
    try withExecutable("exit 7") { executable in
        do {
            _ = try RexService(executable: executable).run([])
            Issue.record("Expected an error")
        } catch {
            #expect(error.localizedDescription == "Rex exited with status 7.")
        }
    }
}
