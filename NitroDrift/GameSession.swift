import SwiftUI
import UIKit

enum GamePhase { case menu, driving, garage, settings, events, leaderboard }
enum DriveMode: String, CaseIterable {
    case freeRide = "Free Ride"
    case sprint = "Sprint"
    case circuit = "Circuit"
    case pursuit = "Hot Pursuit"
}

enum CarPaint: String, CaseIterable, Identifiable {
    case electricBlue, inferno, pearl, venom, midnight, violet
    var id: String { rawValue }
    var title: String {
        switch self {
        case .electricBlue: return "Electric Blue"
        case .inferno: return "Inferno Red"
        case .pearl: return "Arctic Pearl"
        case .venom: return "Venom Green"
        case .midnight: return "Stealth Black"
        case .violet: return "Neon Violet"
        }
    }
    var color: UIColor {
        switch self {
        case .electricBlue: return UIColor(red: 0.06, green: 0.45, blue: 0.98, alpha: 1)
        case .inferno: return UIColor(red: 0.95, green: 0.10, blue: 0.19, alpha: 1)
        case .pearl: return UIColor(red: 0.91, green: 0.94, blue: 1, alpha: 1)
        case .venom: return UIColor(red: 0.22, green: 0.92, blue: 0.45, alpha: 1)
        case .midnight: return UIColor(red: 0.08, green: 0.10, blue: 0.15, alpha: 1)
        case .violet: return UIColor(red: 0.63, green: 0.27, blue: 0.98, alpha: 1)
        }
    }
}

enum CarStyle: Int, CaseIterable, Identifiable {
    case street, sport, hyper
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .street: return "Street GT"
        case .sport: return "Apex R"
        case .hyper: return "Vortex X"
        }
    }
    var price: Int {
        switch self {
        case .street: return 0
        case .sport: return 6500
        case .hyper: return 16000
        }
    }
    var speedBonus: Double { Double(rawValue) * 8.5 }
}

struct DriverInput {
    var left = false, right = false, gas = false, brake = false, nitro = false
    mutating func clear() { left = false; right = false; gas = false; brake = false; nitro = false }
}

struct RaceResult: Identifiable {
    let id = UUID()
    let won: Bool
    let distance: Int
    let reward: Int
    let title: String
}

final class GameSession: ObservableObject {
    @Published var phase: GamePhase = .menu
    @Published var mode: DriveMode = .freeRide
    @Published var speedKPH = 0
    @Published var gear = 1
    @Published var nitro = 100.0
    @Published var driftScore = 0
    @Published var cash: Int
    @Published var engineLevel: Int
    @Published var handlingLevel: Int
    @Published var brakeLevel: Int
    @Published var nitroLevel: Int
    @Published var paint: CarPaint
    @Published var carStyle: CarStyle
    @Published var ownedCarStyles: Set<Int>
    @Published var cameraMode = 0
    @Published var isPaused = false
    @Published var sprintTime = 90.0
    @Published var sprintDistance = 0.0
    @Published var bestSprintDistance: Int
    @Published var raceResult: RaceResult?
    @Published var hapticsEnabled: Bool
    @Published var musicEnabled: Bool
    @Published var soundEnabled: Bool
    @Published var raceCheckpoint = 0
    @Published var raceCheckpointTotal = 0
    @Published var racePosition = 1
    @Published var wantedLevel = 0
    @Published var heat = 0.0
    @Published var district = "DOWNTOWN"
    @Published var cashEarned = 0
    @Published var reputation: Int
    @Published var level: Int
    @Published var wins: Int
    @Published var bestCircuitTime: Double
    @Published var raceElapsed = 0.0
    @Published var damage = 0.0
    @Published var policeNearby = false
    @Published var handlingAssist = true

    var input = DriverInput()
    var resetToken = 0
    let sprintGoal = 1600.0
    private let store = UserDefaults.standard

    init() {
        let s = UserDefaults.standard
        cash = s.object(forKey: "cash") as? Int ?? 1200
        engineLevel = s.integer(forKey: "engineLevel")
        handlingLevel = s.integer(forKey: "handlingLevel")
        brakeLevel = s.integer(forKey: "brakeLevel")
        nitroLevel = s.integer(forKey: "nitroLevel")
        bestSprintDistance = s.integer(forKey: "bestSprintDistance")
        paint = CarPaint(rawValue: s.string(forKey: "paint") ?? "") ?? .electricBlue
        carStyle = CarStyle(rawValue: s.integer(forKey: "carStyle")) ?? .street
        ownedCarStyles = Set((s.array(forKey: "ownedCars") as? [Int] ?? [0]) + [0])
        hapticsEnabled = s.object(forKey: "haptics") as? Bool ?? true
        soundEnabled = s.object(forKey: "soundEnabled") as? Bool ?? true
        musicEnabled = s.object(forKey: "musicEnabled") as? Bool ?? true
        reputation = s.integer(forKey: "reputation")
        level = max(1, s.integer(forKey: "level"))
        wins = s.integer(forKey: "wins")
        bestCircuitTime = s.double(forKey: "bestCircuitTime")
        handlingAssist = s.object(forKey: "handlingAssist") as? Bool ?? true
    }

    func start(_ selection: DriveMode) {
        mode = selection
        sprintTime = selection == .circuit ? 180 : selection == .pursuit ? 75 : 90
        sprintDistance = 0
        raceElapsed = 0
        speedKPH = 0
        gear = 1
        nitro = 100
        driftScore = 0
        raceCheckpoint = 0
        raceCheckpointTotal = 0
        racePosition = 1
        heat = 0
        wantedLevel = 0
        damage = 0
        policeNearby = false
        input.clear()
        isPaused = false
        raceResult = nil
        resetToken += 1
        phase = .driving
        feedback(.medium)
    }

    func finishSprint() {
        guard phase == .driving && raceResult == nil else { return }
        let won = sprintDistance >= sprintGoal
        completeEvent(won: won, distance: Int(sprintDistance), title: won ? "SPRINT COMPLETE" : "TIME'S UP",
                      reward: won ? 900 : max(0, Int(sprintDistance / 25)))
        bestSprintDistance = max(bestSprintDistance, Int(sprintDistance))
        store.set(bestSprintDistance, forKey: "bestSprintDistance")
    }

    func completeEvent(won: Bool, distance: Int, title: String, reward: Int) {
        guard phase == .driving && raceResult == nil else { return }
        let total = max(0, reward)
        earn(total, reputation: won ? 140 : 35)
        if won {
            wins += 1
            store.set(wins, forKey: "wins")
        }
        if won && mode == .circuit && (bestCircuitTime == 0 || raceElapsed < bestCircuitTime) {
            bestCircuitTime = raceElapsed
            store.set(bestCircuitTime, forKey: "bestCircuitTime")
        }
        raceResult = RaceResult(won: won, distance: distance, reward: total, title: title)
        input.clear()
        isPaused = true
        feedback(won ? .heavy : .light)
        if won { OnlineRacing.shared.submitScore(wins) }
    }

    func updateSprint(delta: TimeInterval, meters: Double) {
        guard phase == .driving && !isPaused && raceResult == nil else { return }
        raceElapsed += delta
        if mode == .freeRide { return }
        sprintTime = max(0, sprintTime - delta)
        if mode == .sprint {
            sprintDistance += max(0, meters)
            if sprintDistance >= sprintGoal || sprintTime <= 0 { finishSprint() }
        }
        if mode == .circuit && sprintTime <= 0 {
            completeEvent(won: false, distance: raceCheckpoint, title: "RACE TIMEOUT", reward: 100)
        }
        if mode == .pursuit && sprintTime <= 0 {
            completeEvent(won: heat < 60, distance: Int(heat), title: heat < 60 ? "ESCAPED!" : "BUSTED", reward: heat < 60 ? 1100 : 80)
        }
    }

    func earn(_ amount: Int, reputation gainedRep: Int = 0) {
        guard amount > 0 || gainedRep > 0 else { return }
        cash += amount
        cashEarned += amount
        reputation += gainedRep
        level = max(1, 1 + reputation / 400)
        store.set(cash, forKey: "cash")
        store.set(reputation, forKey: "reputation")
        store.set(level, forKey: "level")
    }

    func addDrift(points: Int) {
        guard points > 0 && phase == .driving && !isPaused else { return }
        driftScore += points
        earn(max(1, points / 3), reputation: max(1, points / 7))
    }

    func setPaint(_ selection: CarPaint) {
        paint = selection; store.set(selection.rawValue, forKey: "paint"); feedback(.light)
    }

    @discardableResult
    func selectOrBuyCar(_ style: CarStyle) -> Bool {
        if !ownedCarStyles.contains(style.rawValue) {
            guard cash >= style.price else { return false }
            cash -= style.price
            store.set(cash, forKey: "cash")
            ownedCarStyles.insert(style.rawValue)
            store.set(Array(ownedCarStyles), forKey: "ownedCars")
        }
        carStyle = style
        store.set(style.rawValue, forKey: "carStyle")
        feedback(.medium)
        resetToken += 1
        return true
    }

    func enginePrice() -> Int { 650 * (engineLevel + 1) }
    func handlingPrice() -> Int { 500 * (handlingLevel + 1) }
    func brakePrice() -> Int { 420 * (brakeLevel + 1) }
    func nitroPrice() -> Int { 575 * (nitroLevel + 1) }

    @discardableResult
    func buyEngine() -> Bool { purchase("engineLevel", price: enginePrice()) }
    @discardableResult
    func buyHandling() -> Bool { purchase("handlingLevel", price: handlingPrice()) }
    @discardableResult
    func buyBrakes() -> Bool { purchase("brakeLevel", price: brakePrice()) }
    @discardableResult
    func buyNitro() -> Bool { purchase("nitroLevel", price: nitroPrice()) }

    private func purchase(_ key: String, price: Int) -> Bool {
        let value: Int
        switch key {
        case "engineLevel": value = engineLevel
        case "handlingLevel": value = handlingLevel
        case "brakeLevel": value = brakeLevel
        default: value = nitroLevel
        }
        guard cash >= price && value < 5 else { return false }
        cash -= price
        let upgraded = value + 1
        switch key {
        case "engineLevel": engineLevel = upgraded
        case "handlingLevel": handlingLevel = upgraded
        case "brakeLevel": brakeLevel = upgraded
        default: nitroLevel = upgraded
        }
        store.set(cash, forKey: "cash")
        store.set(upgraded, forKey: key)
        feedback(.medium)
        return true
    }

    func togglePause() {
        guard phase == .driving && raceResult == nil else { return }
        isPaused.toggle(); input.clear()
    }

    func goToMenu() {
        input.clear()
        isPaused = false
        raceResult = nil
        phase = .menu
    }

    func resetCar() {
        resetToken += 1; input.clear(); speedKPH = 0; gear = 1
        feedback(.light)
    }
    func cycleCamera() { cameraMode = (cameraMode + 1) % 3; feedback(.light) }
    func setHaptics(_ value: Bool) { hapticsEnabled = value; store.set(value, forKey: "haptics") }
    func setSound(_ value: Bool) { soundEnabled = value; store.set(value, forKey: "soundEnabled") }
    func setMusic(_ value: Bool) { musicEnabled = value; store.set(value, forKey: "musicEnabled") }
    func setAssist(_ value: Bool) { handlingAssist = value; store.set(value, forKey: "handlingAssist") }

    func feedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
