import AppKit

let usage = """
usage: Heemac                    run the menu bar app
       Heemac --windows          list candidate windows (front to back)
       Heemac --focus <dir>      focus once; dir is left, right, up or down
       Heemac --login on|off|status   open at login (app bundle only)
"""

func exitWithUsage() -> Never {
    FileHandle.standardError.write(Data((usage + "\n").utf8))
    exit(2)
}

func printWindows() {
    let threshold = Settings.minVisibleFraction
    let windows = WindowList.all()
    let current = Navigator.startingPoint(in: windows.filter { $0.isStandard && $0.visibleFraction >= threshold }).1
    for w in windows {
        let mark = w.ids == current?.ids ? "*" : " "
        let state = !w.isStandard ? "panel" : w.visibleFraction >= threshold ? "target" : "hidden"
        let f = w.frame
        print(String(format: "%@ %-6@ %3.0f%%  %@  [%@]  %.0f,%.0f %.0fx%.0f",
                     mark, state, w.visibleFraction * 100, w.app,
                     w.ids.map(String.init).joined(separator: ","), f.minX, f.minY, f.width, f.height))
    }
}

let args = Array(CommandLine.arguments.dropFirst())
let app = NSApplication.shared

switch args.first {
case nil:
    if let bundleID = Bundle.main.bundleIdentifier,
       NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1
    {
        exit(0) // already running
    }
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
case "--windows":
    printWindows()
case "--focus":
    guard args.count == 2, let direction = Direction(rawValue: args[1]) else { exitWithUsage() }
    exit(Navigator.move(direction) ? 0 : 1)
case "--login":
    switch args.dropFirst().first {
    case "on": exit(LoginItem.set(true) ? 0 : 1)
    case "off": exit(LoginItem.set(false) ? 0 : 1)
    case "status": print(LoginItem.isEnabled ? "on" : "off")
    default: exitWithUsage()
    }
default:
    exitWithUsage()
}
