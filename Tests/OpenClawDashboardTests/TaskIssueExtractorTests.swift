import XCTest
@testable import OpenClawDashboard

final class TaskIssueExtractorTests: XCTestCase {
    func testExtractIssuesIgnoresRemediatedBaselineRegressions() {
        let response = """
        Update complete.
        Remaining issues were baseline regressions identified and now remediated.
        """

        let issues = TaskIssueExtractor.extractIssues(from: response)

        XCTAssertTrue(issues.isEmpty)
    }

    func testExtractIssuesKeepsUnresolvedIssueLines() {
        let response = """
        Remaining issues:
        - Regression in Tasks tab keyboard focus still failing.
        """

        let issues = TaskIssueExtractor.extractIssues(from: response)

        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first, "Regression in Tasks tab keyboard focus still failing.")
    }

    func testExtractIssuesIgnoresPassingRegressionCheckStatus() {
        let response = """
        PASS: task-1300 regression checks complete
        """

        let issues = TaskIssueExtractor.extractIssues(from: response)

        XCTAssertTrue(issues.isEmpty)
    }

    func testExtractIssuesKeepsFailingRegressionStatus() {
        let response = """
        FAIL: task-1300 regression checks complete with keyboard trap issue in model picker
        """

        let issues = TaskIssueExtractor.extractIssues(from: response)

        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first, "FAIL: task-1300 regression checks complete with keyboard trap issue in model picker")
    }
}
