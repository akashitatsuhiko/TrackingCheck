import SwiftUI

// MARK: - Models

enum SiteStatus: String, Codable {
    case detected = "Detected"
    case possible = "Possible"
    case notDetected = "Not detected"
    case checkFailed = "Check failed"
}

struct SavedSite: Identifiable, Codable, Equatable {
    let id: UUID
    var normalizedURL: String
    var displayURL: String
    var status: SiteStatus
    var lastTouched: Date
    var ga4: SiteStatus
    var gtm: SiteStatus
    var ads: SiteStatus
    var detectedIDs: [DetectedID]
    var checkedURL: String
    var openedPage: String

    /// Lightweight init for sample/preview data. Sets all signals to the aggregate status.
    init(rawURL: String, status: SiteStatus) {
        self.id = UUID()
        self.normalizedURL = URLNormalizer.normalize(rawURL)
        self.displayURL = URLNormalizer.display(rawURL)
        self.status = status
        self.lastTouched = Date()
        self.ga4 = status
        self.gtm = status
        self.ads = status
        self.detectedIDs = []
        self.checkedURL = URLNormalizer.normalize(rawURL)
        self.openedPage = URLNormalizer.normalize(rawURL)
    }

    /// Full init used when saving a real check result.
    init(rawURL: String, status: SiteStatus, ga4: SiteStatus, gtm: SiteStatus, ads: SiteStatus,
         detectedIDs: [DetectedID], checkedURL: String, openedPage: String) {
        self.id = UUID()
        self.normalizedURL = URLNormalizer.normalize(rawURL)
        self.displayURL = URLNormalizer.display(rawURL)
        self.status = status
        self.lastTouched = Date()
        self.ga4 = ga4
        self.gtm = gtm
        self.ads = ads
        self.detectedIDs = detectedIDs
        self.checkedURL = checkedURL
        self.openedPage = openedPage
    }
}

// MARK: - URL Normalizer

enum URLNormalizer {
    /// Returns a canonical key used for duplicate detection.
    /// Strips protocol, query, hash, trailing slash. Keeps path.
    static func normalize(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespaces)
        // Strip protocol
        for prefix in ["https://", "http://"] {
            if s.lowercased().hasPrefix(prefix) {
                s = String(s.dropFirst(prefix.count))
                break
            }
        }
        // Strip query and hash
        if let r = s.range(of: "?") { s = String(s[s.startIndex..<r.lowerBound]) }
        if let r = s.range(of: "#") { s = String(s[s.startIndex..<r.lowerBound]) }
        // Strip trailing slash
        while s.hasSuffix("/") { s = String(s.dropLast()) }
        return s.lowercased()
    }

    /// Returns the string to display in list rows.
    /// Uses the same normalization as `normalize(_:)` so display is consistent with saved identity.
    static func display(_ raw: String) -> String {
        normalize(raw)
    }
}

// MARK: - Status Pill

struct StatusPill: View {
    let status: SiteStatus

    var body: some View {
        Text(status.rawValue)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(Capsule())
    }

    private var foreground: Color {
        switch status {
        case .detected:    return Color(red: 0.08, green: 0.40, blue: 0.20)
        case .possible:    return Color(red: 0.15, green: 0.35, blue: 0.60)
        case .notDetected: return Color(red: 0.44, green: 0.44, blue: 0.48)
        case .checkFailed: return Color(red: 0.55, green: 0.18, blue: 0.18)
        }
    }

    private var background: Color {
        switch status {
        case .detected:    return Color(red: 0.88, green: 0.96, blue: 0.90)
        case .possible:    return Color(red: 0.88, green: 0.93, blue: 0.98)
        case .notDetected: return Color(red: 0.93, green: 0.93, blue: 0.94)
        case .checkFailed: return Color(red: 0.97, green: 0.90, blue: 0.90)
        }
    }
}

// MARK: - Site Row

struct SiteRow: View {
    let site: SavedSite

    var body: some View {
        HStack {
            Text(site.displayURL)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 12)
            StatusPill(status: site.status)
        }
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

// MARK: - Empty State

struct EmptySitesState: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            GlobeCheckIllustration()
            VStack(spacing: 6) {
                Text("No saved sites yet")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                Text("Start a quick check with the +")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
    }
}

// MARK: - Illustration (minimal SwiftUI shapes, no external assets)

struct GlobeCheckIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1.5)
                .frame(width: 64, height: 64)
            // Horizontal equator arc
            Ellipse()
                .stroke(Color.secondary.opacity(0.20), lineWidth: 1)
                .frame(width: 64, height: 22)
            // Vertical meridian arc
            Ellipse()
                .stroke(Color.secondary.opacity(0.20), lineWidth: 1)
                .frame(width: 22, height: 64)
            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(Color.secondary.opacity(0.55))
        }
        .frame(width: 72, height: 72)
    }
}

// MARK: - Floating Add Button

struct FloatingAddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Delete Toast

struct DeleteToast: View {
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Text("Site deleted")
                .font(.system(size: 14))
                .foregroundColor(.white)
            Spacer()
            Button("Undo", action: onUndo)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(white: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

// MARK: - Save Limit Notice

struct SaveLimitNotice: View {
    @Environment(\.upgradeAction) private var upgradeAction
    @State private var isUpgrading = false

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Free plan includes up to 3 saved sites.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                Text("Upgrade to Pro for $4.99.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 8)
            Button("Upgrade") {
                guard !isUpgrading else { return }
                isUpgrading = true
                Task {
                    _ = await upgradeAction()
                    isUpgrading = false
                }
            }
            .font(.system(size: 13, weight: .medium))
            .disabled(isUpgrading)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Home / Sites Screen

struct HomeSitesScreen: View {
    @Binding var sites: [SavedSite]
    @Environment(\.isPro) private var isPro
    @State private var showCheckSheet = false
    @State private var showSettings = false
    @State private var showToast = false
    @State private var deletedSite: SavedSite? = nil
    @State private var deletedIndex: Int? = nil
    @State private var toastTimer: Timer? = nil

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Group {
                    if sites.isEmpty {
                        EmptySitesState()
                    } else {
                        List {
                            ForEach(sites) { site in
                                NavigationLink(destination: DetailsScreen(data: DetailsData(
                                    signals: DetailsData.Signals(ga4: site.ga4, gtm: site.gtm, ads: site.ads),
                                    detectedIDs: site.detectedIDs,
                                    checkedURL: site.checkedURL,
                                    openedPage: site.openedPage,
                                    checkedAt: site.lastTouched,
                                    changesSummary: nil
                                ))) {
                                    SiteRow(site: site)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteSite(site)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            if !isPro && sites.count >= 3 {
                                SaveLimitNotice()
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                            }
                        }
                        .listStyle(.plain)
                        .contentMargins(.top, 8, for: .scrollContent)
                        // Reserve space so the last row scrolls clear of the FAB (56pt button + 24pt bottom padding)
                        .contentMargins(.bottom, 96, for: .scrollContent)
                    }
                }

                VStack(spacing: 0) {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingAddButton {
                            showCheckSheet = true
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                    }
                }

                if showToast {
                    VStack {
                        Spacer()
                        DeleteToast(onUndo: undoDelete)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
                }
            }
            .navigationTitle("Tracking Check")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundColor(.primary)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.22), value: showToast)
            .navigationDestination(isPresented: $showSettings) {
                SettingsScreen()
            }
            .sheet(isPresented: $showCheckSheet) {
                CheckScreen()
            }
        }
    }

    // MARK: Delete + Undo

    private func deleteSite(_ site: SavedSite) {
        guard let idx = sites.firstIndex(where: { $0.id == site.id }) else { return }
        deletedSite = sites[idx]
        deletedIndex = idx
        sites.remove(at: idx)
        showToastTemporarily()
    }

    private func undoDelete() {
        guard let site = deletedSite, let idx = deletedIndex else { return }
        let insertAt = min(idx, sites.count)
        withAnimation(.easeInOut(duration: 0.28)) {
            sites.insert(site, at: insertAt)
        }
        deletedSite = nil
        deletedIndex = nil
        dismissToast()
    }

    private func showToastTemporarily() {
        toastTimer?.invalidate()
        withAnimation { showToast = true }
        toastTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: false) { _ in
            dismissToast()
        }
    }

    private func dismissToast() {
        toastTimer?.invalidate()
        withAnimation { showToast = false }
    }
}

// MARK: - Sample Data

let sampleSites: [SavedSite] = [
    SavedSite(rawURL: "https://example.com", status: .detected),
    SavedSite(rawURL: "https://example.com/pricing", status: .possible),
    SavedSite(rawURL: "https://docs.example.com/login", status: .notDetected),
    SavedSite(rawURL: "https://shop.example.com", status: .checkFailed),
]

// MARK: - Previews

#Preview("Populated") {
    @Previewable @State var sites = sampleSites
    HomeSitesScreen(sites: $sites)
}

#Preview("Empty") {
    HomeSitesScreen_Empty()
}

private struct HomeSitesScreen_Empty: View {
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                EmptySitesState()
                HStack {
                    Spacer()
                    FloatingAddButton { }
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                }
            }
            .navigationTitle("Tracking Check")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Image(systemName: "gearshape").foregroundColor(.primary)
                }
            }
        }
    }
}
