import XCTest
@testable import OpenClawDashboard

final class ContentLayoutPolicyTests: XCTestCase {
    private let compactWidth: CGFloat = ContentLayoutPolicy.compactThreshold - 1
    private let defaultWidth: CGFloat = ContentLayoutPolicy.compactThreshold
    private let wideWidth: CGFloat = ContentLayoutPolicy.compactThreshold + 500

    func testCompactChatPreservesSidebarCollapsedState() {
        let collapsed = ContentLayoutPolicy.state(for: compactWidth, selectedTab: .chat, currentSidebarCollapsed: true)
        let expanded = ContentLayoutPolicy.state(for: compactWidth, selectedTab: .chat, currentSidebarCollapsed: false)

        XCTAssertTrue(collapsed.isCompactWindow)
        XCTAssertTrue(collapsed.isMainSidebarCollapsed)
        XCTAssertTrue(expanded.isCompactWindow)
        XCTAssertFalse(expanded.isMainSidebarCollapsed)
    }

    func testCompactNonChatForcesSidebarVisibleAcrossAllTabs() {
        let nonChatTabs = AppTab.allCases.filter { $0 != .chat }

        for tab in nonChatTabs {
            let state = ContentLayoutPolicy.state(for: compactWidth, selectedTab: tab, currentSidebarCollapsed: true)
            XCTAssertTrue(state.isCompactWindow, "Expected compact for tab \(tab)")
            XCTAssertFalse(state.isMainSidebarCollapsed, "Compact mode must force sidebar visible for tab \(tab)")
        }
    }

    func testDefaultAndWideWidthsForceSidebarVisibleAcrossAllTabs() {
        let widths: [(name: String, value: CGFloat)] = [
            ("default", defaultWidth),
            ("wide", wideWidth)
        ]

        for width in widths {
            for tab in AppTab.allCases {
                let state = ContentLayoutPolicy.state(for: width.value, selectedTab: tab, currentSidebarCollapsed: true)
                XCTAssertFalse(state.isCompactWindow, "Expected \(width.name) width to be non-compact for tab \(tab)")
                XCTAssertFalse(state.isMainSidebarCollapsed, "Expected sidebar visible for \(width.name) width on tab \(tab)")
            }
        }
    }
}
