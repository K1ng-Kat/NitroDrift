# NitroDrift 🏎️

Native **3D street-racing game prototype** for iPhone and iPad, made with SwiftUI + SceneKit + GameKit + AVFoundation. iOS 17+.

## Alpha 0.5 — wet-road / water rendering

The rain mode now has physically motivated, GPU-animated water visuals rather than just flat blue transparent rectangles:

- **One bounded live planar-reflection pass** using \`SCNFloor\` follows the nearby road. Nearby buildings, vehicles and lamps can actually appear in its reflection. The reflection is not ray traced and only covers a local 21 × 66 m wet roadway; the infinite base terrain's redundant reflection pass is disabled.
- **Metal shader modifiers on puddles and wet film** animate overlapping capillary wave and ring patterns, alter tangent-space normals, approximate Fresnel view-angle reflectance and produce variable transmission / refraction-*like* tint and ripple distortion. The asphalt beneath stays visible. These are **not physically correct framebuffer refraction or screen-space ray-traced reflections**.
- **Procedural wet/dry normal maps** add micro-surface roughness to roads without downloading texture assets. Water remains non-metallic (dielectric) and wet asphalt becomes optically smoother.
- **Wet tire spray** uses two speed-dependent particle systems behind the rear tires, with rate capped by the selected quality mode. This sits alongside the existing scene rain.
- **Ultra graphics quality**: higher-resolution local mirror (0.55 offscreen reflection scale), stronger shadow quality (2K shadow map), extra rain and spray. Cinematic retains a lower-cost local mirror (0.34), while Balanced disables the mirror and reduces particles. These are qualitative presets, not promises of a particular FPS.
- Wet mode remains available in **Settings → Road condition → Rain**. Choose **Settings → Graphics quality → Ultra** for maximum visual effects. The new settings are persisted across app launches.

**Validation:** iOS simulator compilation and pure Swift physics tests run in GitHub Actions. A successful build does **not** establish that the water shader compiled successfully at runtime on all GPUs, or that the visuals meet photorealism expectations. The shaders should be inspected on an actual iPhone/iPad and optimized with Xcode's GPU frame debugger. SceneKit has rendering limits; true screen-space/ray-traced refraction, expansive city reflections and AAA fidelity would require a deeper custom Metal/modern game-engine renderer and licensed high-detail environment assets.

## Alpha 0.4 — realism systems

This is an integrated realism-focused **mobile prototype**, not photorealism.

- A new force-based, rear-wheel-drive bicycle model uses an automatic six-speed gearbox, simulated engine torque versus RPM, shift interruption, aerodynamic drag, rolling resistance, front/rear slip angles, cornering stiffness, friction-circle tire-force saturation, longitudinal load transfer, lateral yaw inertia, ESC-like optional assist, and separate rear handbrake behavior. Physics is substepped to reduce frame-rate sensitivity.
- Analog Game Controller support: left stick steers, right trigger throttles, left trigger brakes, A uses nitro, and X applies the handbrake. On-screen gas/steering/nitro remain independent multitouch controls.
- Wet road mode alters the grip coefficient, darkens pavement, displays localized SceneKit rain particles and reflective puddles, and reduces distant visibility. Choose Dry or Rain in settings.
- Physically based scene materials now receive environment-based illumination. Cinematic graphics mode enables HDR exposure, subtle bloom, ambient occlusion and moonlight shadows; Balanced reduces effects to preserve performance on lower-memory devices.
- Chase camera eases through turns with anticipation, acceleration-responsive field of view and light collision shake. Brake lights and forward-pointing headlights now react correctly.
- Tire marks are recycled to avoid permanent GPU node growth; AI city traffic now approaches red lights using the same timing phase as visible intersection signal poles.
- The game can load **optional authored vehicle models** named StreetGT.usdz, ApexR.usdz, and VortexX.usdz from its asset directory. Optional legally licensed low/high RPM engine recordings can replace the synthesized fallback and crossfade with the simulated RPM.
- A Swift CLI physics test exercises acceleration, braking, gears, wet/dry grip differences, analog controller input and numerical stability in GitHub Actions.

**Known limits:** The current bundled car and city are still procedural geometry. Real production-scale photorealism requires detailed externally authored vehicles and environments, PBR texture sets, baked lighting / reflection probes, engine recordings and real-device profiling. This is not a validated full rigid-body multibody simulation. Traffic remains scripted and simplified, multiplayer is still a prototype, and no real-world trademarked vehicles or commercial asset libraries are bundled. Compilation and deterministic smoke tests do **not** establish device FPS, collision realism, or finished gameplay quality.

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
