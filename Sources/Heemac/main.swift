import AppKit

let usage = """
usage: Heemac                    run the menu bar app
       Heemac --windows          list candidate windows (front to back)
       Heemac --focus <dir>      focus once; dir is left, right, up or down
       Heemac --login on|off|status   open at login (app bundle only)
"""

func printWindows() {
    let threshold = Settings.minVisibleFraction
    let current = Navigator.startingPoint(in: WindowList.visible(minVisibleFraction: threshold)).1
    for w in WindowList.all() {
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
    guard args.count == 2, let direction = Direction(rawValue: args[1]) else {
        FileHandle.standardError.write(Data((usage + "\n").utf8))
        exit(2)
    }
    exit(Navigator.move(direction) ? 0 : 1)
case "--login":
    switch args.dropFirst().first {
    case "on": exit(LoginItem.set(true) ? 0 : 1)
    case "off": exit(LoginItem.set(false) ? 0 : 1)
    case "status": print(LoginItem.isEnabled ? "on" : "off")
    default:
        FileHandle.standardError.write(Data((usage + "\n").utf8))
        exit(2)
    }
default:
    FileHandle.standardError.write(Data((usage + "\n").utf8))
    exit(2)
}
