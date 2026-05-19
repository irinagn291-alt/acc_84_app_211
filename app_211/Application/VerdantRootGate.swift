import SwiftData
import SwiftUI

struct VerdantBootstrapView: View {
    @Environment(\.modelContext) private var context
    @State private var workbench: VerdantWorkbench?

    var body: some View {
        Group {
            if let workbench {
                VerdantRootGate()
                    .environmentObject(workbench)
                    .environmentObject(workbench.orchestrator)
            } else {
                VStack(spacing: VerdantPlateSkin.Pad.lg) {
                    ProgressView()
                        .tint(VerdantPlateSkin.Hues.primary)
                    Text("Loading VerdantPlate…")
                        .font(VerdantPlateSkin.TypeScale.caption)
                        .foregroundStyle(VerdantPlateSkin.Hues.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VerdantPlateSkin.Hues.background.ignoresSafeArea())
                .task {
                    guard workbench == nil else { return }
                    await Task.yield()
                    workbench = VerdantWorkbench(context: context)
                }
            }
        }
    }
}

struct VerdantRootGate: View {
    @EnvironmentObject private var workbench: VerdantWorkbench
    @State private var prefs: VerdantPrefsSnapshot?

    var body: some View {
        Group {
            if let prefs {
                if prefs.hasCompletedWelcome {
                    VerdantTabShell()
                } else {
                    VerdantWelcomeFlow(initial: prefs) { updated in
                        self.prefs = updated
                    }
                }
            } else {
                ProgressView()
                    .tint(VerdantPlateSkin.Hues.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(VerdantPlateSkin.Hues.background.ignoresSafeArea())
                    .task { reload() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .verdantPrefsChanged)) { _ in
            reload()
        }
    }

    private func reload() {
        prefs = (try? workbench.vault.fetchPrefs()) ?? .defaultValue
    }
}

struct VerdantTabShell: View {
    @EnvironmentObject private var workbench: VerdantWorkbench
    @EnvironmentObject private var orchestrator: VerdantTabOrchestrator

    var body: some View {
        VStack(spacing: 0) {
            if !workbench.reachability.isOnline {
                VPOfflineRibbon()
            }
            TabView(selection: $orchestrator.selectedTab) {
                VerdantScanPortal()
                    .tabItem { Label(VerdantTab.scan.title, systemImage: VerdantTab.scan.icon) }
                    .tag(VerdantTab.scan)

                VerdantExploreDeck()
                    .tabItem { Label(VerdantTab.explore.title, systemImage: VerdantTab.explore.icon) }
                    .tag(VerdantTab.explore)

                VerdantSavedShelf()
                    .tabItem { Label(VerdantTab.shelf.title, systemImage: VerdantTab.shelf.icon) }
                    .tag(VerdantTab.shelf)

                VerdantBasketPlanner()
                    .tabItem { Label(VerdantTab.plan.title, systemImage: VerdantTab.plan.icon) }
                    .tag(VerdantTab.plan)
            }
            .tint(VerdantPlateSkin.Hues.primary)
        }
        .sheet(isPresented: $orchestrator.isPrefsPresented) {
            VerdantPrefsPanel()
        }
        .fullScreenCover(isPresented: $orchestrator.isLensPresented) {
            VerdantLensBridge(
                onCode: { orchestrator.handleScannedCode($0) },
                onCancel: { orchestrator.isLensPresented = false }
            )
            .ignoresSafeArea()
        }
    }
}
