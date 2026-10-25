import SwiftUI

enum NitroTheme {
    static let cyan = Color(red: 0.12, green: 0.77, blue: 1.0)
    static let orange = Color(red: 1.0, green: 0.40, blue: 0.17)
    static let background = Color(red: 0.025, green: 0.037, blue: 0.075)
    static let panel = Color(red: 0.048, green: 0.068, blue: 0.12)
}

struct NitroLogo: View {
    var compact = false

    var body: some View {
        HStack(spacing: 0) {
            Text("NITRO")
                .foregroundStyle(.white)
            Text("DRIFT")
                .foregroundStyle(NitroTheme.cyan)
        }
        .font(.system(size: compact ? 23 : 46, weight: .black, design: .rounded))
        .tracking(compact ? -0.8 : -2.2)
        .shadow(color: NitroTheme.cyan.opacity(0.28), radius: 20, y: 5)
        .accessibilityLabel("NitroDrift")
    }
}

struct NitroButton: View {
    let title: String
    var symbol: String? = nil
    var highlighted = false
    var disabled = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .bold))
                }
                Text(title.uppercased())
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .tracking(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(highlighted ? NitroTheme.background : .white)
            .padding(.horizontal, 17)
            .frame(height: 45)
            .background(highlighted ? NitroTheme.cyan : .white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(.white.opacity(highlighted ? 0 : 0.12), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0.4 : 1)
        .disabled(disabled)
    }
}

struct GlassPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(NitroTheme.panel.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
    }
}

/// Touch-and-hold control. Ending the drag always releases the input.
struct HoldDriveButton: View {
    let label: String
    let symbol: String
    var color: Color = NitroTheme.cyan
    var width: CGFloat = 69
    var height: CGFloat = 67
    let onPressed: (Bool) -> Void

    @State private var held = false

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .black))
            Text(label)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(0.6)
        }
        .foregroundStyle(held ? NitroTheme.background : color)
        .frame(width: width, height: height)
        .background(held ? color : Color.black.opacity(0.61))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(color.opacity(held ? 1 : 0.65), lineWidth: held ? 2 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 15))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !held {
                        held = true
                        onPressed(true)
                    }
                }
                .onEnded { _ in
                    held = false
                    onPressed(false)
                }
        )
        .accessibilityLabel(label)
    }
}

struct StatPill: View {
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.black.opacity(0.55), in: Capsule())
    }
}
