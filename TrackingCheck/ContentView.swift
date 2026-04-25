import StoreKit
import SwiftUI

private struct SaveSiteActionKey: EnvironmentKey {
    static let defaultValue: (SavedSite) -> Void = { _ in }
}

private struct SavedNormalizedURLsKey: EnvironmentKey {
    static let defaultValue: Set<String> = []
}

private struct UpdateSiteActionKey: EnvironmentKey {
    static let defaultValue: (SavedSite) -> Void = { _ in }
}

private struct IsProKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

private struct UpgradeActionKey: EnvironmentKey {
    // Returns true when a product was available and the purchase flow was initiated;
    // false means no product — caller should show a fallback.
    static let defaultValue: () async -> Bool = { false }
}

private struct RestoreActionKey: EnvironmentKey {
    // Returns true when a valid entitlement was found; false means nothing to restore.
    static let defaultValue: () async -> Bool = { false }
}

extension EnvironmentValues {
    var saveSiteAction: (SavedSite) -> Void {
        get { self[SaveSiteActionKey.self] }
        set { self[SaveSiteActionKey.self] = newValue }
    }

    var savedNormalizedURLs: Set<String> {
        get { self[SavedNormalizedURLsKey.self] }
        set { self[SavedNormalizedURLsKey.self] = newValue }
    }

    var updateSiteAction: (SavedSite) -> Void {
        get { self[UpdateSiteActionKey.self] }
        set { self[UpdateSiteActionKey.self] = newValue }
    }

    var isPro: Bool {
        get { self[IsProKey.self] }
        set { self[IsProKey.self] = newValue }
    }

    var upgradeAction: () async -> Bool {
        get { self[UpgradeActionKey.self] }
        set { self[UpgradeActionKey.self] = newValue }
    }

    var restoreAction: () async -> Bool {
        get { self[RestoreActionKey.self] }
        set { self[RestoreActionKey.self] = newValue }
    }
}

private let sitesDefaultsKey = "com.auditools.TrackingCheck.savedSites"

private func loadSites() -> [SavedSite] {
    guard let data = UserDefaults.standard.data(forKey: sitesDefaultsKey),
          let decoded = try? JSONDecoder().decode([SavedSite].self, from: data) else {
        return []
    }
    return decoded
}

func applySiteUpdate(_ updated: SavedSite, to sites: [SavedSite]) -> [SavedSite] {
    guard let idx = sites.firstIndex(where: { $0.normalizedURL == updated.normalizedURL }) else { return sites }
    var site = sites[idx]
    site.status = updated.status
    site.ga4 = updated.ga4
    site.gtm = updated.gtm
    site.ads = updated.ads
    site.detectedIDs = updated.detectedIDs
    site.checkedURL = updated.checkedURL
    site.openedPage = updated.openedPage
    site.lastTouched = updated.lastTouched
    var result = sites
    result.remove(at: idx)
    result.insert(site, at: 0)
    return result
}

struct ContentView: View {
    @State private var sites: [SavedSite] = loadSites()
    @State private var isPro = false
    @State private var upgradeProduct: Product? = nil

    var body: some View {
        HomeSitesScreen(sites: $sites)
            .environment(\.saveSiteAction, { site in
                sites.insert(site, at: 0)
            })
            .environment(\.savedNormalizedURLs, Set(sites.map(\.normalizedURL)))
            .environment(\.updateSiteAction, { updated in
                sites = applySiteUpdate(updated, to: sites)
            })
            .environment(\.isPro, isPro)
            .environment(\.upgradeAction, {
                guard let product = upgradeProduct else { return false }
                let success = await purchase(product)
                if success { isPro = true }
                return true
            })
            .environment(\.restoreAction, {
                let found = await restoreEntitlement()
                if found { isPro = true }
                return found
            })
            .task {
                upgradeProduct = await loadUpgradeProduct()
            }
            .task {
                if await restoreEntitlement() { isPro = true }
            }
            .task {
                for await result in Transaction.updates {
                    if case .verified(let transaction) = result,
                       transaction.productID == upgradeProductID {
                        isPro = true
                        await transaction.finish()
                    }
                }
            }
            .onChange(of: sites) { _, newSites in
                if let data = try? JSONEncoder().encode(newSites) {
                    UserDefaults.standard.set(data, forKey: sitesDefaultsKey)
                }
            }
    }
}

#Preview {
    ContentView()
}
