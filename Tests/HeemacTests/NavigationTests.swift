import AppKit
import XCTest
@testable import Heemac

final class NavigationTests: XCTestCase {
    private let origin = CGRect(x: 100, y: 100, width: 100, height: 100)

    func testEachDirectionUsesScreenCoordinates() {
        let left = window(1, x: 0, y: 100)
        let right = window(2, x: 200, y: 100)
        let up = window(3, x: 100, y: 0)
        let down = window(4, x: 100, y: 200)
        let windows = [left, right, up, down]

        for (direction, expected) in [(Direction.left, left), (.right, right), (.up, up), (.down, down)] {
            XCTAssertEqual(Navigator.nearest(direction, from: origin, excluding: nil, among: windows)?.ids,
                           expected.ids)
        }
    }

    func testAlignedWindowWinsOverCloserDiagonalWindow() {
        let diagonal = window(1, x: 200, y: 200)
        let aligned = window(2, x: 600, y: 100)

        XCTAssertEqual(Navigator.nearest(.right, from: origin, excluding: nil, among: [diagonal, aligned])?.ids,
                       aligned.ids)
    }

    func testNearestAlignedWindowWins() {
        let far = window(1, x: 400, y: 100)
        let near = window(2, x: 220, y: 100)

        XCTAssertEqual(Navigator.nearest(.right, from: origin, excluding: nil, among: [far, near])?.ids,
                       near.ids)
    }

    func testNoWrapAndCurrentWindowIsExcluded() {
        let current = window(1, x: 100, y: 100)
        let right = window(2, x: 200, y: 100)
        let oldOrigin = origin.offsetBy(dx: 10, dy: 0)

        XCTAssertNil(Navigator.nearest(.left, from: oldOrigin, excluding: current, among: [current, right]))
    }

    func testVisibilityCountsOnlyOnScreenArea() {
        let screen = CGRect(x: 0, y: 0, width: 200, height: 200)
        let partlyOffScreen = CGRect(x: 100, y: 0, width: 200, height: 100)
        let covering = CGRect(x: 100, y: 0, width: 50, height: 100)

        XCTAssertEqual(WindowList.visibleFraction(of: partlyOffScreen, coveredBy: [], screens: [screen]), 1)
        XCTAssertEqual(WindowList.visibleFraction(of: partlyOffScreen, coveredBy: [covering], screens: [screen]), 0.5)
        XCTAssertEqual(WindowList.visibleFraction(of: partlyOffScreen, coveredBy: [screen], screens: [screen]), 0)
        XCTAssertEqual(WindowList.visibleFraction(of: partlyOffScreen, coveredBy: [], screens: []), 0)
    }

    func testWindowServerEntriesBecomeTargetsWithVisibleFraction() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        let overlay = CGRect(x: 0, y: 0, width: 400, height: 400)
        // Front to back, as CGWindowListCopyWindowInfo returns them.
        let raw = [
            entry(10, pid: 7, frame: screen, layer: 25), // menu or panel layer: ignored, covers nothing
            entry(11, pid: 8, frame: screen), // background-only app: ignored, covers nothing
            entry(12, pid: 9, frame: CGRect(x: 0, y: 0, width: 30, height: 30)), // too small
            entry(1, pid: 1, frame: overlay), // an app's overlay window...
            entry(2, pid: 1, frame: overlay.offsetBy(dx: 1, dy: 0)), // ...above its own real window
            entry(4, pid: 2, frame: CGRect(x: 200, y: 0, width: 400, height: 400)), // left half under the overlay
            entry(5, pid: 3, frame: CGRect(x: 50, y: 50, width: 300, height: 300)), // entirely under the overlay
        ]

        let groups = WindowList.groups(raw, screens: [screen], policies: [8: .prohibited, 1: .regular])

        XCTAssertEqual(groups.map(\.ids), [[1, 2], [4], [5]])
        XCTAssertEqual(groups.map(\.visibleFraction), [1, 0.5, 0])
    }

    private func entry(_ id: CGWindowID, pid: pid_t, frame: CGRect, layer: Int = 0) -> [String: Any] {
        [
            kCGWindowNumber as String: id,
            kCGWindowOwnerPID as String: pid,
            kCGWindowOwnerName as String: "App \(pid)",
            kCGWindowLayer as String: layer,
            kCGWindowBounds as String: frame.dictionaryRepresentation as NSDictionary,
        ]
    }

    private func window(_ id: CGWindowID, x: CGFloat, y: CGFloat) -> WindowInfo {
        WindowInfo(ids: [id], pid: 1, app: "Test", frame: CGRect(x: x, y: y, width: 100, height: 100),
                   visibleFraction: 1)
    }
}
