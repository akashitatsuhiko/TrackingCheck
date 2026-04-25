import SwiftUI

// MARK: - Check Screen Models

struct TrackingSignals {
    var ga4: SiteStatus
    var gtm: SiteStatus
    var ads: SiteStatus

    var aggregate: SiteStatus {
        let s = [ga4, gtm, ads]
        if s.contains(.detected) { return .detected }
        if s.contains(.possible) { return .possible }
        return .notDetected
    }
}

enum CheckFailureReason: String {
    case invalidURL = "Invalid URL"
    case couldntLoad = "Couldn\u{2019}t load page"
    case timedOut = "Timed out"
}

struct CheckResult {
    enum Outcome {
        case success(TrackingSignals)
        case failure(CheckFailureReason)
    }
    var outcome: Outcome
    var checkedURL: String
    var openedPage: String
    var checkedAt: Date = .now
    var detectedIDs: [DetectedID] = []

    var aggregate: SiteStatus {
        switch outcome {
        case .success(let s): return s.aggregate
        case .failure: return .checkFailed
        }
    }

    var signals: TrackingSignals? {
        if case .success(let s) = outcome { return s }
        return nil
    }

    var failureReason: CheckFailureReason? {
        if case .failure(let r) = outcome { return r }
        return nil
    }

    var isSuccess: Bool { signals != nil }
}

// MARK: - Check Screen

struct CheckScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.saveSiteAction) private var onSave
    @Environment(\.savedNormalizedURLs) private var savedNormalizedURLs
    @Environment(\.updateSiteAction) private var updateSiteAction
    @Environment(\.isPro) private var isPro

    @State private var urlInput: String
    @State private var result: CheckResult?
    @State private var isChecking = false
    @State private var isSaved = false
    @State private var resultOpacity: Double = 1
    @State private var isClearing = false
    @State private var showSavedToast = false
    @State private var showLimitAlert = false
    @State private var toastTimer: Timer? = nil

    @FocusState private var fieldFocused: Bool

    init(urlInput: String = "") {
        self._urlInput = State(initialValue: urlInput)
        self._result = State(initialValue: nil)
    }

    fileprivate init(urlInput: String, result: CheckResult?) {
        self._urlInput = State(initialValue: urlInput)
        self._result = State(initialValue: result)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        inputSection

                        if let r = result {
                            resultContent(r)
                                .opacity(resultOpacity)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 48)
                }
                .scrollDismissesKeyboard(.interactively)

                if showSavedToast {
                    CheckToast(message: "Site saved")
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(2)
                }
            }
            .navigationTitle("Check")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.22), value: showSavedToast)
            .alert("Save limit reached", isPresented: $showLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Free accounts can save up to 3 sites. Upgrade to Pro for $4.99 in Settings.")
            }
        }
    }

    // MARK: Input Section

    private var inputSection: some View {
        VStack(spacing: 12) {
            TextField("Enter a URL", text: $urlInput)
                #if os(iOS)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                #endif
                .autocorrectionDisabled()
                .font(.system(size: 16))
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(Color.checkSecondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .focused($fieldFocused)
                .onChange(of: urlInput) { _, _ in
                    guard result != nil, !isClearing else { return }
                    isClearing = true
                    withAnimation(.easeOut(duration: 0.18)) { resultOpacity = 0 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                        result = nil
                        isSaved = false
                        resultOpacity = 1
                        isClearing = false
                    }
                }

            Button(action: runCheck) {
                Group {
                    if isChecking {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.75)
                                .tint(.white)
                            Text("Checking…")
                        }
                    } else {
                        Text("Quick Check")
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    urlInput.trimmingCharacters(in: .whitespaces).isEmpty || isChecking
                        ? Color.accentColor.opacity(0.4)
                        : Color.accentColor
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isChecking || urlInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.bottom, 8)
    }

    // MARK: Result Content

    @ViewBuilder
    private func resultContent(_ r: CheckResult) -> some View {
        VStack(spacing: 0) {
            CSSeparator()

            // 3. Tracking Signals
            CSSectionHeader("Tracking Signals")
            TrackingSignalRow(name: "GA4", status: r.signals?.ga4 ?? .checkFailed)
            CSRowDivider()
            TrackingSignalRow(name: "GTM", status: r.signals?.gtm ?? .checkFailed)
            CSRowDivider()
            TrackingSignalRow(name: "Ads", status: r.signals?.ads ?? .checkFailed)

            CSSeparator()

            // 4. Check Status
            CSSectionHeader("Check Status")
            HStack {
                Spacer()
                StatusPill(status: r.aggregate)
            }
            .frame(minHeight: 36)
            if let reason = r.failureReason {
                CSRowDivider()
                CSInfoRow(label: "Reason", value: reason.rawValue)
            }

            CSSeparator()

            // 5. Last Checked
            CSSectionHeader("Last Checked")
            CSInfoRow(
                label: nil,
                value: r.checkedAt.formatted(date: .abbreviated, time: .shortened)
            )

            CSSeparator()

            // 6. Checked URL
            CSSectionHeader("Checked URL")
            CSInfoRow(label: nil, value: r.checkedURL)

            CSSeparator()

            // 7. Opened Page
            CSSectionHeader("Opened Page")
            CSInfoRow(label: nil, value: r.openedPage)

            CSSeparator()

            // 8. View Details
            ViewDetailsRow(data: makeDetailsData(from: r))

            // 9. Save Site / Saved / Upgrade CTA
            let alreadySaved = savedNormalizedURLs.contains(URLNormalizer.normalize(r.checkedURL))
            let atFreeLimit = !isPro && savedNormalizedURLs.count >= 3
            if isSaved || r.isSuccess {
                CSSeparator()
                if r.isSuccess && !alreadySaved && !isSaved && atFreeLimit {
                    SaveLimitUpgradeCTA()
                        .padding(.vertical, 4)
                } else {
                    SaveSiteButton(isSaved: isSaved || alreadySaved, onSave: saveSite)
                        .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: Actions

    private func runCheck() {
        let trimmed = urlInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        fieldFocused = false
        isChecking = true
        isSaved = false
        result = nil

        Task {
            let r = await fetchAndCheck(input: trimmed)
            result = r
            isChecking = false
            let normalized = URLNormalizer.normalize(trimmed)
            if savedNormalizedURLs.contains(normalized) {
                updateSiteAction(SavedSite(
                    rawURL: normalized,
                    status: r.aggregate,
                    ga4: r.signals?.ga4 ?? .checkFailed,
                    gtm: r.signals?.gtm ?? .checkFailed,
                    ads: r.signals?.ads ?? .checkFailed,
                    detectedIDs: r.detectedIDs,
                    checkedURL: r.checkedURL,
                    openedPage: r.openedPage
                ))
            }
        }
    }

    private func saveSite() {
        guard !isSaved, let r = result else { return }
        if !isPro && savedNormalizedURLs.count >= 3 {
            showLimitAlert = true
            return
        }
        isSaved = true
        onSave(SavedSite(
            rawURL: r.checkedURL,
            status: r.aggregate,
            ga4: r.signals?.ga4 ?? .checkFailed,
            gtm: r.signals?.gtm ?? .checkFailed,
            ads: r.signals?.ads ?? .checkFailed,
            detectedIDs: r.detectedIDs,
            checkedURL: r.checkedURL,
            openedPage: r.openedPage
        ))
        toastTimer?.invalidate()
        withAnimation { showSavedToast = true }
        toastTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { _ in
            withAnimation { showSavedToast = false }
        }
    }

    private func makeDetailsData(from r: CheckResult) -> DetailsData {
        let signals: DetailsData.Signals
        if let s = r.signals {
            signals = DetailsData.Signals(ga4: s.ga4, gtm: s.gtm, ads: s.ads)
        } else {
            signals = DetailsData.Signals(ga4: .checkFailed, gtm: .checkFailed, ads: .checkFailed)
        }
        return DetailsData(
            signals: signals,
            detectedIDs: r.detectedIDs,
            checkedURL: r.checkedURL,
            openedPage: r.openedPage,
            checkedAt: r.checkedAt,
            changesSummary: nil
        )
    }

}

// MARK: - Fetch + Detection

typealias PageFetcher = (URLRequest) async throws -> (Data, URLResponse)

func fetchAndCheck(input: String) async -> CheckResult {
    await fetchAndCheck(input: input, fetcher: { try await URLSession.shared.data(for: $0) })
}

func fetchAndCheck(input: String, fetcher: PageFetcher) async -> CheckResult {
    let rawWithScheme = input.lowercased().hasPrefix("http://") || input.lowercased().hasPrefix("https://")
        ? input
        : "https://\(input)"

    guard let url = URL(string: rawWithScheme),
          let host = url.host, host.contains(".") else {
        return CheckResult(outcome: .failure(.invalidURL), checkedURL: input, openedPage: input)
    }

    var request = URLRequest(url: url, timeoutInterval: 15)
    request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

    let checkedURL = URLNormalizer.normalize(input)
    do {
        let (data, response) = try await fetcher(request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...399).contains(httpResponse.statusCode) else {
            return CheckResult(outcome: .failure(.couldntLoad), checkedURL: checkedURL, openedPage: checkedURL)
        }
        let openedPage = httpResponse.url.map { URLNormalizer.normalize($0.absoluteString) } ?? checkedURL
        let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        let (signals, detectedIDs) = detectSignals(in: html)
        return CheckResult(outcome: .success(signals), checkedURL: checkedURL, openedPage: openedPage, detectedIDs: detectedIDs)
    } catch let error as URLError {
        let reason: CheckFailureReason
        switch error.code {
        case .timedOut:
            reason = .timedOut
        case .badURL, .unsupportedURL:
            reason = .invalidURL
        default:
            reason = .couldntLoad
        }
        return CheckResult(outcome: .failure(reason), checkedURL: checkedURL, openedPage: checkedURL)
    } catch {
        return CheckResult(outcome: .failure(.couldntLoad), checkedURL: checkedURL, openedPage: checkedURL)
    }
}

func detectSignals(in html: String) -> (TrackingSignals, [DetectedID]) {
    var ids: [DetectedID] = []
    let ga4 = detectGA4(in: html, ids: &ids)
    let gtm = detectGTM(in: html, ids: &ids)
    let ads = detectAds(in: html, ids: &ids)
    return (TrackingSignals(ga4: ga4, gtm: gtm, ads: ads), ids)
}

private func extractMatches(_ pattern: String, in text: String) -> [String] {
    guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
    let ns = text as NSString
    return re.matches(in: text, range: NSRange(location: 0, length: ns.length))
        .map { ns.substring(with: $0.range) }
}

private func detectGA4(in html: String, ids: inout [DetectedID]) -> SiteStatus {
    let found = Array(Set(extractMatches("G-[A-Z0-9]{4,}", in: html)))
    guard !found.isEmpty else { return .notDetected }
    for id in found { ids.append(DetectedID(category: .ga4, value: id)) }
    let isDetected = found.contains { id in
        html.contains("gtag/js?id=\(id)") ||
        html.contains("gtag('config', '\(id)')") ||
        html.contains("gtag(\"config\", \"\(id)\")")
    }
    return isDetected ? .detected : .possible
}

private func detectGTM(in html: String, ids: inout [DetectedID]) -> SiteStatus {
    let found = Array(Set(extractMatches("GTM-[A-Z0-9]{4,}", in: html)))
    guard !found.isEmpty else { return .notDetected }
    for id in found { ids.append(DetectedID(category: .gtm, value: id)) }
    let isDetected = found.contains { id in
        html.contains("googletagmanager.com/gtm.js?id=\(id)")
    }
    return isDetected ? .detected : .possible
}

private func detectAds(in html: String, ids: inout [DetectedID]) -> SiteStatus {
    let found = Array(Set(extractMatches("AW-[0-9]{4,}", in: html)))
    guard !found.isEmpty else { return .notDetected }
    for id in found { ids.append(DetectedID(category: .ads, value: id)) }
    let isDetected = found.contains { id in
        html.contains("gtag('config', '\(id)')") ||
        html.contains("gtag(\"config\", \"\(id)\")")
    }
    return isDetected ? .detected : .possible
}

// MARK: - Sub-components

private struct CSSeparator: View {
    var body: some View { Divider().padding(.vertical, 8) }
}

private struct CSRowDivider: View {
    var body: some View { Divider().padding(.leading, 0) }
}

private struct CSSectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.bottom, 4)
    }
}

private struct CSInfoRow: View {
    let label: String?
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let label {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.trailing)
            } else {
                Text(value)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minHeight: 36)
    }
}

private struct TrackingSignalRow: View {
    let name: String
    let status: SiteStatus

    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 15))
                .foregroundColor(.primary)
            Spacer(minLength: 12)
            StatusPill(status: status)
        }
        .frame(minHeight: 44)
    }
}

private struct ViewDetailsRow: View {
    let data: DetailsData

    var body: some View {
        NavigationLink(destination: DetailsScreen(data: data)) {
            HStack {
                Text("View Details")
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.checkTertiaryLabel)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SaveSiteButton: View {
    let isSaved: Bool
    let onSave: () -> Void

    var body: some View {
        Button(action: onSave) {
            HStack(spacing: 6) {
                if isSaved {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(isSaved ? "Saved" : "Save Site")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(isSaved ? .secondary : Color.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.checkSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isSaved)
    }
}

private struct SaveLimitUpgradeCTA: View {
    @Environment(\.upgradeAction) private var upgradeAction
    @State private var isUpgrading = false
    @State private var showUnavailableAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Free plan includes up to 3 saved sites.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text("Upgrade to Pro for $4.99.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Button {
                guard !isUpgrading else { return }
                isUpgrading = true
                Task {
                    let available = await upgradeAction()
                    if !available { showUnavailableAlert = true }
                    isUpgrading = false
                }
            } label: {
                Text("Upgrade")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isUpgrading ? .secondary : Color.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.checkSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(isUpgrading)
        }
        .alert("Upgrade", isPresented: $showUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("In-app purchase isn't available yet. Check back soon.")
        }
    }
}

private extension Color {
    static var checkSecondaryBackground: Color {
        #if os(iOS)
        Color(uiColor: .secondarySystemBackground)
        #else
        Color.gray.opacity(0.12)
        #endif
    }

    static var checkTertiaryLabel: Color {
        #if os(iOS)
        Color(uiColor: .tertiaryLabel)
        #else
        Color.secondary.opacity(0.55)
        #endif
    }
}

struct CheckToast: View {
    let message: String

    var body: some View {
        HStack {
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - Previews

#Preview("Initial State") {
    CheckScreen()
}

#Preview("Result — Success (mixed signals)") {
    CheckScreen(
        urlInput: "example.com",
        result: CheckResult(
            outcome: .success(TrackingSignals(
                ga4: .detected,
                gtm: .detected,
                ads: .possible
            )),
            checkedURL: "example.com",
            openedPage: "example.com"
        )
    )
}

#Preview("Result — Failed") {
    CheckScreen(
        urlInput: "broken-site",
        result: CheckResult(
            outcome: .failure(.couldntLoad),
            checkedURL: "broken-site",
            openedPage: "broken-site"
        )
    )
}
