import SwiftUI

// MARK: - Details Screen Models

struct DetectedID: Identifiable, Codable, Equatable {
    enum Category: String, Codable {
        case ga4 = "GA4"
        case gtm = "GTM"
        case ads = "Ads"
    }
    let id = UUID()
    let category: Category
    let value: String

    // Exclude id from coding — a fresh UUID is generated on decode, which is fine
    // since id is only used for SwiftUI Identifiable within a session.
    enum CodingKeys: String, CodingKey { case category, value }
}

struct DetailsData {
    struct Signals {
        var ga4: SiteStatus
        var gtm: SiteStatus
        var ads: SiteStatus
    }
    var signals: Signals
    /// Only detected categories, in caller-supplied order (screen re-sorts to GA4 → GTM → Ads)
    var detectedIDs: [DetectedID]
    var checkedURL: String
    var openedPage: String
    var checkedAt: Date = .now
    /// nil = no previous result; non-nil = summary change strings (may be empty)
    var changesSummary: [String]?
}

// MARK: - Details Screen

struct DetailsScreen: View {
    private let data: DetailsData
    @Environment(\.updateSiteAction) private var updateSiteAction
    @Environment(\.savedNormalizedURLs) private var savedNormalizedURLs
    @Environment(\.isPro) private var isPro
    @State private var liveSignals: DetailsData.Signals
    @State private var liveIDs: [DetectedID]
    @State private var liveOpenedPage: String
    @State private var liveCheckedAt: Date
    @State private var liveChangesSummary: [String]?

    init() {
        let d = sampleDetailsData
        self.data = d
        self._liveSignals = State(initialValue: d.signals)
        self._liveIDs = State(initialValue: d.detectedIDs)
        self._liveOpenedPage = State(initialValue: d.openedPage)
        self._liveCheckedAt = State(initialValue: d.checkedAt)
        self._liveChangesSummary = State(initialValue: d.changesSummary)
    }

    init(data: DetailsData) {
        self.data = data
        self._liveSignals = State(initialValue: data.signals)
        self._liveIDs = State(initialValue: data.detectedIDs)
        self._liveOpenedPage = State(initialValue: data.openedPage)
        self._liveCheckedAt = State(initialValue: data.checkedAt)
        self._liveChangesSummary = State(initialValue: data.changesSummary)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                DSSeparator()

                // 1. Detected Signals
                DSSectionHeader("Detected Signals")
                DSSignalRow(name: "GA4", status: liveSignals.ga4)
                DSRowDivider()
                DSSignalRow(name: "GTM", status: liveSignals.gtm)
                DSRowDivider()
                DSSignalRow(name: "Ads", status: liveSignals.ads)

                DSSeparator()

                // 2. Detected IDs
                DSSectionHeader("Detected IDs")
                detectedIDsContent

                DSSeparator()

                // 3. Checked URL
                DSSectionHeader("Checked URL")
                DSInfoText(data.checkedURL)

                DSSeparator()

                // 4. Opened Page
                DSSectionHeader("Opened Page")
                DSInfoText(liveOpenedPage)

                DSSeparator()

                // 5. Changes Since Last Check
                DSSectionHeader("Changes Since Last Check")
                changesContent

                DSSeparator()

                // 6. Check Again
                DSCheckAgainButton(
                    checkedURL: data.checkedURL,
                    onResult: { newSignals, newIDs, newOpenedPage in
                        liveChangesSummary = isPro
                            ? detailsDetailedDiff(
                                oldSignals: liveSignals, oldPage: liveOpenedPage,
                                newSignals: newSignals, newPage: newOpenedPage)
                            : detailsDiff(
                                oldSignals: liveSignals, oldPage: liveOpenedPage,
                                newSignals: newSignals, newPage: newOpenedPage)
                        liveSignals = newSignals
                        liveIDs = newIDs
                        liveOpenedPage = newOpenedPage
                        liveCheckedAt = .now
                        if savedNormalizedURLs.contains(data.checkedURL) {
                            updateSiteAction(SavedSite(
                                rawURL: data.checkedURL,
                                status: detailsAggregate(newSignals),
                                ga4: newSignals.ga4,
                                gtm: newSignals.gtm,
                                ads: newSignals.ads,
                                detectedIDs: newIDs,
                                checkedURL: data.checkedURL,
                                openedPage: newOpenedPage
                            ))
                        }
                    }
                )
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .navigationTitle(data.checkedURL.isEmpty ? "Details" : data.checkedURL)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Dynamic sections

    @ViewBuilder
    private var detectedIDsContent: some View {
        let ordered = orderedIDs
        if ordered.isEmpty {
            DSNoteRow("No IDs detected")
        } else {
            ForEach(Array(ordered.enumerated()), id: \.element.id) { i, item in
                if i > 0 { DSRowDivider() }
                DSDetectedIDRow(item: item)
            }
        }
    }

    @ViewBuilder
    private var changesContent: some View {
        if let summary = liveChangesSummary {
            if summary.isEmpty {
                DSNoteRow("No changes detected")
            } else {
                ForEach(Array(summary.enumerated()), id: \.offset) { i, change in
                    if i > 0 { DSRowDivider() }
                    DSInfoText(change)
                }
            }
        } else {
            DSNoteRow("No previous result to compare")
        }
        Text("Last checked: \(liveCheckedAt.formatted(date: .abbreviated, time: .standard))")
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
    }

    private var orderedIDs: [DetectedID] {
        [DetectedID.Category.ga4, .gtm, .ads].flatMap { cat in
            liveIDs.filter { $0.category == cat }
        }
    }
}

// MARK: - Change Summary Helpers

private func detailsAggregate(_ s: DetailsData.Signals) -> SiteStatus {
    let all = [s.ga4, s.gtm, s.ads]
    if all.contains(.detected) { return .detected }
    if all.contains(.possible) { return .possible }
    if all.contains(.checkFailed) { return .checkFailed }
    return .notDetected
}

func detailsDiff(oldSignals: DetailsData.Signals, oldPage: String,
                  newSignals: DetailsData.Signals, newPage: String) -> [String] {
    var lines: [String] = []
    if oldSignals.ga4 != newSignals.ga4 || oldSignals.gtm != newSignals.gtm || oldSignals.ads != newSignals.ads {
        lines.append("Signal status changed")
    }
    if oldPage != newPage {
        lines.append("Opened page changed")
    }
    if detailsAggregate(oldSignals) != detailsAggregate(newSignals) {
        lines.append("Check status changed")
    }
    return lines
}

func detailsDetailedDiff(oldSignals: DetailsData.Signals, oldPage: String,
                          newSignals: DetailsData.Signals, newPage: String) -> [String] {
    var lines: [String] = []
    if oldSignals.ga4 != newSignals.ga4 {
        lines.append("GA4: \(oldSignals.ga4.rawValue) → \(newSignals.ga4.rawValue)")
    }
    if oldSignals.gtm != newSignals.gtm {
        lines.append("GTM: \(oldSignals.gtm.rawValue) → \(newSignals.gtm.rawValue)")
    }
    if oldSignals.ads != newSignals.ads {
        lines.append("Ads: \(oldSignals.ads.rawValue) → \(newSignals.ads.rawValue)")
    }
    if oldPage != newPage {
        lines.append("Opened page: \(oldPage) → \(newPage)")
    }
    return lines
}

// MARK: - Sub-components

private struct DSSeparator: View {
    var body: some View { Divider().padding(.vertical, 8) }
}

private struct DSRowDivider: View {
    var body: some View { Divider() }
}

private struct DSSectionHeader: View {
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

private struct DSSignalRow: View {
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

private struct DSDetectedIDRow: View {
    let item: DetectedID
    @State private var copied = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.category.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Text(item.value)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
            }
            Spacer()
            Button(action: copyID) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 14))
                    .foregroundColor(copied ? Color(red: 0.08, green: 0.40, blue: 0.20) : .secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 52)
    }

    private func copyID() {
        #if os(iOS)
        UIPasteboard.general.string = item.value
        #endif
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copied = false }
        }
    }
}

private struct DSInfoText: View {
    let value: String
    init(_ value: String) { self.value = value }

    var body: some View {
        Text(value)
            .font(.system(size: 15))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 36)
    }
}

private struct DSNoteRow: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 36)
    }
}

private struct DSCheckAgainButton: View {
    let checkedURL: String
    let onResult: (DetailsData.Signals, [DetectedID], String) -> Void
    @State private var isChecking = false

    var body: some View {
        Button {
            guard !isChecking else { return }
            isChecking = true
            Task {
                let r = await fetchAndCheck(input: checkedURL)
                switch r.outcome {
                case .success(let s):
                    onResult(DetailsData.Signals(ga4: s.ga4, gtm: s.gtm, ads: s.ads), r.detectedIDs, r.openedPage)
                case .failure:
                    onResult(DetailsData.Signals(ga4: .checkFailed, gtm: .checkFailed, ads: .checkFailed), [], r.openedPage)
                }
                isChecking = false
            }
        } label: {
            Group {
                if isChecking {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.75)
                            .tint(Color(red: 0.15, green: 0.35, blue: 0.80))
                        Text("Checking…")
                    }
                } else {
                    Text("Check Again")
                }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Color(red: 0.15, green: 0.35, blue: 0.80))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color(red: 0.90, green: 0.94, blue: 1.00))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(red: 0.55, green: 0.70, blue: 0.95), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isChecking)
    }
}

// MARK: - Sample Data

private let sampleDetailsData = DetailsData(
    signals: DetailsData.Signals(ga4: .detected, gtm: .detected, ads: .possible),
    detectedIDs: [
        DetectedID(category: .ga4, value: "G-1234567890"),
        DetectedID(category: .gtm, value: "GTM-ABCDEF1"),
        DetectedID(category: .ads, value: "AW-9876543210"),
    ],
    checkedURL: "example.com/pricing",
    openedPage: "example.com/pricing",
    changesSummary: ["Signal status changed", "Opened page changed"]
)

// MARK: - Previews

#Preview("Full Result") {
    NavigationStack {
        DetailsScreen(data: sampleDetailsData)
    }
}

#Preview("First Check — No Previous Result") {
    NavigationStack {
        DetailsScreen(data: DetailsData(
            signals: DetailsData.Signals(ga4: .detected, gtm: .detected, ads: .notDetected),
            detectedIDs: [
                DetectedID(category: .ga4, value: "G-0987654321"),
                DetectedID(category: .gtm, value: "GTM-XYZ1234"),
            ],
            checkedURL: "example.com",
            openedPage: "example.com",
            changesSummary: nil
        ))
    }
}

#Preview("Nothing Detected") {
    NavigationStack {
        DetailsScreen(data: DetailsData(
            signals: DetailsData.Signals(ga4: .notDetected, gtm: .notDetected, ads: .notDetected),
            detectedIDs: [],
            checkedURL: "example.com/simple",
            openedPage: "example.com/simple",
            changesSummary: ["Check status changed"]
        ))
    }
}
