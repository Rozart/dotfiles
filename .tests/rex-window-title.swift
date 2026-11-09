import CoreGraphics
import Foundation

let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.count == 4, arguments[0] == "--pid", arguments[2] == "--session", let pid = Int(arguments[1]) {
    let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
    let titles = windows.filter {
        ($0[kCGWindowOwnerPID as String] as? Int) == pid
    }.compactMap { $0[kCGWindowName as String] as? String }.filter {
        $0.hasSuffix(" - " + arguments[3])
    }
    guard titles.count == 1 else {
        let names = windows.filter {
            ($0[kCGWindowOwnerPID as String] as? Int) == pid
        }.compactMap { $0[kCGWindowName as String] as? String }
        FileHandle.standardError.write(Data(names.joined(separator: "\n").utf8))
        exit(1)
    }
    print(titles[0])
} else if arguments.count == 1, let windowID = UInt32(arguments[0]) {
    let windows = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]] ?? []
    guard let title = windows.first(where: {
        ($0[kCGWindowNumber as String] as? UInt32) == windowID
    })?[kCGWindowName as String] as? String else { exit(1) }
    print(title)
} else {
    exit(2)
}
