import Foundation
import Darwin

struct Listener: Identifiable, Equatable {
    var pid: Int32
    var process: String
    var uid: UInt32
    var port: Int
    var addresses: [String]
    var directory: String = ""
    var executable: String = ""
    var id: String { "\(pid):\(port)" }
    var project: String { directory.isEmpty || directory == "/" ? process : URL(fileURLWithPath: directory).lastPathComponent }
    var url: URL { URL(string: "http://localhost:\(port)")! }
    var canStop: Bool { uid == getuid() && pid != getpid() && !Self.protected.contains(process.lowercased()) }
    static let protected: Set<String> = ["controlcenter", "rapportd", "windowserver", "loginwindow", "systemuiserver", "sharingd", "portpocket", "launchd", "kernel_task"]
}

enum PortDiscovery {
    static func run(_ arguments: [String]) throws -> (String, Int32) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        task.arguments = arguments
        let output = Pipe()
        task.standardOutput = output
        task.standardError = FileHandle.nullDevice
        try task.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        return (String(decoding: data, as: UTF8.self), task.terminationStatus)
    }

    static func parse(_ text: String) -> [Listener] {
        var pid: Int32 = 0
        var process = ""
        var uid: UInt32 = UInt32.max
        var result: [String: Listener] = [:]
        for line in text.split(separator: "\n") {
            guard let field = line.first else { continue }
            let value = String(line.dropFirst())
            switch field {
            case "p": pid = Int32(value) ?? 0; process = ""; uid = UInt32.max
            case "c": process = value
            case "u": uid = UInt32(value) ?? UInt32.max
            case "n":
                guard pid > 0, let colon = value.lastIndex(of: ":"),
                      let port = Int(value[value.index(after: colon)...]), (1...65535).contains(port) else { continue }
                let address = String(value[..<colon])
                let key = "\(pid):\(port)"
                if var item = result[key] {
                    if !item.addresses.contains(address) { item.addresses.append(address); result[key] = item }
                } else { result[key] = Listener(pid: pid, process: process, uid: uid, port: port, addresses: [address]) }
            default: break
            }
        }
        return result.values.sorted { $0.port == $1.port ? $0.pid < $1.pid : $0.port < $1.port }
    }

    static func scan(details: Bool = true) throws -> [Listener] {
        let (text, status) = try run(["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcun"])
        guard status == 0 || (status == 1 && text.isEmpty) else {
            throw NSError(domain: "PortPocket", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Port discovery could not complete. Try refreshing."])
        }
        var listeners = parse(text)
        if details, !listeners.isEmpty {
            let pids = Set(listeners.map(\.pid)).map(String.init).joined(separator: ",")
            let (directories, _) = try run(["-a", "-p", pids, "-d", "cwd", "-F", "pn"])
            var pid: Int32 = 0
            var paths: [Int32: String] = [:]
            for line in directories.split(separator: "\n") {
                if line.first == "p" { pid = Int32(line.dropFirst()) ?? 0 }
                if line.first == "n" { paths[pid] = String(line.dropFirst()) }
            }
            for i in listeners.indices {
                listeners[i].directory = paths[listeners[i].pid] ?? ""
                listeners[i].executable = executable(pid: listeners[i].pid)
            }
        }
        return listeners
    }

    static func executable(pid: Int32) -> String {
        var path = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &path, UInt32(path.count)) > 0 else { return "" }
        return String(cString: path)
    }

    static func stop(_ listener: Listener) throws {
        guard listener.canStop, !listener.executable.isEmpty,
              executable(pid: listener.pid) == listener.executable,
              try scan(details: false).contains(where: { $0.id == listener.id && $0.uid == listener.uid && $0.process == listener.process }) else {
            throw NSError(domain: "PortPocket", code: 1, userInfo: [NSLocalizedDescriptionKey: "The process changed or is protected. Refresh the list and try again."])
        }
        guard kill(listener.pid, SIGTERM) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }
}

func testPortParser() {
    let fixture = "p123\ncnode\nu501\nf9\nn*:3000\nf10\nn[::1]:3000\np456\ncPython\nu501\nf4\nn127.0.0.1:8000\nnnot-a-port\n"
    let items = PortDiscovery.parse(fixture)
    precondition(items.count == 2)
    precondition(items[0].port == 3000 && items[0].addresses == ["*", "[::1]"])
    precondition(items[1].pid == 456 && items[1].process == "Python")
    precondition(PortDiscovery.parse("").isEmpty)
    let protected = Listener(pid: 123, process: "ControlCenter", uid: getuid(), port: 5000, addresses: ["*"])
    precondition(!protected.canStop)
    print("PASS: IPv4/IPv6 parsing, socket deduplication, sorting, empty state, protected process")
}
