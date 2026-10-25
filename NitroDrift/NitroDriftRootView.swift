import SwiftUI

struct NitroDriftRootView: View {
    @EnvironmentObject private var session: GameSession
    @StateObject private var online = OnlineRacing.shared

    var body: some View {
        GeometryReader { size in
            ZStack {
                GameSceneView(session: session)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

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
                    DrivingHUD(session: session)
                }
            }
            .frame(width: size.size.width, height: size.size.height)
            .foregroundStyle(.white)
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
            .scrollIndicators(.hidden)
            .frame(width: 298)

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                StatPill(symbol: "dollarsign.circle.fill", text: "\(session.cash) CR")
                StatPill(symbol: "star.fill", text: "LVL \(session.level) • \(session.wins) WINS")
                Spacer()
                Text("ALPHA 0.7")
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
                                        .frame(width: 37, height: 37)
                                        .frame(width: 48, height: 48)
                                        .contentShape(Rectangle())
                                        .overlay {
                                            Circle()
                                                .strokeBorder(.white, lineWidth: session.paint == paint ? 3 : 0)
                                                .padding(-3)
                                        }
                                }
                                .buttonStyle(NitroPressStyle())
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
                ScrollView {
                    VStack(alignment: .leading, spacing: 13) {
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
                    Picker("Road condition", selection: Binding(
                        get: { session.weather },
                        set: { session.setWeather($0) }
                    )) {
                        ForEach(StreetWeatherMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Picker("Graphics quality", selection: Binding(
                        get: { session.graphicsQuality },
                        set: { session.setQuality($0) }
                    )) {
                        ForEach(GraphicsQuality.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Screen-space water refraction (experimental)", isOn: Binding(
                        get: { session.screenRefractionEnabled },
                        set: { session.setRefraction($0) }
                    ))
                    .tint(NitroTheme.cyan)
                    Text("Ultra + Rain required. Turn this off if your GPU shows artifacts.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.66))
                    Text("Ultra enables stronger reflections and higher-quality shadows. Balanced saves battery.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.60))
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
                    Text("NitroDrift Alpha 0.7 • iOS 17+")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.47))
                    }
                    .padding(2)
                }
                .scrollIndicators(.hidden)
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
                    .frame(width: 50, height: 50)
                    .contentShape(Rectangle())
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(NitroPressStyle())
            .accessibilityLabel("Back to main menu")

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


}

#Preview {
    NitroDriftRootView()
        .environmentObject(GameSession())
}
