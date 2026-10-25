import SwiftUI

/// Device-adaptive HUD. Controls remain outside scroll views and are layered
/// above a non-hit-testable SceneKit view so every touch reaches UIKit tracking.
struct DrivingHUD: View {
    @ObservedObject var session: GameSession

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 820
            let control = compact ? CGFloat(59) : CGFloat(75)
            let height = compact ? CGFloat(65) : CGFloat(80)
            let mapSize = compact ? CGFloat(82) : CGFloat(115)
            let horizontalPadding = compact ? CGFloat(12) : CGFloat(24)

            ZStack {
                VStack(spacing: 8) {
                    topHUD(compact: compact)
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: compact ? 5 : 10) {
                        HoldDriveButton(label: "LEFT", symbol: "arrow.left",
                                        width: control, height: height,
                                        onPressed: { session.input.left = $0 })
                        HoldDriveButton(label: "RIGHT", symbol: "arrow.right",
                                        width: control, height: height,
                                        onPressed: { session.input.right = $0 })

                        Spacer(minLength: 2)

                        MiniMapView(session: session)
                            .frame(width: mapSize, height: mapSize)
                            .allowsHitTesting(false)

                        VStack(spacing: 0) {
                            Text("\(session.speedKPH)")
                                .font(.system(size: compact ? 35 : 51, weight: .black, design: .rounded).monospacedDigit())
                                .minimumScaleFactor(0.75)
                                .contentTransition(.numericText())
                            Text("KM/H   ·   G\(session.gear)")
                                .font(.system(size: compact ? 9 : 11, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.82))
                        }
                        .frame(width: compact ? 90 : 125)
                        .overlay(alignment: .top) {
                            Text("\(session.engineRPM) RPM")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.58))
                                .offset(y: -12)
                        }
                        .padding(.bottom, 3)

                        Spacer(minLength: 2)

                        HoldDriveButton(label: "E-BRAKE", symbol: "hand.raised.fill",
                                        color: NitroTheme.orange,
                                        width: compact ? 48 : 64, height: height - 6,
                                        onPressed: { session.input.handbrake = $0 })
                        HoldDriveButton(label: "BRAKE", symbol: "minus",
                                        color: NitroTheme.orange,
                                        width: control, height: height,
                                        onPressed: { session.input.brake = $0 })
                        HoldDriveButton(label: "GAS", symbol: "arrow.up",
                                        width: control, height: height,
                                        onPressed: { session.input.gas = $0 })
                        VStack(spacing: 5) {
                            HoldDriveButton(label: "NITRO", symbol: "bolt.fill",
                                            color: NitroTheme.orange,
                                            width: control, height: height - 14,
                                            onPressed: { session.input.nitro = $0 })
                            GeometryReader { bounds in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(.white.opacity(0.19))
                                    Capsule().fill(NitroTheme.orange)
                                        .frame(width: bounds.size.width * CGFloat(max(0, min(1, session.nitro / 100))))
                                }
                            }
                            .frame(width: control, height: 7)
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, compact ? 6 : 12)

                if session.isPaused {
                    Color.black.opacity(0.76)
                        .ignoresSafeArea()
                    GlassPanel {
                        VStack(spacing: 12) {
                            if let result = session.raceResult {
                                Text(result.title)
                                    .font(.system(size: 23, weight: .black, design: .rounded))
                                Text("\(result.distance) • +\(result.reward) CR")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(NitroTheme.cyan)
                                NitroButton(title: "Race again", symbol: "arrow.clockwise", highlighted: true) {
                                    if session.mode == .online {
                                        session.goToMenu()
                                        session.phase = .leaderboard
                                    } else { session.start(session.mode) }
                                }
                            } else {
                                Text("PAUSED")
                                    .font(.system(size: 25, weight: .black, design: .rounded))
                                NitroButton(title: "Resume", symbol: "play.fill", highlighted: true) {
                                    session.togglePause()
                                }
                                NitroButton(title: "Restart", symbol: "arrow.clockwise") {
                                    session.start(session.mode)
                                }
                            }
                            NitroButton(title: "Main menu", symbol: "house.fill") {
                                session.goToMenu()
                            }
                        }
                        .frame(width: 224)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func topHUD(compact: Bool) -> some View {
        HStack(spacing: compact ? 7 : 11) {
            actionIcon("pause.fill", accessibility: "Pause") { session.togglePause() }

            VStack(alignment: .leading, spacing: 1) {
                Text(session.district)
                    .font(.system(size: compact ? 9 : 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NitroTheme.cyan)
                HStack(spacing: 8) {
                    Text("\(session.cash) CR")
                    Text("·")
                    Text("\(session.driftScore) DRIFT")
                }
                .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.82))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 9))

            Spacer(minLength: 2)

            if session.mode != .freeRide {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.1f SEC", session.sprintTime))
                        .font(.system(size: compact ? 15 : 22, weight: .black, design: .monospaced))
                        .foregroundStyle(session.sprintTime < 15 ? NitroTheme.orange : .white)
                    Text(detail)
                        .font(.system(size: compact ? 9 : 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.68), in: RoundedRectangle(cornerRadius: 9))
            }

            actionIcon("camera.rotate.fill", accessibility: "Change camera") { session.cycleCamera() }
            actionIcon("arrow.counterclockwise", accessibility: "Reset car") { session.resetCar() }
        }
    }

    private var detail: String {
        switch session.mode {
        case .freeRide: return ""
        case .sprint: return "\(Int(session.sprintDistance)) / \(Int(session.sprintGoal)) M"
        case .pursuit: return "HEAT \(Int(session.heat))% • \(session.wantedLevel) STARS"
        case .circuit, .online:
            return "GATE \(session.raceCheckpoint)/\(session.raceCheckpointTotal)  \(session.nextGateDirection) \(session.nextGateDistance) M"
        }
    }

    private func actionIcon(_ symbol: String, accessibility: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 47, height: 47)
                .background(.black.opacity(0.73), in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(accessibility)
    }
}
