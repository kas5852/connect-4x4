import SwiftUI
import ConnectCore

enum Palette {
    static let background = Color(hex: 0x0C1420)
    static let surface = Color(hex: 0x172334)
    static let elevated = Color(hex: 0x223248)
    static let muted = Color(hex: 0xA6B5C9)
    static let ink = Color(hex: 0xF7F5ED)
    static let lime = Color(hex: 0xC5F778)
    static let coral = Color(hex: 0xFF7C70)
    static let gold = Color(hex: 0xFFD076)
    static let board = Color(hex: 0x35557D)
    static let hole = Color(hex: 0x101D2E)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255,
                  blue: Double(hex & 255) / 255, opacity: 1)
    }
}

extension Player {
    var color: Color { self == .coral ? Palette.coral : Palette.gold }
    var symbol: String { self == .coral ? "circle.fill" : "diamond.fill" }
}

struct Eyebrow: View {
    var text: String
    var body: some View {
        Text(text).font(.system(size: 10, weight: .heavy, design: .monospaced))
            .tracking(2).foregroundStyle(Palette.muted)
    }
}

struct PrimaryButton: View {
    let title: String
    var symbol = "arrow.up.right"
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 17, weight: .heavy, design: .rounded))
                Spacer()
                Image(systemName: symbol).font(.system(size: 18, weight: .bold))
            }.foregroundStyle(Palette.background).padding(.horizontal, 22).frame(minHeight: 58)
                .background(Palette.lime, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }
}

struct Wordmark: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("connect").foregroundStyle(Palette.ink)
            Text("4×4").foregroundStyle(Palette.lime)
        }.font(.system(size: 24, weight: .black, design: .rounded))
            .accessibilityElement(children: .ignore).accessibilityLabel("Connect four by four")
    }
}
