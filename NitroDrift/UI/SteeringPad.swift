import SwiftUI
import UIKit

/// One tracking surface lets a thumb cross neutral and reverse without lifting.
struct SteeringPad: UIViewRepresentable {
    let changed: (Double) -> Void

    func makeUIView(context: Context) -> Pad { let pad = Pad(); pad.changed = changed; return pad }
    func updateUIView(_ view: Pad, context: Context) { view.changed = changed }
    static func dismantleUIView(_ view: Pad, coordinator: ()) { view.changed?(0); view.changed = nil }

    final class Pad: UIControl {
        var changed: ((Double) -> Void)?
        private let left = UIImageView(image: UIImage(systemName: "chevron.left"))
        private let right = UIImageView(image: UIImage(systemName: "chevron.right"))
        private var value = 0.0

        override init(frame: CGRect) {
            super.init(frame: frame)
            isExclusiveTouch = false
            backgroundColor = UIColor.black.withAlphaComponent(0.38)
            layer.cornerRadius = 22
            layer.cornerCurve = .continuous
            layer.borderWidth = 1
            layer.borderColor = UIColor.white.withAlphaComponent(0.34).cgColor
            for symbol in [left,right] {
                symbol.contentMode = .scaleAspectFit
                symbol.preferredSymbolConfiguration = UIImage.SymbolConfiguration(weight: .bold)
                symbol.tintColor = .white
                addSubview(symbol)
            }
            isAccessibilityElement = true
            accessibilityLabel = "Steering"
            accessibilityHint = "Slide left or right to steer. Lift to straighten."
            accessibilityTraits = .adjustable
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
        override func layoutSubviews() {
            super.layoutSubviews()
            let side = min(26, bounds.height/2)
            for (i, symbol) in [left,right].enumerated() {
                symbol.frame = CGRect(x: bounds.width * (i==0 ? 0.24 : 0.76)-side/2,
                                      y: bounds.midY-side/2,width: side,height: side)
            }
        }
        private func setSteering(_ next: Double) {
            guard value != next else { return }
            value = next
            left.tintColor = next < -0.05 ? .systemYellow : .white
            right.tintColor = next > 0.05 ? .systemYellow : .white
            changed?(next)
        }
        private func track(_ touch: UITouch) {
            let axis = Double((touch.location(in: self).x-bounds.midX)/max(1,bounds.midX))
            let magnitude = min(1,max(0,(abs(axis)-0.065)/0.67))
            setSteering(axis < 0 ? -magnitude : magnitude)
        }
        override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool { track(touch); return true }
        override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool { track(touch); return true }
        override func endTracking(_ touch: UITouch?, with event: UIEvent?) { setSteering(0) }
        override func cancelTracking(with event: UIEvent?) { setSteering(0) }
        override func accessibilityIncrement() { accessibilityTurn(1) }
        override func accessibilityDecrement() { accessibilityTurn(-1) }
        private func accessibilityTurn(_ direction: Double) {
            setSteering(direction)
            DispatchQueue.main.asyncAfter(deadline: .now()+0.32) { [weak self] in
                if self?.value == direction { self?.setSteering(0) }
            }
        }
    }
}
