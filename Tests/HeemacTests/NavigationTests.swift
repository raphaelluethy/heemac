import CoreGraphics
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

    private func window(_ id: CGWindowID, x: CGFloat, y: CGFloat) -> WindowInfo {
        WindowInfo(ids: [id], pid: 1, app: "Test", frame: CGRect(x: x, y: y, width: 100, height: 100),
                   visibleFraction: 1)
    }
}
