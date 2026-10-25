import SwiftUI
import UIKit

enum GamePhase {
    case menu, driving, garage, settings
}

enum DriveMode {
    case freeRide, sprint
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

struct DriverInput {
    var left = false
    var right = false
    var gas = false
    var brake = false
    var nitro = false

    mutating func clear() {
        left = false
        right = false
        gas = false
        brake = false
        nitro = false
    }
}

struct RaceResult: Identifiable {
    let id = UUID()
    let won: Bool
    let distance: Int
    let reward: Int
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
    @Published var paint: CarPaint
    @Published var cameraMode = 0
    @Published var isPaused = false
    @Published var sprintTime = 90.0
    @Published var sprintDistance = 0.0
    @Published var bestSprintDistance: Int
    @Published var raceResult: RaceResult?
    @Published var hapticsEnabled: Bool

    var input = DriverInput()
    var resetToken = 0

    let sprintGoal = 1600.0
    private let store = UserDefaults.standard

    init() {
        cash = UserDefaults.standard.object(forKey: "cash") as? Int ?? 1200
        engineLevel = UserDefaults.standard.integer(forKey: "engineLevel")
        handlingLevel = UserDefaults.standard.integer(forKey: "handlingLevel")
        bestSprintDistance = UserDefaults.standard.integer(forKey: "bestSprintDistance")
        paint = CarPaint(rawValue: UserDefaults.standard.string(forKey: "paint") ?? "") ?? .electricBlue
        hapticsEnabled = UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true
    }

    func start(_ selection: DriveMode) {
        mode = selection
        sprintTime = 90
        sprintDistance = 0
        speedKPH = 0
        gear = 1
        nitro = 100
        driftScore = 0
        input.clear()
        isPaused = false
        raceResult = nil
        resetToken += 1
        phase = .driving
        feedback(.medium)
    }

    func finishSprint() {
        guard phase == .driving, mode == .sprint, raceResult == nil else { return }
        let won = sprintDistance >= sprintGoal
        let reward = won ? 900 : Int(sprintDistance / 25)
        cash += reward
        store.set(cash, forKey: "cash")
        bestSprintDistance = max(bestSprintDistance, Int(sprintDistance))
        store.set(bestSprintDistance, forKey: "bestSprintDistance")
        raceResult = RaceResult(won: won, distance: Int(sprintDistance), reward: reward)
        input.clear()
        isPaused = true
        feedback(won ? .heavy : .light)
    }

    func updateSprint(delta: TimeInterval, meters: Double) {
        guard phase == .driving, mode == .sprint, !isPaused else { return }
        sprintTime = max(0, sprintTime - delta)
        sprintDistance += max(0, meters)
        if sprintDistance >= sprintGoal || sprintTime <= 0 {
            finishSprint()
        }
    }

    func addDrift(points: Int) {
        guard points > 0, phase == .driving, !isPaused else { return }
        driftScore += points
        let earned = max(1, points / 3)
        cash += earned
        store.set(cash, forKey: "cash")
    }

    func setPaint(_ selection: CarPaint) {
        paint = selection
        store.set(selection.rawValue, forKey: "paint")
        feedback(.light)
    }

    func enginePrice() -> Int { 650 * (engineLevel + 1) }
    func handlingPrice() -> Int { 500 * (handlingLevel + 1) }

    @discardableResult
    func buyEngine() -> Bool {
        let price = enginePrice()
        guard cash >= price, engineLevel < 5 else { return false }
        cash -= price
        engineLevel += 1
        saveUpgrades()
        feedback(.medium)
        return true
    }

    @discardableResult
    func buyHandling() -> Bool {
        let price = handlingPrice()
        guard cash >= price, handlingLevel < 5 else { return false }
        cash -= price
        handlingLevel += 1
        saveUpgrades()
        feedback(.medium)
        return true
    }

    func togglePause() {
        guard phase == .driving, raceResult == nil else { return }
        isPaused.toggle()
        input.clear()
    }

    func goToMenu() {
        input.clear()
        isPaused = false
        raceResult = nil
        phase = .menu
    }

    func resetCar() {
        resetToken += 1
        input.clear()
        speedKPH = 0
        gear = 1
        feedback(.light)
    }

    func cycleCamera() {
        cameraMode = (cameraMode + 1) % 3
        feedback(.light)
    }

    func setHaptics(_ value: Bool) {
        hapticsEnabled = value
        store.set(value, forKey: "haptics")
    }

    func feedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func saveUpgrades() {
        store.set(cash, forKey: "cash")
        store.set(engineLevel, forKey: "engineLevel")
        store.set(handlingLevel, forKey: "handlingLevel")
    }
}
