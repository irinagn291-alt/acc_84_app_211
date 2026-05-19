import SwiftUI

struct VPNutriGlyph: View {
    let grade: String?
    var compact: Bool = false

    var body: some View {
        let normalized = grade?.lowercased()
        let known = normalized.flatMap { ["a", "b", "c", "d", "e"].contains($0) ? $0 : nil }

        if let known {
            Text(known.uppercased())
                .font(.system(size: compact ? 13 : 16, weight: .black, design: .rounded))
                .foregroundStyle(VerdantPlateSkin.Hues.textLight)
                .padding(.horizontal, compact ? 8 : 12)
                .padding(.vertical, compact ? 4 : 6)
                .background(Color.vpNutriColor(grade: known))
                .clipShape(Capsule())
                .accessibilityLabel("Nutri-Score \(known.uppercased())")
        } else if !compact {
            Text("Nutri ?")
                .font(VerdantPlateSkin.TypeScale.caption)
                .foregroundStyle(VerdantPlateSkin.Hues.textMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(VerdantPlateSkin.Hues.skeleton)
                .clipShape(Capsule())
        }
    }
}

struct VPEcoGlyph: View {
    let grade: String?

    var body: some View {
        let t = (grade?.uppercased()) ?? "—"
        Text("Eco \(t)")
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.vpNutriColor(grade: grade))
            .foregroundStyle(VerdantPlateSkin.Hues.textLight)
            .clipShape(Capsule())
    }
}

struct VPNovaGlyph: View {
    let group: Int?

    var body: some View {
        VStack(spacing: 2) {
            Text("NOVA")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(VerdantPlateSkin.Hues.primaryDark)
            Text(group.map(String.init) ?? "—")
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.vpNovaColor(group: group))
        }
        .frame(minWidth: 58)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VerdantPlateSkin.Hues.primaryLight)
        .clipShape(Capsule())
    }
}

struct VPScoreStrip: View {
    let item: VerdantFoodItem

    var body: some View {
        HStack(spacing: VerdantPlateSkin.Pad.sm) {
            VPNutriGlyph(grade: item.nutriScore)
            VPNovaGlyph(group: item.novaGroup)
            VPEcoGlyph(grade: item.ecoScore)
        }
    }
}
