import SwiftUI

enum VerdantPlateSkin {
    enum Hues {
        static let background   = Color(hex: 0xEFFAF3)
        static let surface      = Color(hex: 0xFFFFFF)
        static let surfaceSoft  = Color(hex: 0xF4FBF7)
        static let primary      = Color(hex: 0x14805A)
        static let primaryDark  = Color(hex: 0x0B4D35)
        static let primaryLight = Color(hex: 0xC8F0DC)
        static let accent       = Color(hex: 0x2ECC71)
        static let secondary    = Color(hex: 0x6EE7A8)
        static let textPrimary  = Color(hex: 0x102A1E)
        static let textMuted    = Color(hex: 0x5C7A6A)
        static let textLight    = Color.white
        static let border       = Color(hex: 0xD4EBDD)
        static let danger       = Color(hex: 0xE05252)
        static let warning      = Color(hex: 0xE6A817)
        static let info         = Color(hex: 0x2B8CDB)
        static let skeleton     = Color(hex: 0xE2F2E8)

        static let nutriA = Color(hex: 0x038141)
        static let nutriB = Color(hex: 0x85BB2F)
        static let nutriC = Color(hex: 0xFECB02)
        static let nutriD = Color(hex: 0xEE8100)
        static let nutriE = Color(hex: 0xE63E11)

        static let nova1 = Color(hex: 0x14805A)
        static let nova2 = Color(hex: 0x6EE7A8)
        static let nova3 = Color(hex: 0xE6A817)
        static let nova4 = Color(hex: 0xE05252)
    }

    enum Pad {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Corner {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 22
        static let xl: CGFloat = 30
    }

    enum TypeScale {
        static let title = Font.system(size: 28, weight: .heavy, design: .rounded)
        static let h1 = Font.system(size: 24, weight: .heavy, design: .rounded)
        static let h2 = Font.system(size: 20, weight: .bold, design: .rounded)
        static let body = Font.system(size: 15, weight: .regular, design: .rounded)
        static let caption = Font.system(size: 12, weight: .semibold, design: .rounded)
        static let eyebrow = Font.system(size: 14, weight: .heavy, design: .rounded)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    static func vpNutriColor(grade: String?) -> Color {
        switch grade?.lowercased() {
        case "a": VerdantPlateSkin.Hues.nutriA
        case "b": VerdantPlateSkin.Hues.nutriB
        case "c": VerdantPlateSkin.Hues.nutriC
        case "d": VerdantPlateSkin.Hues.nutriD
        case "e": VerdantPlateSkin.Hues.nutriE
        default: VerdantPlateSkin.Hues.textMuted
        }
    }

    static func vpNovaColor(group: Int?) -> Color {
        switch group {
        case 1: VerdantPlateSkin.Hues.nova1
        case 2: VerdantPlateSkin.Hues.nova2
        case 3: VerdantPlateSkin.Hues.nova3
        case 4: VerdantPlateSkin.Hues.nova4
        default: VerdantPlateSkin.Hues.textMuted
        }
    }

    static func vpCautionTint(for severity: VerdantCautionSeverity) -> Color {
        switch severity {
        case .danger: VerdantPlateSkin.Hues.danger
        case .caution: VerdantPlateSkin.Hues.warning
        case .info: VerdantPlateSkin.Hues.info
        }
    }
}

extension View {
    func vpCardShadow() -> some View {
        shadow(color: VerdantPlateSkin.Hues.textPrimary.opacity(0.08), radius: 16, x: 0, y: 8)
    }

    func vpSoftShadow() -> some View {
        shadow(color: VerdantPlateSkin.Hues.textPrimary.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

enum VPMotion {
    @MainActor static var reduced: Bool { UIAccessibility.isReduceMotionEnabled }
    @MainActor static func spring() -> Animation? {
        reduced ? .linear(duration: 0.01) : .spring(duration: 0.35, bounce: 0.12)
    }
}

struct VPPrimaryButton: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .heavy, design: .rounded))
            .foregroundStyle(VerdantPlateSkin.Hues.textLight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(enabled ? VerdantPlateSkin.Hues.primary : VerdantPlateSkin.Hues.skeleton)
            .clipShape(RoundedRectangle(cornerRadius: VerdantPlateSkin.Corner.lg, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

struct VPScaleButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(VPMotion.spring(), value: configuration.isPressed)
    }
}
