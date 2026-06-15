import Alamofire
import SwiftData
import SwiftUI

@main
struct app_211App: App {
    @UIApplicationDelegateAdaptor(VerdantAppDelegate.self) private var appDelegate
    @State private var isInitializing = true
    @State private var displayMode: DisplayMode = .loading
    @State private var webContentURL: String?

    private let container: ModelContainer = Self.buildContainer()

    var body: some Scene {
        WindowGroup {
            rootView
                .onAppear(perform: performRegistration)
        }
    }

    @ViewBuilder
    private var rootView: some View {
        ZStack {
            if isInitializing {
                VStack(spacing: VerdantPlateSkin.Pad.lg) {
                    ProgressView()
                        .tint(VerdantPlateSkin.Hues.primary)
                    Text("Loading VerdantPlate…")
                        .font(VerdantPlateSkin.TypeScale.caption)
                        .foregroundStyle(VerdantPlateSkin.Hues.textMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VerdantPlateSkin.Hues.background.ignoresSafeArea())
            } else if displayMode == .webContent, let url = webContentURL {
                VerdantWebContentShell(urlString: url)
            } else {
                VerdantBootstrapView()
                    .modelContainer(container)
                    .preferredColorScheme(.light)
            }
        }
    }

    private func performRegistration() {
        if let saved = DataCache.shared.contentURL, !saved.isEmpty {
            finishLaunch(mode: .webContent, url: saved)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            finishLaunch(mode: .nativeInterface, url: nil)
        }

        NetworkService.shared.performRegistration(pushToken: "") { mode, url in
            DispatchQueue.main.async {
                finishLaunch(mode: mode, url: url)
            }
        }
    }

    private func finishLaunch(mode: DisplayMode, url: String?) {
        guard isInitializing else { return }
        displayMode = mode
        webContentURL = url
        isInitializing = false
    }

    private static func buildContainer() -> ModelContainer {
        let schema = Schema([
            VPSettingsRecord.self,
            VPCachedItemRecord.self,
            VPHistoryRecord.self,
            VPFavoriteRecord.self,
            VPBasketRecord.self,
            VPBasketItemRecord.self,
        ])
        let diskConfig = ModelConfiguration(isStoredInMemoryOnly: false)
        if let c = try? ModelContainer(for: schema, configurations: [diskConfig]) { return c }
        let memConfig = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let c = try? ModelContainer(for: schema, configurations: [memConfig]) else {
            fatalError("VerdantPlate: unable to create SwiftData container")
        }
        return c
    }
}
