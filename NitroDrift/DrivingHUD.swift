import SwiftUI

/// Thumb-first landscape controls. Easy Drive accelerates automatically; this
/// frees both thumbs for steering, controlled braking, drifting and boost.
/// All driving controls are native UIKit buttons supporting simultaneous touch.
struct DrivingHUD: View {
    @ObservedObject var session: GameSession

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 790
            let narrow = geo.size.width < 705
            let steerWidth: CGFloat = narrow ? 76 : compact ? 92 : 108
            let pedalWidth: CGFloat = narrow ? 62 : compact ? 72 : 84
            let controlHeight: CGFloat = compact ? 71 : 88
            let edge: CGFloat = narrow ? 8 : compact ? 12 : 23
            let spacing: CGFloat = narrow ? 5 : 9
            ZStack {
                VStack(spacing: 4) {
                    topHUD(compact: compact)
                    Spacer(minLength: 6)

                    // Speed belongs in the unobstructed middle of the screen,
                    // avoiding six controls plus a minimap fighting for width.
                    HStack(alignment: .bottom, spacing: spacing) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: spacing) {
                                HoldDriveButton(label: "LEFT", symbol: "arrowshape.left.fill",
                                                color: NitroTheme.cyan,
                                                width: steerWidth, height: controlHeight,
                                                onPressed: { session.input.left = $0 })
                                    .frame(width: steerWidth, height: controlHeight)
                                HoldDriveButton(label: "RIGHT", symbol: "arrowshape.right.fill",
                                                color: NitroTheme.cyan,
                                                width: steerWidth, height: controlHeight,
                                                onPressed: { session.input.right = $0 })
                                    .frame(width: steerWidth, height: controlHeight)
                            }
                            Text(session.easyDrive ? "AUTO ACCELERATION" : "MANUAL THROTTLE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(.white.opacity(0.65))
                        }

                        Spacer(minLength: 2)

                        VStack(spacing: 0) {
                            Text("\(session.speedKPH)")
                                .font(.system(size: compact ? 31 : 47,
                                              weight: .black, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("KM/H  G\(session.gear)")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.75))
                            Text("\(session.engineRPM) RPM")
                                .font(.system(size: 8, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.54))
                        }
                        .frame(width: narrow ? 78 : compact ? 98 : 120)
                        .padding(.bottom, 5)
                        .allowsHitTesting(false)

                        Spacer(minLength: 2)

                        HStack(alignment: .bottom, spacing: spacing) {
                            HoldDriveButton(label: "BRAKE", symbol: "minus.circle.fill",
                                            color: NitroTheme.orange,
                                            width: pedalWidth, height: controlHeight,
                                            onPressed: { session.input.brake = $0 })
                                .frame(width: pedalWidth, height: controlHeight)
                            HoldDriveButton(label: "DRIFT", symbol: "steeringwheel",
                                            color: NitroTheme.orange,
                                            width: pedalWidth, height: controlHeight,
                                            onPressed: { session.input.handbrake = $0 })
                                .frame(width: pedalWidth, height: controlHeight)
                            VStack(spacing: 5) {
                                HoldDriveButton(label: "NITRO", symbol: "bolt.fill",
                                                color: NitroTheme.cyan,
                                                width: pedalWidth, height: controlHeight - 11,
                                                onPressed: { session.input.nitro = $0 })
                                    .frame(width: pedalWidth, height: controlHeight - 11)
                                GeometryReader { progress in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(.white.opacity(0.17))
                                        Capsule().fill(NitroTheme.cyan)
                                            .frame(width: progress.size.width *
                                                CGFloat(max(0, min(1, session.nitro / 100))))
                                    }
                                }
                                .frame(width: pedalWidth, height: 6)
                                .allowsHitTesting(false)
                            }
                            if !session.easyDrive {
                                HoldDriveButton(label: "GAS", symbol: "arrow.up.circle.fill",
                                                color: NitroTheme.cyan,
                                                width: pedalWidth, height: controlHeight,
                                                onPressed: { session.input.gas = $0 })
                                    .frame(width: pedalWidth, height: controlHeight)
                            }
                        }
                    }
                    .padding(.bottom, compact ? 3 : 11)
                }
                .padding(.horizontal, edge)
                .padding(.top, compact ? 3 : 10)

                if session.isPaused {
                    Color.black.opacity(0.85).ignoresSafeArea()
                    GlassPanel {
                        VStack(spacing: 12) {
                            if let result = session.raceResult {
                                Text(result.title)
                                    .font(.system(size: 23, weight: .black, design: .rounded))
                                Text("\(result.distance) • +\(result.reward) CR")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(NitroTheme.cyan)
                                NitroButton(title: "Race again", symbol: "arrow.clockwise",
                                            highlighted: true) {
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
                Text(session.district + (session.weather == .rain ? " · RAIN" : ""))
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
                .frame(width: 52, height: 52)
                .background(.black.opacity(0.73), in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
        }
        .buttonStyle(NitroPressStyle())
        .accessibilityLabel(accessibility)
    }
}
