import UIKit

enum DemoCard: String, CaseIterable, Identifiable {
    case card1 = "Icon1"
    case card2 = "Icon2"
    case card3 = "Icon3"
    case card4 = "Icon4"

    private static let storageKey = "demo.selectedIcon"

    var id: String { rawValue }

    var iconName: String? {
        switch self {
        case .card1:
            return nil
        case .card2:
            return "Dark"
        case .card3:
            return "Aurora"
        case .card4:
            return "AuroraDark"
        }
    }

    var displayName: String {
        switch self {
        case .card1:
            return "Card 1"
        case .card2:
            return "Card 2"
        case .card3:
            return "Card 3"
        case .card4:
            return "Card 4"
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
            let icon = DemoCard(rawValue: rawValue)
        else {
            return .card1
        }
        return icon
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.storageKey)
    }

    @MainActor
    func apply() async {
        save()
    }
}
