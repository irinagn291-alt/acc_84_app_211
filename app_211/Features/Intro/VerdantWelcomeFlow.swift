import SwiftUI

struct VerdantWelcomeFlow: View {
    @EnvironmentObject private var workbench: VerdantWorkbench
    let initial: VerdantPrefsSnapshot
    var onComplete: (VerdantPrefsSnapshot) -> Void

    @State private var step = 0

    private let cards: [(icon: String, title: String, body: String, tint: Color)] = [
        ("qrcode.viewfinder", "Point & decode", "Aim at any product barcode or QR code. VerdantPlate pulls nutrition data from OpenFoodFacts in seconds.", VerdantPlateSkin.Hues.primaryLight),
        ("chart.bar.doc.horizontal", "Read the label", "See Nutri-Score, NOVA group, Eco-Score, and gentle cautions about sugar, salt, and processing.", VerdantPlateSkin.Hues.secondary.opacity(0.35)),
        ("tray.full.fill", "Build your shelf", "Save favorites, browse history, and plan daily baskets — cached cards work offline.", VerdantPlateSkin.Hues.primaryLight),
    ]

    var body: some View {
        ZStack {
            VerdantPlateSkin.Hues.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(VerdantPlateSkin.Hues.primary)
                    Text("VerdantPlate")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(VerdantPlateSkin.Hues.primaryDark)
                    Spacer()
                    Button("Skip") { finish() }
                        .font(VerdantPlateSkin.TypeScale.eyebrow)
                        .foregroundStyle(VerdantPlateSkin.Hues.textMuted)
                }
                .padding(.horizontal, VerdantPlateSkin.Pad.xl)
                .padding(.top, VerdantPlateSkin.Pad.lg)

                Spacer()

                let card = cards[step]
                VStack(spacing: VerdantPlateSkin.Pad.xl) {
                    ZStack {
                        RoundedRectangle(cornerRadius: VerdantPlateSkin.Corner.xl, style: .continuous)
                            .fill(card.tint)
                            .frame(width: 120, height: 120)
                            .offset(x: step == 1 ? 12 : -8, y: step == 2 ? -10 : 0)
                        Image(systemName: card.icon)
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundStyle(VerdantPlateSkin.Hues.primary)
                    }
                    Text(card.title)
                        .font(VerdantPlateSkin.TypeScale.title)
                        .foregroundStyle(VerdantPlateSkin.Hues.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(card.body)
                        .font(VerdantPlateSkin.TypeScale.body)
                        .foregroundStyle(VerdantPlateSkin.Hues.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, VerdantPlateSkin.Pad.xl)
                }

                HStack(spacing: VerdantPlateSkin.Pad.sm) {
                    ForEach(cards.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == step ? VerdantPlateSkin.Hues.primary : VerdantPlateSkin.Hues.border)
                            .frame(width: i == step ? 24 : 8, height: 8)
                    }
                }
                .padding(.top, VerdantPlateSkin.Pad.xxl)

                Spacer()

                Button {
                    if step < cards.count - 1 {
                        withAnimation(VPMotion.spring()) { step += 1 }
                    } else {
                        finish()
                    }
                } label: {
                    HStack {
                        Text(step < cards.count - 1 ? "Continue" : "Get started")
                        Image(systemName: "arrow.down")
                    }
                }
                .buttonStyle(VPPrimaryButton())
                .padding(.horizontal, VerdantPlateSkin.Pad.xl)
                .padding(.bottom, VerdantPlateSkin.Pad.xxl)
            }
        }
    }

    private func finish() {
        var prefs = initial
        prefs.hasCompletedWelcome = true
        try? workbench.vault.savePrefs(prefs)
        onComplete(prefs)
    }
}
