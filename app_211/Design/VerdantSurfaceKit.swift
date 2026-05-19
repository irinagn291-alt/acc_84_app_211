import SwiftUI

struct VPField: View {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: VerdantPlateSkin.Pad.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(VerdantPlateSkin.Hues.textMuted)
            TextField(placeholder, text: $text)
                .font(VerdantPlateSkin.TypeScale.body)
                .submitLabel(.search)
                .onSubmit(onSubmit)
        }
        .padding(.horizontal, VerdantPlateSkin.Pad.lg)
        .padding(.vertical, 14)
        .background(VerdantPlateSkin.Hues.surface)
        .clipShape(RoundedRectangle(cornerRadius: VerdantPlateSkin.Corner.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VerdantPlateSkin.Corner.lg, style: .continuous)
                .stroke(VerdantPlateSkin.Hues.border, lineWidth: 1)
        )
    }
}

struct VPEmptyCanvas: View {
    let icon: String
    let title: String
    let detail: String
    var actionTitle: String?
    var onAction: (() -> Void)?

    var body: some View {
        VStack(spacing: VerdantPlateSkin.Pad.lg) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(VerdantPlateSkin.Hues.primary.opacity(0.7))
            Text(title)
                .font(VerdantPlateSkin.TypeScale.h2)
                .foregroundStyle(VerdantPlateSkin.Hues.textPrimary)
            Text(detail)
                .font(VerdantPlateSkin.TypeScale.body)
                .foregroundStyle(VerdantPlateSkin.Hues.textMuted)
                .multilineTextAlignment(.center)
            if let actionTitle, let onAction {
                Button(actionTitle, action: onAction)
                    .buttonStyle(VPPrimaryButton())
                    .padding(.top, VerdantPlateSkin.Pad.sm)
            }
        }
        .padding(VerdantPlateSkin.Pad.xl)
    }
}

struct VPChip: View {
    let label: String
    var selected: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(VerdantPlateSkin.TypeScale.caption)
                .foregroundStyle(selected ? VerdantPlateSkin.Hues.textLight : VerdantPlateSkin.Hues.primaryDark)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? VerdantPlateSkin.Hues.primary : VerdantPlateSkin.Hues.primaryLight)
                .clipShape(Capsule())
        }
        .buttonStyle(VPScaleButton())
    }
}

struct VPProductRowContent: View {
    let item: VerdantListItem

    var body: some View {
        HStack(spacing: VerdantPlateSkin.Pad.md) {
            VPRemoteThumb(urlString: item.imageUrl, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(VerdantPlateSkin.Hues.textPrimary)
                    .lineLimit(2)
                if let brand = item.brand {
                    Text(brand)
                        .font(VerdantPlateSkin.TypeScale.caption)
                        .foregroundStyle(VerdantPlateSkin.Hues.textMuted)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let grade = item.nutriScore {
                VPNutriGlyph(grade: grade, compact: true)
            }
        }
        .padding(VerdantPlateSkin.Pad.md)
        .background(VerdantPlateSkin.Hues.surface)
        .clipShape(RoundedRectangle(cornerRadius: VerdantPlateSkin.Corner.md, style: .continuous))
        .vpSoftShadow()
    }
}

struct VPProductRowLink: View {
    let item: VerdantListItem

    var body: some View {
        NavigationLink(value: item.barcode) {
            VPProductRowContent(item: item)
        }
        .buttonStyle(.plain)
    }
}

struct VPCautionBanner: View {
    let caution: VerdantCaution

    var body: some View {
        HStack(alignment: .top, spacing: VerdantPlateSkin.Pad.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.vpCautionTint(for: caution.severity))
            Text(caution.message)
                .font(VerdantPlateSkin.TypeScale.caption)
                .foregroundStyle(VerdantPlateSkin.Hues.textPrimary)
        }
        .padding(VerdantPlateSkin.Pad.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.vpCautionTint(for: caution.severity).opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: VerdantPlateSkin.Corner.sm, style: .continuous))
    }
}

struct VPOfflineRibbon: View {
    var body: some View {
        HStack(spacing: VerdantPlateSkin.Pad.sm) {
            Image(systemName: "wifi.slash")
            Text("Offline — showing cached data when available")
                .font(VerdantPlateSkin.TypeScale.caption)
        }
        .foregroundStyle(VerdantPlateSkin.Hues.textLight)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(VerdantPlateSkin.Hues.primaryDark)
    }
}

struct VPRemoteThumb: View {
    let urlString: String?
    var size: CGFloat = 72

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .background(VerdantPlateSkin.Hues.primaryLight)
        .clipShape(RoundedRectangle(cornerRadius: VerdantPlateSkin.Corner.sm, style: .continuous))
    }

    private var placeholder: some View {
        Image(systemName: "leaf.fill")
            .font(.system(size: size * 0.35))
            .foregroundStyle(VerdantPlateSkin.Hues.primary.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct VPScanHeroCard: View {
    var onScan: () -> Void

    var body: some View {
        Button(action: onScan) {
            HStack(spacing: VerdantPlateSkin.Pad.lg) {
                ZStack {
                    Circle()
                        .fill(VerdantPlateSkin.Hues.primaryLight)
                        .frame(width: 64, height: 64)
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(VerdantPlateSkin.Hues.primary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scan product")
                        .font(VerdantPlateSkin.TypeScale.h2)
                        .foregroundStyle(VerdantPlateSkin.Hues.textPrimary)
                    Text("Barcode or QR on packaging")
                        .font(VerdantPlateSkin.TypeScale.caption)
                        .foregroundStyle(VerdantPlateSkin.Hues.textMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(VerdantPlateSkin.Hues.textMuted)
            }
            .padding(VerdantPlateSkin.Pad.lg)
            .background(
                LinearGradient(
                    colors: [VerdantPlateSkin.Hues.surface, VerdantPlateSkin.Hues.primaryLight.opacity(0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: VerdantPlateSkin.Corner.lg, style: .continuous))
            .vpCardShadow()
        }
        .buttonStyle(VPScaleButton())
    }
}

struct VPPreferencesToolbar: ViewModifier {
    @EnvironmentObject private var orchestrator: VerdantTabOrchestrator

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    orchestrator.isPrefsPresented = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(VerdantPlateSkin.Hues.primary)
                }
                .accessibilityLabel("Preferences")
            }
        }
    }
}

extension View {
    func vpPreferencesToolbar() -> some View {
        modifier(VPPreferencesToolbar())
    }
}
