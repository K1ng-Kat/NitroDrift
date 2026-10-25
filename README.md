# NitroDrift 🏎️

Native **3D street-racing game prototype** for iPhone and iPad, made with SwiftUI + SceneKit + GameKit + AVFoundation. iOS 17+.

## Alpha 0.3 — driving + interaction overhaul

The 0.3 update focuses on fixing intermittent controls and making the experience less toy-like.

- **Controls:** Steering, gas, brake and nitro use independent UIKit \`UIControl\` tracking. They react immediately to touch-down and release on lift, cancellation, moving away, or removal from the window. Controls are individually multitouch-compatible. The underlying SceneKit view no longer receives touches, and the HUD is resized for compact landscape iPhones.
- **Dynamics:** New \`CarDynamics\` single-track arcade model integrates engine force, aerodynamic drag, rolling losses, progressive braking, speed-dependent steering, limited tire grip, lateral slip, yaw inertia, weight transfer and nitrous acceleration at bounded substeps. This is an improved driving approximation, **not a rigid-body racing simulator**.
- **Vehicle:** The player car now has angled windshield/back glass, rounded body panels, side mirrors, split lights, vents, rear diffuser/spoiler, exhaust, detailed rims and coupled wheel spin. The entire generated car remains fictional.
- **World:** Procedural asphalt detail, star-sky gradient, raised sidewalks/curbs, intersection crossings, district landmark signs and more useful nearby street lighting.
- **HUD:** Reorganized speed, nitro, minimap, vehicle inputs, camera, pause, mode timer, and race information to avoid touch-target overlap on narrow screens.

The update **passes the unsigned iOS simulator compile check**. Physical tap reliability and frame rates still need testing on a real iPhone/iPad. Neither simulator compilation nor these simplified visuals imply console-level realism.

## Alpha 0.2 — implemented

| System | What's playable |
|---|---|
| Driving | Steering, gas, brakes, nitro, drifting, chase/hood/aerial cameras, arcade tire-grip assist |
| City | Expanded ~1km x 1km procedural neon city, four named districts, road grid and minimap |
| Traffic | 14 moving street cars and collision damage |
| Racing | Timed 1,600-m Sprint, nine *ordered* circuit checkpoint gates, CPU rival and finish payouts |
| Police | Two pursuing AI police cars, 75-second Hot Pursuit, heat/wanted system |
| Audio | Procedurally synthesized motor loop, electronic soundtrack, boost/crash/checkpoint sounds |
| Garage | Three fictional vehicle tiers, six paints, engine/handling/brake/nitro performance upgrades |
| Career | Persistent credits, driver reputation and level, wins, circuit best and owned cars |
| Online | Game Center two-person live checkpoint match transport, remote rival car and wins leaderboard hooks |

This is **a first integrated playable prototype**, NOT a finished realistic open-world title: handling/bumper collisions are arcade approximations, traffic follows scripted straight roads, police navigation is simplified, cars use primitive placeholder models, the map is finite rather than streamed, career is lightweight, and there are no cloud accounts or multiplayer servers.

## Run in Xcode

1. Clone the repository from https://github.com/K1ng-Kat/NitroDrift .
2. Open **NitroDrift.xcodeproj** and select the NitroDrift app target.
3. Pick your Apple developer Team in Signing & Capabilities (and a unique bundle identifier if yours conflicts).
4. Select an iPhone/iPad simulator or device, then press Command-R.

Offline play requires no external dependencies, paid assets or API keys. Automated **iOS Simulator build verification** runs on every GitHub push; that does not replace device QA.

### Enable Game Center matchmaking (requires setup)

Game Center features require an Apple Developer signing team and Game Center enabled for this app identifier in the Apple Developer portal / App Store Connect. Create an App Store Connect leaderboard with ID **nitrodrift_wins**, or change the ID in **OnlineRacing.swift** to yours. Install signed copies of the same game build on **two separate devices**, with distinct Game Center users, then choose **Online / Rankings → Find 1v1 match**.

Online uses GameKit's real-time match API to send race positions (~10 times/second), checkpoints and a reliable completion packet; the other car is rendered in the scene. Real-device online matchmaking, leaderboards, network failure recovery and provisioning are **not verified** by the CI build. There is no secure authoritative racing backend or cloud economy.

## Controls

LEFT / RIGHT steer; GAS accelerates; BRAKE slows; NITRO boosts; Camera changes chase/hood/aerial; Reset restarts at the origin (and restarts event state); Pause lets you resume, restart, or quit. The map shows nearby streets and the next checkpoint.

## Notes

Progress is stored **locally** in UserDefaults (not cloud-synced or cheat-proof). The project uses generated visuals and original synthesized audio to avoid third-party licensed assets. Game Center entitlement exists in the Xcode project; release signing requires your valid provisioning profile.

## Future production milestones

Real suspension/wheel physics, robust vehicle collisions, smarter traffic/AI navigation, countdown synchronization and online recovery, larger streaming regions, performance profiling on older iPads, fuller career story, more detailed car meshes, cloud saves, and release QA.
