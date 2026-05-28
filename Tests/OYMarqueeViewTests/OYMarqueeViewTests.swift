import XCTest
@testable import OYMarqueeView

#if canImport(UIKit)
import UIKit

final class OYMarqueeViewTests: XCTestCase {

    private final class DummyDataSource: OYMarqueeViewDataSource {
        func numberOfItems(in marqueeView: OYMarqueeView) -> Int { 3 }

        func marqueeView(_ marqueeView: OYMarqueeView, itemForIndexAt index: Int) -> OYMarqueeViewItem {
            OYMarqueeViewItem(reuseIdentifier: "cell")
        }

        func marqueeView(_ marqueeView: OYMarqueeView, itemSizeForIndexAt index: Int) -> CGSize {
            CGSize(width: 60, height: 20)
        }
    }

    private final class SpyDelegate: OYMarqueeViewDelegate {
        var didDisplayIndices: [Int] = []
        var didSelectIndices: [Int] = []

        func marqueeView(_ marqueeView: OYMarqueeView, didDisplayItemAt index: Int) {
            didDisplayIndices.append(index)
        }

        func marqueeView(_ marqueeView: OYMarqueeView, didSelectItemAt index: Int) {
            didSelectIndices.append(index)
        }
    }

    func testPauseResumeStopStateTransitions() {
        let view = OYMarqueeView(frame: CGRect(x: 0, y: 0, width: 200, height: 40), scrollDirection: .horizontal)
        let ds = DummyDataSource()
        view.dataSource = ds

        view.reloadData()
        XCTAssertFalse(view.isPaused)

        view.pause()
        XCTAssertTrue(view.isPaused)

        view.resume()
        XCTAssertFalse(view.isPaused)

        view.stop()
        XCTAssertFalse(view.isPaused)
    }

    func testDeprecatedAliasDataSourseMapsToDataSource() {
        let view = OYMarqueeView()
        let ds = DummyDataSource()

        view.dataSourse = ds
        XCTAssertNotNil(view.dataSource)

        view.dataSource = nil
        XCTAssertNil(view.dataSourse)
    }

    func testSpacingAndOffsetAreClampedToNonNegative() {
        let view = OYMarqueeView()

        view.itemSpacing = -10
        XCTAssertEqual(view.itemSpacing, 0)

        view.preloadOffset = -30
        XCTAssertEqual(view.preloadOffset, 0)

        view.space = -5
        XCTAssertEqual(view.itemSpacing, 0)

        view.offset = -7
        XCTAssertEqual(view.preloadOffset, 0)
    }

    func testDelegateReceivesDidDisplayCallbackAfterReloadData() {
        let view = OYMarqueeView(frame: CGRect(x: 0, y: 0, width: 200, height: 40), scrollDirection: .horizontal)
        let ds = DummyDataSource()
        let spy = SpyDelegate()
        view.dataSource = ds
        view.delegate = spy

        view.reloadData()
        XCTAssertFalse(spy.didDisplayIndices.isEmpty)
    }
}

#else

final class OYMarqueeViewTests: XCTestCase {
    func testUIKitUnavailableOnThisPlatform() {
        XCTAssertTrue(true)
    }
}

#endif
