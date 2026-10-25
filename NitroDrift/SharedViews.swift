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
            .frame(minHeight: 52)
            .contentShape(Rectangle())
                        .background {
                RoundedRectangle(cornerRadius: 13)
                    .fill(
                        LinearGradient(
                            colors: highlighted
                                ? [NitroTheme.cyan, NitroTheme.cyan.opacity(0.78)]
                                : [.white.opacity(0.18), .white.opacity(0.065)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 11)
                    .strokeBorder(.white.opacity(highlighted ? 0.18 : 0.20), lineWidth: 1)
            }
        }
        .buttonStyle(NitroPressStyle())
        .opacity(disabled ? 0.4 : 1)
        .disabled(disabled)
    }
}

/// Consistent pressed feedback for all menu, garage and navigation buttons.
struct NitroPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.982 : 1)
            .brightness(configuration.isPressed ? 0.045 : 0)
            .animation(.easeOut(duration: 0.075), value: configuration.isPressed)
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
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [NitroTheme.panel.opacity(0.95),
                                     NitroTheme.background.opacity(0.84)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            }
    }
}

/// Native UIKit touch tracking, independent per button and reliable with
/// simultaneous steering + throttle + nitro touches.
/// SwiftUI zero-distance DragGestures frequently lose touch-up and conflict.
struct HoldDriveButton: UIViewRepresentable {
    let label: String
    let symbol: String
    var color: Color = NitroTheme.cyan
    var width: CGFloat = 69
    var height: CGFloat = 67
    let onPressed: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPressed: onPressed) }

    func makeUIView(context: Context) -> RacingTouchControl {
        let control = RacingTouchControl()
        control.configure(title: label, symbol: symbol, tint: UIColor(color))
        control.onChange = { [weak coordinator = context.coordinator] pressed in
            coordinator?.onPressed(pressed)
        }
        control.isExclusiveTouch = false
        control.isMultipleTouchEnabled = false
        control.isUserInteractionEnabled = true
        control.accessibilityLabel = label
        control.accessibilityTraits = .button
        return control
    }

    func updateUIView(_ view: RacingTouchControl, context: Context) {
        context.coordinator.onPressed = onPressed
        view.configure(title: label, symbol: symbol, tint: UIColor(color))
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: RacingTouchControl, context: Context) -> CGSize? {
        CGSize(width: width, height: height)
    }

    static func dismantleUIView(_ view: RacingTouchControl, coordinator: Coordinator) {
        view.release()
        view.onChange = nil
    }

    final class Coordinator {
        var onPressed: (Bool) -> Void
        init(onPressed: @escaping (Bool) -> Void) { self.onPressed = onPressed }
    }
}

final class RacingTouchControl: UIControl {
    var onChange: ((Bool) -> Void)?
    private let iconView = UIImageView()
    private let caption = UILabel()
    private var tint = UIColor.cyan
    private var down = false
    private var configuredTitle = ""
    private var configuredSymbol = ""
    private var configuredTint = UIColor.clear
    private let fill = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isExclusiveTouch = false
        backgroundColor = .clear
        layer.cornerRadius = 15
        layer.borderWidth = 1.5
        clipsToBounds = true
        fill.isUserInteractionEnabled = false
        iconView.isUserInteractionEnabled = false
        caption.isUserInteractionEnabled = false
        fill.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        caption.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fill)
        addSubview(iconView)
        addSubview(caption)
        iconView.contentMode = .scaleAspectFit
        caption.font = .systemFont(ofSize: 10, weight: .heavy)
        caption.textAlignment = .center
        caption.adjustsFontSizeToFitWidth = true
        NSLayoutConstraint.activate([
            fill.leadingAnchor.constraint(equalTo: leadingAnchor),
            fill.trailingAnchor.constraint(equalTo: trailingAnchor),
            fill.topAnchor.constraint(equalTo: topAnchor),
            fill.bottomAnchor.constraint(equalTo: bottomAnchor),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -9),
            iconView.heightAnchor.constraint(equalToConstant: 26),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            caption.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 3),
            caption.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            caption.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3)
        ])
        render()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    func configure(title: String, symbol: String, tint: UIColor) {
        // SwiftUI updates 10+ times/sec for the speedometer: avoid rebuilding
        // images and button layers on every unrelated frame of HUD telemetry.
        if configuredTitle == title && configuredSymbol == symbol &&
           configuredTint.isEqual(tint) { return }
        configuredTitle = title
        configuredSymbol = symbol
        configuredTint = tint
        self.tint = tint
        caption.text = title
        iconView.image = UIImage(systemName: symbol)?.withRenderingMode(.alwaysTemplate)
        render()
    }

    private func render() {
        layer.borderColor = tint.withAlphaComponent(down ? 1 : 0.68).cgColor
        fill.backgroundColor = down ? tint : UIColor.black.withAlphaComponent(0.73)
        iconView.tintColor = down ? UIColor.black : tint
        caption.textColor = down ? UIColor.black : tint
    }

    private func setDown(_ state: Bool) {
        guard down != state else { return }
        down = state
        render()
        onChange?(state)
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        setDown(true)
        return true
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        // Maintain control ownership until the same finger is lifted/cancelled.
        // A drag must never unexpectedly release BRAKE, GAS or steering.
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) { release() }
    override var isEnabled: Bool {
        didSet { if !isEnabled { release() } }
    }
    override func cancelTracking(with event: UIEvent?) { release() }
    override func willMove(toWindow newWindow: UIWindow?) {
        if newWindow == nil { release() }
        super.willMove(toWindow: newWindow)
    }

    func release() { setDown(false) }
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
