import Testing
@testable import TrackingCheck

struct ChangesSummaryTests {

    // Convenience aliases
    private typealias Signals = DetailsData.Signals

    private func signals(_ ga4: SiteStatus, _ gtm: SiteStatus, _ ads: SiteStatus) -> Signals {
        Signals(ga4: ga4, gtm: gtm, ads: ads)
    }

    // MARK: - No changes

    @Test func noChanges_returnsEmpty() {
        let s = signals(.detected, .possible, .notDetected)
        let result = detailsDiff(oldSignals: s, oldPage: "example.com", newSignals: s, newPage: "example.com")
        #expect(result.isEmpty)
    }

    // MARK: - Signal status changed

    @Test func signalChanged_ga4() {
        let result = detailsDiff(
            oldSignals: signals(.notDetected, .notDetected, .notDetected), oldPage: "example.com",
            newSignals: signals(.detected, .notDetected, .notDetected),    newPage: "example.com"
        )
        #expect(result.contains("Signal status changed"))
    }

    @Test func signalChanged_gtm() {
        let result = detailsDiff(
            oldSignals: signals(.notDetected, .notDetected, .notDetected), oldPage: "example.com",
            newSignals: signals(.notDetected, .possible, .notDetected),    newPage: "example.com"
        )
        #expect(result.contains("Signal status changed"))
    }

    @Test func signalChanged_ads() {
        let result = detailsDiff(
            oldSignals: signals(.detected, .detected, .notDetected), oldPage: "example.com",
            newSignals: signals(.detected, .detected, .detected),    newPage: "example.com"
        )
        #expect(result.contains("Signal status changed"))
    }

    @Test func signalUnchanged_notIncluded() {
        let s = signals(.detected, .detected, .possible)
        let result = detailsDiff(oldSignals: s, oldPage: "example.com", newSignals: s, newPage: "example.com")
        #expect(!result.contains("Signal status changed"))
    }

    // MARK: - Opened page changed

    @Test func openedPageChanged() {
        let s = signals(.detected, .notDetected, .notDetected)
        let result = detailsDiff(oldSignals: s, oldPage: "example.com", newSignals: s, newPage: "example.com/redirect")
        #expect(result.contains("Opened page changed"))
    }

    @Test func openedPageUnchanged_notIncluded() {
        let s = signals(.detected, .notDetected, .notDetected)
        let result = detailsDiff(oldSignals: s, oldPage: "example.com", newSignals: s, newPage: "example.com")
        #expect(!result.contains("Opened page changed"))
    }

    // MARK: - Aggregate check status changed

    @Test func checkStatusChanged_notDetectedToDetected() {
        let result = detailsDiff(
            oldSignals: signals(.notDetected, .notDetected, .notDetected), oldPage: "example.com",
            newSignals: signals(.detected, .notDetected, .notDetected),    newPage: "example.com"
        )
        #expect(result.contains("Check status changed"))
    }

    @Test func checkStatusChanged_detectedToCheckFailed() {
        let result = detailsDiff(
            oldSignals: signals(.detected, .notDetected, .notDetected),   oldPage: "example.com",
            newSignals: signals(.checkFailed, .checkFailed, .checkFailed), newPage: "example.com"
        )
        #expect(result.contains("Check status changed"))
    }

    @Test func checkStatusUnchanged_notIncluded() {
        // Both aggregate to .detected
        let result = detailsDiff(
            oldSignals: signals(.detected, .notDetected, .notDetected), oldPage: "example.com",
            newSignals: signals(.notDetected, .detected, .notDetected), newPage: "example.com"
        )
        #expect(!result.contains("Check status changed"))
    }

    // MARK: - Multiple changes

    @Test func multipleChanges_allThreeLines() {
        let result = detailsDiff(
            oldSignals: signals(.notDetected, .notDetected, .notDetected), oldPage: "example.com",
            newSignals: signals(.detected, .notDetected, .notDetected),    newPage: "example.com/new"
        )
        #expect(result.contains("Signal status changed"))
        #expect(result.contains("Opened page changed"))
        #expect(result.contains("Check status changed"))
        #expect(result.count == 3)
    }

    @Test func multipleChanges_signalAndPage_noAggregateChange() {
        // ga4 changes detected→possible (aggregate stays detected), page changes
        let result = detailsDiff(
            oldSignals: signals(.detected, .notDetected, .notDetected), oldPage: "example.com",
            newSignals: signals(.possible, .detected, .notDetected),    newPage: "example.com/other"
        )
        #expect(result.contains("Signal status changed"))
        #expect(result.contains("Opened page changed"))
        #expect(!result.contains("Check status changed"))
        #expect(result.count == 2)
    }
}
