//  Story 134 (#142): the home row brings Exercise Analyzer to the front. Install Exercise Analyzer's simulator build
//  (its own repo) on the simulator first; without it this fails.

import XCTest

final class ExerciseAnalyzerLinkUITests: XCTestCase {
  func testHomeRowOpensExerciseAnalyzer() throws {
    let analyzer = XCUIApplication(bundleIdentifier: "com.idvorkin.exerciseanalyzer")
    let app = XCUIApplication()
    app.launch()
    let row = app.buttons["home-exercise_analyzer"]
    XCTAssertTrue(row.waitForExistence(timeout: 15), app.debugDescription)
    row.tap()
    XCTAssertTrue(analyzer.wait(for: .runningForeground, timeout: 15), "Exercise Analyzer came to the front")
  }
}
