import Testing
@testable import TrackingCheck

struct SavedSiteTests {

    // MARK: - Helpers

    private func site(_ rawURL: String, status: SiteStatus = .detected) -> SavedSite {
        SavedSite(rawURL: rawURL, status: status)
    }

    private func fullSite(_ rawURL: String, status: SiteStatus, ga4: SiteStatus = .notDetected,
                           gtm: SiteStatus = .notDetected, ads: SiteStatus = .notDetected,
                           ids: [DetectedID] = [], openedPage: String? = nil) -> SavedSite {
        SavedSite(rawURL: rawURL, status: status, ga4: ga4, gtm: gtm, ads: ads,
                  detectedIDs: ids, checkedURL: URLNormalizer.normalize(rawURL),
                  openedPage: openedPage ?? URLNormalizer.normalize(rawURL))
    }

    // MARK: - Identity matching

    @Test func identity_httpAndHttps_sameNormalizedURL() {
        #expect(site("http://example.com").normalizedURL == site("https://example.com").normalizedURL)
    }

    @Test func identity_queryStripped_matchesBare() {
        #expect(site("https://example.com?utm=abc").normalizedURL == site("example.com").normalizedURL)
    }

    @Test func identity_hashStripped_matchesBare() {
        #expect(site("https://example.com#section").normalizedURL == site("example.com").normalizedURL)
    }

    @Test func identity_trailingSlashStripped_matchesBare() {
        #expect(site("https://example.com/").normalizedURL == site("example.com").normalizedURL)
    }

    @Test func identity_caseInsensitive_matches() {
        #expect(site("HTTPS://EXAMPLE.COM").normalizedURL == site("example.com").normalizedURL)
    }

    @Test func identity_differentPaths_areDistinct() {
        #expect(site("example.com").normalizedURL != site("example.com/pricing").normalizedURL)
    }

    // MARK: - applySiteUpdate: field replacement

    @Test func update_preservesExistingID() {
        let original = site("example.com")
        let updated = fullSite("example.com", status: .possible)
        let result = applySiteUpdate(updated, to: [original])
        #expect(result[0].id == original.id)
    }

    @Test func update_replacesMutableFields() {
        let original = site("example.com", status: .notDetected)
        let newIDs = [DetectedID(category: .ga4, value: "G-ABCD1234")]
        let updated = fullSite("example.com", status: .detected,
                                ga4: .detected, gtm: .possible, ads: .notDetected,
                                ids: newIDs, openedPage: "example.com/redirect")
        let result = applySiteUpdate(updated, to: [original])
        #expect(result[0].status == .detected)
        #expect(result[0].ga4 == .detected)
        #expect(result[0].gtm == .possible)
        #expect(result[0].ads == .notDetected)
        #expect(result[0].checkedURL == "example.com")
        #expect(result[0].openedPage == "example.com/redirect")
        #expect(result[0].detectedIDs.first?.value == "G-ABCD1234")
        #expect(result[0].lastTouched == updated.lastTouched)
    }

    // MARK: - applySiteUpdate: list behavior

    @Test func update_movesUpdatedSiteToFront() {
        let sites = [site("a.com"), site("b.com"), site("c.com")]
        let updated = fullSite("c.com", status: .possible)
        let result = applySiteUpdate(updated, to: sites)
        #expect(result[0].normalizedURL == "c.com")
        #expect(result[1].normalizedURL == "a.com")
        #expect(result[2].normalizedURL == "b.com")
    }

    @Test func update_noDuplicateCreated() {
        let sites = [site("example.com"), site("other.com")]
        let updated = fullSite("example.com", status: .possible)
        let result = applySiteUpdate(updated, to: sites)
        #expect(result.count == 2)
    }

    @Test func update_unknownURL_leavesListUnchanged() {
        let sites = [site("example.com")]
        let unknown = fullSite("other.com", status: .detected)
        let result = applySiteUpdate(unknown, to: sites)
        #expect(result.count == 1)
        #expect(result[0].normalizedURL == "example.com")
    }

    @Test func update_checkFailedResult_updatesStatusAndClearsIDs() {
        let original = fullSite("example.com", status: .detected,
                                 ga4: .detected, ids: [DetectedID(category: .ga4, value: "G-ABCD1234")])
        let failed = fullSite("example.com", status: .checkFailed,
                               ga4: .checkFailed, gtm: .checkFailed, ads: .checkFailed)
        let result = applySiteUpdate(failed, to: [original])
        #expect(result[0].id == original.id)
        #expect(result[0].status == .checkFailed)
        #expect(result[0].ga4 == .checkFailed)
        #expect(result[0].detectedIDs.isEmpty)
    }
}
