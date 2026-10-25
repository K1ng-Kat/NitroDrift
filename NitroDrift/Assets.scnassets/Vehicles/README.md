# High-fidelity vehicle assets (USDZ / SCN)

NitroDrift supports replacing its generated car mesh with an authored PBR vehicle.
A built-in fallback remains so that the game can run without any extra downloads.

Place **StreetGT.usdz**, **ApexR.usdz**, or **VortexX.usdz** in this folder
(\`NitroDrift/Assets.scnassets/Vehicles/\`). \`.scn\` is also accepted.

Model requirements:
- Units are **metres**. Length around 4.6 m, height around 1.45 m, width around 2.1 m.
- Coordinate system: **+Y up**, **front faces -Z**, pivot at ground center.
- Use separate wheel-pivot groups called \`wheel_fl\`, \`wheel_fr\`,
  \`wheel_rl\`, \`wheel_rr\`, each with a direct child called \`roll\` for rotation.
- Name paintable mesh nodes \`paint\` or \`paint_...\`.
- Bake UVs and include PBR base color, normal, metalness/roughness and ambient
  occlusion where licensed.
- Export a model you own or have permission to distribute, retaining source
  license and attribution where required.
- Aim for a range of model LODs (e.g. a detailed high profile and lightweight
  driving LOD), keeping textures modest on older iPhones/iPads.

No third-party car models, real brands, or copyrighted textures are included.
Import is optional and does not imply an existing high-fidelity asset is bundled.
