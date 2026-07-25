import XCTest
@testable import OBSStopwatchMac
final class OBSStopwatchMacTests: XCTestCase {
    @MainActor
    func testFormatsElapsedTime() {
        XCTAssertEqual(StopwatchModel.format(0), "00:00:00")
        XCTAssertEqual(StopwatchModel.format(3_661), "01:01:01")
        XCTAssertEqual(StopwatchModel.format(-1), "00:00:00")
    }

    @MainActor
    func testParsesValidElapsedTime() {
        XCTAssertEqual(StopwatchModel.parse("01:01:01"), 3_661)
        XCTAssertEqual(StopwatchModel.parse(" 10:05:09\n"), 36_309)
    }

    @MainActor
    func testRejectsInvalidElapsedTime() {
        XCTAssertNil(StopwatchModel.parse("1:2"))
        XCTAssertNil(StopwatchModel.parse("00:60:00"))
        XCTAssertNil(StopwatchModel.parse("-1:00:00"))
    }
}
