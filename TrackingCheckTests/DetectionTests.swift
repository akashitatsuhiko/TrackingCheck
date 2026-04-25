import Testing
@testable import TrackingCheck

struct DetectionTests {

    // MARK: - GA4

    @Test func ga4_detected_viaGtagConfig_singleQuote() {
        let html = "<script>gtag('config', 'G-ABCD1234');</script>"
        let (signals, ids) = detectSignals(in: html)
        #expect(signals.ga4 == .detected)
        #expect(ids.contains { $0.category == .ga4 && $0.value == "G-ABCD1234" })
    }

    @Test func ga4_detected_viaGtagJS() {
        let html = #"<script async src="https://www.googletagmanager.com/gtag/js?id=G-ABCD1234"></script>"#
        let (signals, ids) = detectSignals(in: html)
        #expect(signals.ga4 == .detected)
        #expect(ids.contains { $0.category == .ga4 && $0.value == "G-ABCD1234" })
    }

    @Test func ga4_possible_bareID() {
        let html = "<meta content='G-ABCD1234'>"
        let (signals, ids) = detectSignals(in: html)
        #expect(signals.ga4 == .possible)
        #expect(ids.contains { $0.category == .ga4 && $0.value == "G-ABCD1234" })
    }

    @Test func ga4_notDetected_noID() {
        let html = "<html><body>No tracking here</body></html>"
        let (signals, ids) = detectSignals(in: html)
        #expect(signals.ga4 == .notDetected)
        #expect(!ids.contains { $0.category == .ga4 })
    }

    // MARK: - GTM

    @Test func gtm_detected_viaGtmJS() {
        let html = #"<script src="https://www.googletagmanager.com/gtm.js?id=GTM-WXYZ567"></script>"#
        let (signals, ids) = detectSignals(in: html)
        #expect(signals.gtm == .detected)
        #expect(ids.contains { $0.category == .gtm && $0.value == "GTM-WXYZ567" })
    }

    @Test func gtm_possible_bareID() {
        let html = "<!-- GTM-WXYZ567 -->"
        let (signals, ids) = detectSignals(in: html)
        #expect(signals.gtm == .possible)
        #expect(ids.contains { $0.category == .gtm && $0.value == "GTM-WXYZ567" })
    }

    @Test func gtm_notDetected_noID() {
        let html = "<html><body>No tag manager</body></html>"
        let (signals, ids) = detectSignals(in: html)
        #expect(signals.gtm == .notDetected)
        #expect(!ids.contains { $0.category == .gtm })
    }

    // MARK: - Ads

    @Test func ads_detected_viaGtagConfig() {
        let html = "<script>gtag('config', 'AW-123456789');</script>"
        let (signals, ids) = detectSignals(in: html)
        #expect(signals.ads == .detected)
        #expect(ids.contains { $0.category == .ads && $0.value == "AW-123456789" })
    }

    @Test func ads_possible_bareID() {
        let html = "<div data-ads='AW-123456789'></div>"
        let (signals, ids) = detectSignals(in: html)
        #expect(signals.ads == .possible)
        #expect(ids.contains { $0.category == .ads && $0.value == "AW-123456789" })
    }

    @Test func ads_notDetected_noID() {
        let html = "<html><body>No ads here</body></html>"
        let (signals, ids) = detectSignals(in: html)
        #expect(signals.ads == .notDetected)
        #expect(!ids.contains { $0.category == .ads })
    }

    // MARK: - All signals absent

    @Test func allNotDetected_emptyHTML() {
        let (signals, ids) = detectSignals(in: "")
        #expect(signals.ga4 == .notDetected)
        #expect(signals.gtm == .notDetected)
        #expect(signals.ads == .notDetected)
        #expect(ids.isEmpty)
    }

    // MARK: - Mixed page

    @Test func mixed_ga4Detected_gtmPossible_adsDetected() {
        let html = """
        <script>gtag('config', 'G-ABCD1234');</script>
        <!-- GTM-WXYZ567 -->
        <script>gtag('config', 'AW-123456789');</script>
        """
        let (signals, ids) = detectSignals(in: html)
        #expect(signals.ga4 == .detected)
        #expect(signals.gtm == .possible)
        #expect(signals.ads == .detected)
        #expect(ids.contains { $0.category == .ga4 && $0.value == "G-ABCD1234" })
        #expect(ids.contains { $0.category == .gtm && $0.value == "GTM-WXYZ567" })
        #expect(ids.contains { $0.category == .ads && $0.value == "AW-123456789" })
    }
}
