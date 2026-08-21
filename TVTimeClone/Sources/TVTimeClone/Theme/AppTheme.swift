import SwiftUI

enum AppTheme {
    static let background   = Color(hex: "0A0A0A")
    static let surface      = Color(hex: "111111")
    static let card         = Color(hex: "1A1A1A")
    static let accent       = Color(hex: "4BFF6B")
    static let accentDim    = Color(hex: "2A8C3F")
    static let text         = Color.white
    static let subtext      = Color(white: 0.5)
    static let separator    = Color(white: 0.12)

    static let cornerRadius: CGFloat = 12
    static let cardCornerRadius: CGFloat = 10

    static func springSnappy() -> Animation {
        .spring(response: 0.32, dampingFraction: 0.72)
    }
    static func springBouncy() -> Animation {
        .spring(response: 0.42, dampingFraction: 0.62)
    }
    static func springSmooth() -> Animation {
        .spring(response: 0.5, dampingFraction: 0.85)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Press-scale button style
struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
