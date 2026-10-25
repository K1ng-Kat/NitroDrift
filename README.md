# NitroDrift 🏎️

Native **3D street-racing game prototype** for iPhone and iPad, made with SwiftUI + SceneKit + GameKit + AVFoundation. iOS 17+.

## Alpha 0.8 — stable braking, easy mobile controls and brighter graphics

This update directly addresses two issues reported during live gameplay:
holding BRAKE spun the car, and touch controls were awkward/unreliable.

### Braking and physics
- **BRAKE is now independent from DRIFT**: front-biased ABS-inspired service
  braking leaves lateral tire grip available for steering. The handbrake
  intentionally reduces rear grip, but the footbrake does not.
- Unrequested yaw is damped when braking with neutral steering, physical
  yaw response is bounded, and lateral drift is attenuated near a stop.
- Dedicated physics regression tests now simulate straight braking at
  ~94 km/h, brake + steering release, both wet and dry traction, and
  confirm no residual uncontrolled rotation. These passed in CI.

### Asphalt-inspired Easy Drive controls
- **Easy Drive is ON by default**, stored in Settings. The car automatically
  accelerates unless you hold BRAKE or DRIFT. You no longer need to hold
  GAS at the same time as turning.
- Two generous LEFT and RIGHT thumb zones and dedicated BRAKE, DRIFT, and
  NITRO controls; turning Easy Drive off reveals a manual GAS button.
- Native UIKit hold controls retain their press state during small finger
  drags and release on touch lift, cancellation, view removal or disable.
- Touch controls have explicit stable frames and don't recreate images
  on every speedometer update. Other UI buttons have pressed feedback,
  larger hit targets, and accessible online menus.
- Compact minimap has been restored without stealing input events.

### Visual improvements
- **Golden Hour is the new default lighting.** Settings now offers Golden
  Hour, Daylight and Night. Every preset updates sun intensity/color,
  ambient light, environment probe, haze and façade emissive windows.
- Procedural multi-layer cloud backgrounds replace the solid midnight
  gradient when driving by day or at sunset. The skyline, asphalt and
  car paint are much easier to see.
- Lower, closer chase-camera composition with speed-adaptive field of view.
- A soft contact shadow anchors the player car to the asphalt.
- Menu no longer blacks out most of the scene; panels and primary buttons
  have more polished layered gradients and softer edges.
- Retains prior real CC0 PBR asphalt textures, three CC0 USDZ sports car
  files, and photographed Shanghai Bund lighting environment.

**Limits:** These fixes are a more usable and readable SceneKit mobile racer,
not a finished AAA photorealistic game. Automatic acceleration is distinct
from Asphalt's proprietary TouchDrive route-selection system; steering
remains fully player-controlled. Physics tests and simulator compilation
do not prove real-device touch usability or performance. Test on a real
iPhone in both Easy Drive and Manual modes and report any remaining
broken/overlapping controls.

## Alpha 0.7 — visual design and car orientation overhaul

This release responds to real gameplay feedback that the world looked ugly and the
car could appear sideways in the menu or while body roll was animated.

- **Three real CC0, textured USDZ car meshes bundled:** StreetGT (Sports Car),
  ApexR (1990s Sports Car), VortexX (1980s Sports Car) from Grab3D's
  [CC0 1.0 model pages](https://grab3d.com/models/vehicles/sports-car/).
  Assets are shipped offline inside \`Assets.scnassets/Vehicles\`, not fetched
  from the network by the app.
- **Correct car alignment:** Heading/yaw lives exclusively on a world root
  with front local -Z; chassis pitch and roll apply to a separate visual child.
  The asset importer normalizes its vehicle bounding box to about 4.55 m,
  raises the underbody to the ground, and automatically turns assets with an
  X-major longitudinal axis by 90 degrees. The garage and menu camera now
  remains behind the car in a consistent rear three-quarter position instead
  of orbiting to its side.
- **Modern building façades:** Six reusable procedural PBR facade atlases add
  framed, inset windows, varied warm/cool office lighting with separate
  emission maps, subtly detailed panels, ground-level shop glass, parapets,
  roof equipment and selective restrained metal accents. This replaces
  thousands of isolated bright rectangles on solid dark cubes.
- **Beautiful grounded streetscape:** Warmer, directional streetlamp fixtures
  replace hovering cyan glowing balls; subtle trees, roof silhouettes and
  reduced neon introduce visual depth. Traffic cars have shaped PBR bodywork,
  wheels, painted lamps and toned glass instead of bare rectangles.
- **Existing real materials retained:** CC0 asphalt diffuse/normal/roughness,
  nighttime Shanghai Bund image-based lighting, rainy road planar reflections,
  optional screen-space water refraction and tire spray.

**Reality check:** The imported meshes are game-ready lightweight CC0 assets,
not high-budget scanned manufacturer vehicles. Dynamic traffic/navigation,
city architecture, local light and shadow quality, camera realism and refraction
are still mobile-game approximations. Simulator compilation is tested; real
device screenshots, performance, and the exact orientation of each third-party
USDZ asset still require visual QA.

## Alpha 0.6 — real assets + experimental scene refraction

This update moves beyond solely generated textures, although it is not a fully
photorealistic game or a physically correct scene-traced renderer.

**Bundled, legally reusable assets (already in the repository):**
- Poly Haven **Aerial Asphalt 01** (CC0): the real 1K diffuse, normal and
  roughness maps are bundled under Assets.scnassets/Surfaces and automatically
  loaded for both road directions at consistent roughly 8 m texture tiling.
- Poly Haven **Shanghai Bund** nighttime environment (CC0): a photographed
  1024 × 512 city lighting probe, derived from the 1K Radiance HDRI and
  tone-mapped into an iPhone-friendly JPG. Glossy surfaces use it for image-based
  lighting. The game continues using its own geometry and sky background.
- The automated source installers live in scripts/install_pbr_assets.py and
  scripts/install_night_hdri.py. GitHub Actions fetched and committed the assets.
  The game runs offline; it doesn't download textures at launch.

**Rendering engineering:**
- SceneKit SCNTechnique renders normal scene color and separate water masks,
  then a Metal compositor applies **Snell-law screen-space refraction** at
  approximate index of refraction 1.333 with animated slope normals,
  view-dependent Fresnel and subtle channel dispersion.
- This mode enables only with Ultra graphics, Rain weather, and the setting
  Screen-space water refraction (experimental) switched on. Turn off the toggle
  if the device shows shader artifacts or poor FPS. Other settings retain
  SceneKit surface shaders and local reflected-scene planar water.
- A smooth lofted body shell and blended normals replace the boxiest sections
  of the procedurally made player car. These remain original generated shapes,
  **not** an externally authored supercar asset.
- Fixed a real bug: rain traction is now applied to **every** physics
  integration substep, so tire response actually changes in wet conditions.
- CI now smoke-launches an iPhone simulator in Ultra/Rain and saves a
  screenshot artifact in GitHub Actions, in addition to compiling Swift/Metal
  and running drivetrain tests.

**Not yet delivered:** hardware ray-traced scene intersections through water,
multiple refraction bounces, caustics, a complete AAA vehicle and architecture
asset pack, robust reflection occlusion, high-speed traffic AI, physically
modeled suspension, and production performance certification. Current
screen-space transmission samples only **visible pixels**, so it cannot recover
occluded submerged geometry. SceneKit's SCNTechnique path is deprecated by
Apple; a full physically accurate water engine would require a custom Metal
renderer and much larger development effort. Do not advertise the project as
AAA photorealism without real-device profiling and visual QA.

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
