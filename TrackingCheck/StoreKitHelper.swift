import StoreKit

// Must match the product ID configured in App Store Connect / StoreKit configuration file.
let upgradeProductID = "com.akashi.TrackingCheck.pro"

func loadUpgradeProduct() async -> Product? {
    do {
        let products = try await Product.products(for: [upgradeProductID])
        if products.isEmpty {
            print("[StoreKit] loadUpgradeProduct: succeeded but no products returned for '\(upgradeProductID)'")
            return nil
        }
        print("[StoreKit] loadUpgradeProduct: loaded '\(products[0].id)' — \(products[0].displayName)")
        return products.first
    } catch {
        print("[StoreKit] loadUpgradeProduct: threw error — \(error)")
        return nil
    }
}

/// Checks current entitlements for the upgrade product. Returns true if a verified entitlement exists.
func restoreEntitlement() async -> Bool {
    for await result in Transaction.currentEntitlements {
        if case .verified(let transaction) = result,
           transaction.productID == upgradeProductID {
            return true
        }
    }
    return false
}

/// Attempts a StoreKit 2 purchase. Returns true only on verified success.
func purchase(_ product: Product) async -> Bool {
    guard let result = try? await product.purchase() else { return false }
    guard case .success(let verification) = result else { return false }
    guard case .verified(let transaction) = verification else { return false }
    await transaction.finish()
    return true
}
