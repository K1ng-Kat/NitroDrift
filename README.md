# NitroDrift 🏎️

**A native 3D street-racing game for iPhone and iPad.** Built with SwiftUI + SceneKit in Xcode.

## Alpha 0.1 — first playable prototype

- Procedural neon city with an interconnected road grid, buildings, road markings, and lighting
- Drive a 3D car using on-screen steering, accelerator, brake, and nitro controls
- Arcade handling, collision with off-road blocks, smooth chase/hood/high cameras
- Free Ride and a timed Sprint Challenge
- Drift scores, earned credits, upgrades, paint customization, locally saved progress
- Landscape iPhone and iPad interface; works offline without external assets

This is a **prototype**, not a finished open-world AAA game. Multiplayer, licensed vehicles, realistic wheel physics, traffic AI, police pursuits, narrative career, and larger environments are future milestones, **not** implemented features.

## Open in Xcode

1. Clone this repository to your Mac.
2. Open `NitroDrift.xcodeproj` in Xcode 16+ (Xcode 27 recommended).
3. Select the `NitroDrift` target, choose your Apple development team in Signing & Capabilities, and choose an iPhone or iPad.
4. Press **Run** (⌘R). No external dependencies or API keys.

The app defaults to landscape orientation and targets iOS/iPadOS 17+.

## Controls

- **Left/right arrows** steer; **GAS** accelerates; **BRAKE** decelerates
- **NITRO** gives a short speed boost and gradually regenerates
- **Camera** cycles chase, close/hood, and high views
- **Reset** places the car back on the road
- **Pause** pauses the simulation; return to menu from the pause overlay

In the garage, spend credits on engine and handling upgrades or choose a paint color. Progress saves locally using UserDefaults.

## Roadmap

1. **Alpha 0.1** — playable driving core, procedural streets, garage, drift, sprint
2. **Alpha 0.2** — checkpoint racing, AI opponents and traffic, collision improvement
3. **Alpha 0.3** — bigger world, custom models, audio, tuned handling
4. **Alpha 0.4** — career mode, profile, challenges, more customization
5. **Online milestone** — matchmaking, crews, events, cloud saves and security

All game visuals are generated in code. No third-party assets or copyrighted car badges are bundled.
