import SwiftUI

struct NitroDriftRootView: View {
    @EnvironmentObject private var session: GameSession
    @StateObject private var online = OnlineRacing.shared

    var body: some View {
        GeometryReader { size in
            ZStack {
                GameSceneView(session: session)
                    .ignoresSafeArea()

                if session.phase != .driving {
                    LinearGradient(
                        colors: [.black.opacity(0.88), .black.opacity(0.36), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }

                switch session.phase {
                case .menu:
                    menu
                case .garage:
                    garage
                case .settings:
                    settings
                case .events:
                    events
                case .leaderboard:
                    leaderboard
                case .driving:
                    drivingHUD
                }
            }
            .frame(width: size.size.width, height: size.size.height)
            .foregroundStyle(.white)
            .animation(.easeInOut(duration: 0.20), value: session.phase)
            .onAppear {
                let active = session
                online.onMatchReady = { [weak active] in active?.start(.online) }
                online.onMatchEnded = { [weak active] in
                    guard let active, active.phase == .driving, active.mode == .online else { return }
                    active.completeEvent(won: false, distance: active.raceCheckpoint,
                                         title: "OPPONENT LEFT", reward: 0)
                }
            }
        }
    }

    private var menu: some View {
        HStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                Text("THE STREETS ARE YOURS")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(NitroTheme.orange)

                NitroLogo()

                Text("Build your ride. Own the night.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))

                Spacer(minLength: 8)

                NitroButton(title: "Free ride", symbol: "steeringwheel", highlighted: true) {
                    session.start(.freeRide)
                }
                NitroButton(title: "Race events", symbol: "flag.checkered") {
                    session.phase = .events
                }
                NitroButton(title: "My garage", symbol: "car.side.fill") {
                    session.phase = .garage
                }
                NitroButton(title: "Online / rankings", symbol: "network") {
                    session.phase = .leaderboard
                    online.authenticate()
                }
                NitroButton(title: "Settings", symbol: "gearshape.fill") {
                    session.phase = .settings
                }
            }
                }
            }
            .scrollIndicators(.hidden)
            .frame(width: 298)

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                StatPill(symbol: "dollarsign.circle.fill", text: "\(session.cash) CR")
                StatPill(symbol: "star.fill", text: "LVL \(session.level) • \(session.wins) WINS")
                Spacer()
                Text("ALPHA 0.2")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 15)
    }

    private var garage: some View {
        HStack(alignment: .top, spacing: 12) {
            GlassPanel {
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        header("GARAGE")

                        HStack {
                            Text(session.carStyle.title.uppercased())
                                .font(.system(size: 23, weight: .black, design: .rounded))
                            Spacer()
                            Text("\(session.cash) CR")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundStyle(NitroTheme.cyan)
                        }

                        Text("YOUR CARS")
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.60))
                        ForEach(CarStyle.allCases) { style in
                            let owned = session.ownedCarStyles.contains(style.rawValue)
                            NitroButton(title: (style == session.carStyle ? "✓ " : "") + style.title + (owned ? "" : " • \(style.price) CR"),
                                        symbol: "car.side.fill", highlighted: style == session.carStyle,
                                        disabled: !owned && session.cash < style.price) {
                                _ = session.selectOrBuyCar(style)
                            }
                        }
                        Text("CUSTOM PAINT")
                            .font(.system(size: 11, weight: .heavy))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.60))

                        HStack(spacing: 11) {
                            ForEach(CarPaint.allCases) { paint in
                                Button {
                                    session.setPaint(paint)
                                } label: {
                                    Circle()
                                        .fill(Color(uiColor: paint.color))
                                        .frame(width: 28, height: 28)
                                        .overlay {
                                            Circle()
                                                .strokeBorder(.white, lineWidth: session.paint == paint ? 3 : 0)
                                                .padding(-3)
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(paint.title)
                            }
                        }

                        Text(session.paint.title.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(NitroTheme.cyan)

                        Divider().overlay(.white.opacity(0.15))

                        upgrade(
                            title: "ENGINE",
                            subtitle: "Top speed + acceleration",
                            level: session.engineLevel,
                            price: session.enginePrice(),
                            buy: { session.buyEngine() }
                        )
                        upgrade(
                            title: "HANDLING",
                            subtitle: "More responsive turning",
                            level: session.handlingLevel,
                            price: session.handlingPrice(),
                            buy: { session.buyHandling() }
                        )

                        upgrade(title: "BRAKES", subtitle: "Shorter stopping distance",
                                level: session.brakeLevel, price: session.brakePrice(),
                                buy: { session.buyBrakes() })
                        upgrade(title: "NITRO", subtitle: "Longer, stronger boost",
                                level: session.nitroLevel, price: session.nitroPrice(),
                                buy: { session.buyNitro() })

                        NitroButton(title: "Drive this car", symbol: "steeringwheel", highlighted: true) {
                            session.start(.freeRide)
                        }
                    }
                    .padding(2)
                }
            }
            .frame(width: 340)
            Spacer(minLength: 0)
            VStack(alignment: .trailing) {
                Text("YOUR RIDE")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(NitroTheme.cyan)
                Text("Drag-free 3D rotating preview")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
    }

    private func upgrade(title: String, subtitle: String,
                         level: Int, price: Int, buy: @escaping () -> Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                Spacer()
                Text("LVL \(level + 1)/6")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(NitroTheme.cyan)
            }
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.67))
            NitroButton(
                title: level >= 5 ? "Maxed out" : "Upgrade • \(price) CR",
                symbol: "arrow.up.circle",
                disabled: level >= 5 || session.cash < price,
                action: { _ = buy() }
            )
        }
    }

    private var settings: some View {
        HStack {
            GlassPanel {
                VStack(alignment: .leading, spacing: 17) {
                    header("SETTINGS")
                    Toggle("Haptic feedback", isOn: Binding(
                        get: { session.hapticsEnabled },
                        set: { session.setHaptics($0) }
                    ))
                    .tint(NitroTheme.cyan)

                    Toggle("Engine / effects", isOn: Binding(get: { session.soundEnabled },
                                                                  set: { session.setSound($0) })).tint(NitroTheme.cyan)
                    Toggle("Synthesized soundtrack", isOn: Binding(get: { session.musicEnabled },
                                                                        set: { session.setMusic($0) })).tint(NitroTheme.cyan)
                    Toggle("Handling assist", isOn: Binding(get: { session.handlingAssist },
                                                                 set: { session.setAssist($0) })).tint(NitroTheme.cyan)
                    Text("CAMERA")
                        .font(.system(size: 11, weight: .black))
                        .tracking(2)
                        .foregroundStyle(NitroTheme.cyan)
                    Text("Switch between chase, hood, and high-angle views while driving.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                    Text("Progress is saved automatically on this device.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.65))
                    Text("NitroDrift Alpha 0.2 • iOS 17+")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.47))
                }
            }
            .frame(width: 390)
            Spacer()
        }
        .padding(.horizontal, 25)
    }

    private func header(_ title: String) -> some View {
        HStack(spacing: 12) {
            Button {
                session.phase = .menu
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .black))
                    .frame(width: 35, height: 35)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.system(size: 19, weight: .black, design: .rounded))
                .tracking(1.5)
        }
    }


    private var events: some View {
        HStack(alignment: .top) {
            GlassPanel {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        header("STREET EVENTS")
                        Text("EARN CREDITS • BUILD YOUR REP")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(NitroTheme.cyan)
                        Text("LEVEL \(session.level) • \(session.reputation) REP")
                            .font(.system(size: 13, weight: .bold))
                        NitroButton(title: "Speed Sprint • 900 CR", symbol: "speedometer", highlighted: true) {
                            session.start(.sprint)
                        }
                        Text("Cover 1,600 m in 90 seconds.")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                        NitroButton(title: "Circuit Showdown • 1,800 CR", symbol: "flag.checkered") {
                            session.start(.circuit)
                        }
                        Text("Hit 9 neon checkpoint gates in order before your rival.")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                        NitroButton(title: "Hot Pursuit • 1,100 CR", symbol: "bolt.car.fill") {
                            session.start(.pursuit)
                        }
                        Text("Survive the chase for 75 seconds without maxing out heat.")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.7))
                        if session.bestCircuitTime > 0 {
                            StatPill(symbol: "trophy.fill", text: String(format: "CIRCUIT PB %.1f s", session.bestCircuitTime))
                        }
                    }
                    .padding(2)
                }
            }
            .frame(width: 390)
            Spacer()
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 10)
    }

    private var leaderboard: some View {
        HStack(alignment: .top) {
            GlassPanel {
                VStack(alignment: .leading, spacing: 13) {
                    header("ONLINE RACING")
                    Text(online.status)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(online.authenticated ? NitroTheme.cyan : NitroTheme.orange)
                    Text("Connect to Game Center for two-player real-time checkpoint duels and rankings.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.75))
                    NitroButton(title: online.authenticated ? "Find 1v1 match" : "Sign in", symbol: "person.2.fill",
                                highlighted: true) {
                        if online.authenticated { online.findMatch() }
                        else { online.authenticate() }
                    }
                    NitroButton(title: "Game Center rankings", symbol: "trophy.fill") {
                        online.showLeaderboards()
                    }
                    Text("Online play requires Game Center enabled for this app in App Store Connect. Opponents need compatible builds.")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .frame(width: 420)
            Spacer()
        }
        .padding(.horizontal, 25)
        .padding(.vertical, 10)
    }

    private var drivingHUD: some View {
        ZStack {
            VStack {
                HStack(alignment: .top) {
                    Button {
                        session.togglePause()
                    } label: {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 16, weight: .black))
                            .frame(width: 43, height: 43)
                            .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    StatPill(symbol: "dollarsign.circle.fill", text: "\(session.cash) CR")
                    StatPill(symbol: "sparkles", text: "\(session.driftScore) DRIFT")
                    StatPill(symbol: "map", text: session.district)
                    if session.mode == .circuit || session.mode == .online {
                        StatPill(symbol: "location.north.fill",
                                 text: "\(session.nextGateDirection) \(session.nextGateDistance) M")
                    }
                    Spacer()

                    if session.mode != .freeRide {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(String(format: "%.1f s", session.sprintTime))
                                .font(.system(size: 25, weight: .heavy, design: .monospaced))
                                .foregroundStyle(session.sprintTime < 15 ? NitroTheme.orange : .white)
                            Text(session.mode == .sprint ? "\(Int(session.sprintDistance)) / \(Int(session.sprintGoal)) M" :
                                 session.mode == .pursuit ? "HEAT \(Int(session.heat))% • \(session.wantedLevel) STARS" :
                                 "GATE \(session.raceCheckpoint) / \(session.raceCheckpointTotal) • P\(session.racePosition)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                    }
                    Button {
                        session.cycleCamera()
                    } label: {
                        Image(systemName: "camera.rotate.fill")
                            .font(.system(size: 18))
                            .frame(width: 43, height: 43)
                            .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        session.resetCar()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 18, weight: .bold))
                            .frame(width: 43, height: 43)
                            .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                HStack(alignment: .bottom, spacing: 9) {
                    MiniMapView(session: session)
                        .frame(width: 102, height: 102)
                        .padding(.bottom, 2)
                    Spacer(minLength: 2)
                    HoldDriveButton(label: "LEFT", symbol: "arrow.left",
                                    onPressed: { session.input.left = $0 })
                    HoldDriveButton(label: "RIGHT", symbol: "arrow.right",
                                    onPressed: { session.input.right = $0 })

                    Spacer(minLength: 8)

                    VStack(spacing: 0) {
                        Text("\(session.speedKPH)")
                            .font(.system(size: 48, weight: .black, design: .rounded).monospacedDigit())
                            .contentTransition(.numericText())
                        HStack(spacing: 12) {
                            Text("KM/H")
                            Text("G\(session.gear)")
                        }
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.80))
                    }
                    .frame(minWidth: 120)
                    .padding(.bottom, 6)

                    Spacer(minLength: 8)

                    HoldDriveButton(label: "BRAKE", symbol: "minus",
                                    color: NitroTheme.orange,
                                    onPressed: { session.input.brake = $0 })
                    HoldDriveButton(label: "GAS", symbol: "arrow.up",
                                    onPressed: { session.input.gas = $0 })
                    VStack(spacing: 4) {
                        HoldDriveButton(label: "NITRO", symbol: "bolt.fill",
                                        color: NitroTheme.orange,
                                        width: 72, height: 48,
                                        onPressed: { session.input.nitro = $0 })
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.black.opacity(0.65))
                                Capsule().fill(NitroTheme.orange)
                                    .frame(width: geo.size.width * CGFloat(max(0, min(1, session.nitro / 100))))
                            }
                        }
                        .frame(width: 72, height: 7)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)

            if session.isPaused {
                Color.black.opacity(0.68)
                    .ignoresSafeArea()

                GlassPanel {
                    VStack(spacing: 13) {
                        if let result = session.raceResult {
                            Text(result.title)
                                .font(.system(size: 25, weight: .black, design: .rounded))
                            Text("\(result.distance) m • +\(result.reward) CR")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundStyle(NitroTheme.cyan)
                            NitroButton(title: "Race again", highlighted: true) {
                                if session.mode == .online {
                                    session.goToMenu()
                                    session.phase = .leaderboard
                                } else {
                                    session.start(session.mode)
                                }
                            }
                        } else {
                            Text("PAUSED")
                                .font(.system(size: 25, weight: .black, design: .rounded))
                            NitroButton(title: "Resume", symbol: "play.fill", highlighted: true) {
                                session.togglePause()
                            }
                            NitroButton(title: "Restart drive", symbol: "arrow.clockwise") {
                                session.start(session.mode)
                            }
                        }
                        NitroButton(title: "Main menu", symbol: "house.fill") {
                            session.goToMenu()
                        }
                    }
                    .frame(width: 235)
                }
            }
        }
    }
}

#Preview {
    NitroDriftRootView()
        .environmentObject(GameSession())
}
