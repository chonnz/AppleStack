import Foundation

enum DetailStateStore {
    private static let selectedTabPrefix = "appleStack.detail.selectedTab."

    static func selectedTab(for detailKey: String) -> String? {
        UserDefaults.standard.string(forKey: selectedTabPrefix + detailKey)
    }

    static func setSelectedTab(_ tab: String, for detailKey: String) {
        UserDefaults.standard.set(tab, forKey: selectedTabPrefix + detailKey)
    }
}
