import UIKit

enum DemoCard: String, CaseIterable, Identifiable {
    case card1 = "iconLight"
    case card2 = "icondark"
    case card3 = "iconproaurora"
    case card4 = "iconpronight"

    private static let storageKey = "demo.selectedIcon"

    var id: String { rawValue }

    var iconName: String? {
        rawValue
    }

    var displayName: String {
        switch self {
        case .card1:
            return "Light"
        case .card2:
            return "Dark"
        case .card3:
            return "Pro Aurora"
        case .card4:
            return "Pro Night"
        }
    }

    var previewImageName: String {
        rawValue
    }

    var requiresPro: Bool {
        false
    }

    static func current() -> DemoCard {
        guard
            let rawValue = UserDefaults.standard.string(forKey: storageKey),
            let icon = DemoCard(rawValue: rawValue) ?? legacyIcon(for: rawValue)
        else {
            return .card1
        }
        return icon
    }

    private static func legacyIcon(for rawValue: String) -> DemoCard? {
        switch rawValue {
        case "Icon1":
            return .card1
        case "Icon2":
            return .card2
        case "Icon3":
            return .card3
        case "Icon4":
            return .card4
        default:
            return nil
        }
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.storageKey)
    }

    @MainActor
    func apply() async {
        save()
    }
}
