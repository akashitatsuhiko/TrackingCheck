import Foundation
import Testing
@testable import TrackingCheck

struct FetchAndCheckTests {

    // MARK: - Invalid URL (guard fires before fetcher is called)

    @Test func invalidURL_noHostDot() async {
        let result = await fetchAndCheck(input: "plaintext")
        #expect(result.failureReason == .invalidURL)
        #expect(result.checkedURL == "plaintext")
        #expect(result.openedPage == "plaintext")
    }

    // MARK: - URLError mapping

    @Test func urlError_timedOut_mapsToTimedOut() async {
        let result = await fetchAndCheck(input: "example.com", fetcher: { _ in
            throw URLError(.timedOut)
        })
        #expect(result.failureReason == .timedOut)
    }

    @Test func urlError_networkFailure_mapsToCouldntLoad() async {
        let result = await fetchAndCheck(input: "example.com", fetcher: { _ in
            throw URLError(.networkConnectionLost)
        })
        #expect(result.failureReason == .couldntLoad)
    }

    @Test func urlError_badURL_mapsToInvalidURL() async {
        let result = await fetchAndCheck(input: "example.com", fetcher: { _ in
            throw URLError(.badURL)
        })
        #expect(result.failureReason == .invalidURL)
    }

    @Test func nonURLError_mapsToCouldntLoad() async {
        struct ArbitraryError: Error {}
        let result = await fetchAndCheck(input: "example.com", fetcher: { _ in
            throw ArbitraryError()
        })
        #expect(result.failureReason == .couldntLoad)
    }

    // MARK: - HTTP status code mapping

    @Test func http404_mapsToCouldntLoad() async {
        let result = await fetchAndCheck(input: "example.com", fetcher: { req in
            (Data(), HTTPURLResponse(url: req.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!)
        })
        #expect(result.failureReason == .couldntLoad)
    }

    @Test func http500_mapsToCouldntLoad() async {
        let result = await fetchAndCheck(input: "example.com", fetcher: { req in
            (Data(), HTTPURLResponse(url: req.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!)
        })
        #expect(result.failureReason == .couldntLoad)
    }

    // MARK: - Successful response

    @Test func success_normalizedCheckedURL() async {
        let result = await fetchAndCheck(input: "https://Example.com/", fetcher: { req in
            (Data(), HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        #expect(result.isSuccess)
        #expect(result.checkedURL == "example.com")
    }

    @Test func success_openedPageFromResponseURL() async {
        let finalURL = URL(string: "https://example.com/redirect")!
        let result = await fetchAndCheck(input: "example.com", fetcher: { _ in
            (Data(), HTTPURLResponse(url: finalURL, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        #expect(result.openedPage == "example.com/redirect")
    }

    @Test func success_checkedURLRemainsNormalizedInput_onRedirect() async {
        let finalURL = URL(string: "https://example.com/redirect")!
        let result = await fetchAndCheck(input: "example.com", fetcher: { _ in
            (Data(), HTTPURLResponse(url: finalURL, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        #expect(result.checkedURL == "example.com")
    }
}
