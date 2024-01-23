import Foundation
import SpatialMediaKit
import XCTest

class SpatialVideoSplitterTest: XCTestCase {
  let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
    UUID().uuidString)
  override func setUp() {
    try! FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: false)
  }

  override func tearDown() {
    try! FileManager.default.removeItem(at: testDirectory)
  }

  func testSplittingFiles() throws {
    guard
      let videoURL = Bundle.module.path(forResource: "spatial_video", ofType: ".mov")
    else {
      XCTFail("Video file not found in test bundle")
      return
    }

    SpatialVideoSplitter().transcodeMovie(
      filePath: videoURL, outputDir: testDirectory.absoluteString
    )
    XCTAssertNotNil(
      FileManager.default.fileExists(
        atPath:
          testDirectory.appendingPathComponent("spatial_video_LEFT.mov").absoluteString))
    XCTAssertNotNil(
      FileManager.default.fileExists(
        atPath:
          testDirectory.appendingPathComponent("spatial_video_RIGHT.mov").absoluteString))
  }
}
