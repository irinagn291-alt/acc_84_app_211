import Combine
import SwiftData
import SwiftUI

enum VerdantTab: Int, CaseIterable, Identifiable {
    case scan
    case explore
    case shelf
    case plan

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .scan: "Scan"
        case .explore: "Explore"
        case .shelf: "Shelf"
        case .plan: "Plan"
        }
    }

    var icon: String {
        switch self {
        case .scan: "qrcode.viewfinder"
        case .explore: "magnifyingglass"
        case .shelf: "books.vertical.fill"
        case .plan: "calendar"
        }
    }
}

@MainActor
final class VerdantTabOrchestrator: ObservableObject {
    @Published var selectedTab: VerdantTab = .scan
    @Published var scanPath = NavigationPath()
    @Published var explorePath = NavigationPath()
    @Published var shelfPath = NavigationPath()
    @Published var planPath = NavigationPath()
    @Published var isLensPresented = false
    @Published var isPrefsPresented = false
    @Published var pendingBarcode: String?

    func openItem(barcode: String, from tab: VerdantTab? = nil) {
        let code = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        if let tab { selectedTab = tab }
        switch selectedTab {
        case .scan:
            scanPath.append(code)
        case .explore:
            explorePath.append(code)
        case .shelf:
            shelfPath.append(code)
        case .plan:
            planPath.append(code)
        }
    }

    func handleScannedCode(_ raw: String) {
        isLensPresented = false
        guard let code = VPScannedCodeNormalizer.canonicalProductCode(raw) else {
            pendingBarcode = raw
            return
        }
        selectedTab = .scan
        scanPath.append(code)
    }
}

@MainActor
final class VerdantWorkbench: ObservableObject {
    let vault: VerdantVaultStore
    let gateway: VerdantOFFGateway
    let cautionEngine: VerdantCautionEngine
    let reachability: VerdantReachability
    let orchestrator: VerdantTabOrchestrator

    init(context: ModelContext) {
        let gw = VerdantOFFGateway()
        self.gateway = gw
        self.vault = VerdantVaultStore(context: context, gateway: gw)
        self.cautionEngine = VerdantCautionEngine()
        self.reachability = VerdantReachability()
        self.orchestrator = VerdantTabOrchestrator()
        reachability.begin()
        URLCache.shared = URLCache(memoryCapacity: 50 * 1_024 * 1_024, diskCapacity: 200 * 1_024 * 1_024)
    }
}
