# Authored environment assets

Place a legally licensed, game-ready `CityBlock.usdz` (or `CityBlock.scn`) in this folder to replace the placeholder block buildings.

## Asset contract

- Model units: **metres**. Orientation: **Y-up**, ground height at **Y=0**.
- A tile covers **150 × 150 metres**, centered at its local origin.
- Roads run on the 150 m grid, leaving the tile perimeter road corridor clear. Keep road and collision surfaces out of the model; NitroDrift supplies those itself.
- Geometry should stay inside approximately **±62 metres** of the tile center in X and Z. Use storefronts, signs, trees, parking and realistic building silhouettes inside this footprint.
- Use physically based metal/rough materials; embed/licence all image textures. Author real facade normal/roughness/base color maps and LODs for distant buildings.
- Repetition is deliberate: the same scene is instanced across 36 blocks. Author multiple tile variants or an asset streaming system before attempting a unique AAA city.
- Test on a real device in all three graphics settings and day/night/rain. High-resolution textures on every surface without LODs can exhaust iPad memory.

If the file is absent or cannot be parsed, the app renders the original procedural city. This asset folder alone does not increase install size to 1 GB or imply that AAA assets are bundled.
