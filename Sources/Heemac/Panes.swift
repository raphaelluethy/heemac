import AppKit

/// Moves between panes inside an app's window before falling back to window
/// navigation, like vim-tmux-navigator. Currently supports Rex via its CLI.
enum Panes {
    static let rexBundleID = "com.superlogical.rex"

    /// Tries to move one pane in `direction` within the focused app. Returns
    /// true when a pane took focus; false means the caller should move between
    /// windows instead (no pane support, single pane, or at the layout edge).
    static func move(_ direction: Direction, pid: pid_t) -> Bool {
        guard Settings.paneNavigation,
              NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == rexBundleID,
              let rex = rexExecutable()
        else { return false }

        guard let before = rexFocus(rex), before.paneCount > 1 else { return false }
        guard run(rex, ["focus", direction.rawValue]) != nil, let after = rexFocus(rex) else { return false }
        return after.block != before.block
    }

    private struct RexFocus {
        let block: String
        let paneCount: Int
    }

    /// The focused pane of the active Rex window and how many panes it has.
    private static func rexFocus(_ rex: String) -> RexFocus? {
        guard let data = run(rex, ["window", "ls", "--json"]),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let activeID = json["active_window_id"] as? String,
              let windows = json["windows"] as? [[String: Any]],
              let window = windows.first(where: { $0["window_id"] as? String == activeID }),
              let block = window["focused_block_id"] as? String
        else { return nil }
        let layers = window["layers"] as? [[String: Any]] ?? []
        let panes = layers.filter { $0["kind"] as? String == "tiled" }
            .reduce(0) { $0 + (($1["blocks"] as? [Any])?.count ?? 0) }
        return RexFocus(block: block, paneCount: panes)
    }

    private static func rexExecutable() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            Settings.defaults.string(forKey: "rexPath"),
            "\(home)/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex",
            "/opt/homebrew/bin/rex",
            "/usr/local/bin/rex",
        ]
        return candidates.compactMap { $0 }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Runs a command with a short timeout; returns stdout on exit status 0.
    private static func run(_ path: String, _ args: [String], timeout: TimeInterval = 0.5) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let out = Pipe()
        process.standardOutput = out
        process.standardError = FileHandle.nullDevice
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        do { try process.run() } catch { return nil }
        let kill = DispatchWorkItem { process.terminate() }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: kill)
        // Read while it runs, so output larger than the pipe buffer can't stall it.
        let data = out.fileHandleForReading.readDataToEndOfFile()
        exited.wait()
        kill.cancel()
        guard process.terminationReason == .exit else {
            Navigator.log.error("\(path, privacy: .public) \(args.joined(separator: " "), privacy: .public) timed out")
            return nil
        }
        return process.terminationStatus == 0 ? data : nil
    }
}
