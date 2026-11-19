import SwiftUI

/// Thumb-first landscape controls. Easy Drive accelerates automatically; this
/// frees both thumbs for steering, controlled braking, drifting and boost.
/// All driving controls are native UIKit buttons supporting simultaneous touch.
struct DrivingHUD: View {
    @ObservedObject var session: GameSession

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 790
            let narrow = geo.size.width < 705
            let steerWidth: CGFloat = narrow ? 76 : compact ? 92 : 108
            let pedalWidth: CGFloat = session.easyDrive ? (narrow ? 54 : compact ? 65 : 74)
                                                      : (narrow ? 46 : compact ? 54 : 61)
            let controlHeight: CGFloat = max(44, min(compact ? 65 : 77, geo.size.height * 0.17))
            let edge: CGFloat = narrow ? 8 : compact ? 12 : 23
            let spacing: CGFloat = narrow ? 5 : 7
            let nitroHeight = max(44, controlHeight - 11)
            ZStack {
                if session.isBoosting && !reduceMotion && !session.isPaused {
                    SpeedLines(intensity: min(1, Double(session.speedKPH) / 190), boosting: true)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                VStack(spacing: 4) {
                    topHUD(compact: compact)
                    Spacer(minLength: 6)

                    // Speed belongs in the unobstructed middle of the screen,
                    // avoiding six controls plus a minimap fighting for width.
                    HStack(alignment: .bottom, spacing: spacing) {
                        VStack(alignment: .leading, spacing: 5) {
                            SteeringPad { session.input.touchSteering = $0 }
                                .frame(width: steerWidth * 2 + spacing, height: controlHeight)
                            Text(session.easyDrive ? "AUTO ACCELERATION" : "MANUAL THROTTLE")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(.white.opacity(0.65))
                        }

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
                                                width: pedalWidth, height: nitroHeight,
                                                onPressed: { session.pressNitro($0) })
                                    .frame(width: pedalWidth, height: nitroHeight)
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
                                HStack {
                                    Toggle("Easy Drive", isOn: Binding(get: { session.easyDrive }, set: session.setEasyDrive))
                                        .tint(NitroTheme.cyan)
                                    actionIcon("arrow.counterclockwise", accessibility: "Reset car") { session.resetCar(); session.togglePause() }
                                }
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
        ZStack {
            HStack(spacing: compact ? 5 : 10) {
                actionIcon("pause.fill", accessibility: "Pause") { session.togglePause() }
                VStack(alignment: .leading, spacing: 1) {
                    Text((session.mode == .circuit || session.mode == .online) ? "\(session.racePosition)/2 POS" : session.mode.rawValue.uppercased())
                        .font(.system(size: compact ? 11 : 15, weight: .black, design: .rounded))
                    Text(session.district + (session.weather == .rain ? " · RAIN" : ""))
                        .font(.system(size: compact ? 8 : 9, weight: .bold))
                        .foregroundStyle(NitroTheme.cyan)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.64)
                .frame(width: compact ? 73 : 105, alignment: .leading)
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(session.mode == .freeRide ? "\(session.cash) CR" : String(format: "%.1f SEC", session.sprintTime))
                        .font(.system(size: compact ? 12 : 15, weight: .black, design: .rounded))
                        .monospacedDigit()
                    if session.mode != .freeRide {
                        Text(detail).font(.system(size: compact ? 8 : 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.60)
                .frame(width: compact ? 80 : 119, alignment: .trailing)
                actionIcon("camera.rotate.fill", accessibility: "Change camera") { session.cycleCamera() }
            }
            SpeedReadout(session: session, compact: compact)
        }
        .overlay(alignment: .topLeading) {
            MiniMapView(session: session)
                .frame(width: compact ? 42 : 55, height: compact ? 42 : 55)
                .opacity(0.72)
                .offset(y: compact ? 49 : 61)
                .allowsHitTesting(false)
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

/// Lightweight animated peripheral streaks. It is intentionally a SwiftUI
/// overlay so the effect scales cleanly across iPhone and iPad without adding
/// another SceneKit render pass or affecting collision/input handling.
private struct SpeedLines: View {
    let intensity: Double
    let boosting: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            Canvas { canvas, size in
                guard intensity > 0.01 else { return }
                let t = context.date.timeIntervalSinceReferenceDate
                let count = 18
                for index in 0..<count {
                    let seed = Double(index) * 17.31
                    let side = index.isMultiple(of: 2) ? 1.0 : -1.0
                    let y = (sin(t * (0.32 + intensity * 0.8) + seed) * 0.5 + 0.5) * size.height
                    let edgeX = side > 0 ? size.width * 0.73 : size.width * 0.27
                    let length = (24 + CGFloat((index * 19) % 55)) * CGFloat(intensity)
                    let start = CGPoint(x: edgeX, y: y)
                    let end = CGPoint(x: edgeX + CGFloat(side) * length, y: y + CGFloat((index % 3) - 1) * 5)
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    canvas.stroke(path,
                                  with: .color((boosting ? NitroTheme.orange : NitroTheme.cyan)
                                    .opacity(0.06 + intensity * 0.11)),
                                  lineWidth: boosting ? 2.0 : 1.15)
                }
            }
        }
        .blendMode(.screen)
    }
}

private struct SpeedReadout: View {
    @ObservedObject var session: GameSession
    let compact: Bool

    var body: some View {
        let gold = Color(red: 1, green: 0.80, blue: 0.20)
        VStack(spacing: -1) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(session.speedKPH)")
                    .font(.system(size: compact ? 34 : 46, weight: .black, design: .rounded).italic())
                    .monospacedDigit()
                Text("km/h")
                    .font(.system(size: compact ? 10 : 13, weight: .bold))
            }
            .foregroundStyle(session.isBoosting ? .white : gold)
            GeometryReader { proxy in
                let w = proxy.size.width
                let arc = Path { path in
                    path.move(to: CGPoint(x: 3, y: 1))
                    path.addQuadCurve(to: CGPoint(x: w-3, y: 1), control: CGPoint(x: w/2, y: 14))
                }
                arc.stroke(.black.opacity(0.4), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                arc.trimmedPath(from: 0, to: max(0,min(1,CGFloat(session.nitro/100))))
                    .stroke(session.isBoosting ? .cyan : gold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }
            .frame(height: 10)
        }
        .frame(width: compact ? 118 : 150)
        .shadow(color: .black.opacity(0.64), radius: 2, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Speed and nitro")
        .accessibilityValue("\(session.speedKPH) kilometres per hour, \(Int(session.nitro)) percent nitro")
        .allowsHitTesting(false)
    }
}
