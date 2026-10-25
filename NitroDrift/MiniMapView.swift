import SwiftUI

/// Local procedural minimap centred on the player's current position.
struct MiniMapView: View {
    @ObservedObject var session: GameSession

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let scale = 0.19
            let center = CGPoint(x: w / 2, y: h / 2)

            func point(_ x: Double, _ z: Double) -> CGPoint {
                CGPoint(x: center.x + (x - session.playerX) * scale,
                        y: center.y + (z - session.playerZ) * scale)
            }

            var streets = Path()
            for coordinate in stride(from: -450.0, through: 450.0, by: 150) {
                let a = point(coordinate, -520)
                let b = point(coordinate, 520)
                streets.move(to: a); streets.addLine(to: b)
                let c = point(-520, coordinate)
                let d = point(520, coordinate)
                streets.move(to: c); streets.addLine(to: d)
            }
            context.stroke(streets, with: .color(.gray.opacity(0.55)), lineWidth: 4)

            if (session.mode == .circuit || session.mode == .online),
               session.raceCheckpoint < StreetSystems.checkpoints.count {
                let checkpoint = StreetSystems.checkpoints[session.raceCheckpoint]
                let p = point(checkpoint.0, checkpoint.1)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)),
                             with: .color(.orange))
            }

            if session.mode == .online, let remote = OnlineRacing.shared.remoteState {
                let p = point(remote.x, remote.z)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)),
                             with: .color(.red))
            }

            var triangle = Path()
            triangle.move(to: CGPoint(x: center.x, y: center.y - 8))
            triangle.addLine(to: CGPoint(x: center.x - 5, y: center.y + 6))
            triangle.addLine(to: CGPoint(x: center.x + 5, y: center.y + 6))
            triangle.closeSubpath()
            let rotated = triangle.applying(CGAffineTransform(translationX: -center.x, y: -center.y)
                .rotated(by: CGFloat(session.playerHeading))
                .translatedBy(x: center.x, y: center.y))
            context.fill(rotated, with: .color(NitroTheme.cyan))
            context.stroke(rotated, with: .color(.white), lineWidth: 1)
        }
        .background(.black.opacity(0.70))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(NitroTheme.cyan.opacity(0.32), lineWidth: 1)
        }
        .accessibilityLabel("Minimap; district \(session.district)")
    }
}
