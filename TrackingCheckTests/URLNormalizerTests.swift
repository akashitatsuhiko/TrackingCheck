import Testing
@testable import TrackingCheck

struct URLNormalizerTests {

    // MARK: - normalize(_:)

    @Test func normalize_stripsHTTPS() {
        #expect(URLNormalizer.normalize("https://example.com") == "example.com")
    }

    @Test func normalize_stripsHTTP() {
        #expect(URLNormalizer.normalize("http://example.com") == "example.com")
    }

    @Test func normalize_stripsTrailingSlash() {
        #expect(URLNormalizer.normalize("https://Example.com/") == "example.com")
    }

    @Test func normalize_stripsQuery() {
        #expect(URLNormalizer.normalize("http://example.com/pricing?utm=abc") == "example.com/pricing")
    }

    @Test func normalize_stripsHash() {
        #expect(URLNormalizer.normalize("example.com/path/#section") == "example.com/path")
    }

    @Test func normalize_lowercases() {
        #expect(URLNormalizer.normalize("HTTPS://DOCS.Example.com/Login/") == "docs.example.com/login")
    }

    @Test func normalize_keepsPath() {
        #expect(URLNormalizer.normalize("example.com/pricing") == "example.com/pricing")
    }

    @Test func normalize_noProtocol() {
        #expect(URLNormalizer.normalize("example.com") == "example.com")
    }

    // MARK: - display(_:)

    @Test func display_matchesNormalize() {
        let inputs = [
            "https://Example.com/",
            "http://example.com/pricing?utm=abc",
            "example.com/path/#section",
            "HTTPS://DOCS.Example.com/Login/",
        ]
        for input in inputs {
            #expect(URLNormalizer.display(input) == URLNormalizer.normalize(input))
        }
    }
}
