# Included (when installer succeeds) CC0 sports-car models

These original fictional models are from Grab3D, which labels them CC0 1.0:
- StreetGT.usdz: https://grab3d.com/models/vehicles/sports-car/
- ApexR.usdz: https://grab3d.com/models/vehicles/1990s-sports-car/
- VortexX.usdz: https://grab3d.com/models/vehicles/1980s-sports-car/

Models are not real automaker products, and are not photogrammetry-scanned.
Their bundled 2K PBR maps, wheel geometry and body silhouettes are more detailed
than NitroDrift's previous primitives. Respect asset licensing if swapping them.

The binary files are installed once in GitHub Actions using
scripts/install_cc0_cars.py. If the remote CDN is unavailable, the original
game remains playable using the built-in modeled car, and the installer must
be retried. Import orientation follows the wheel hubs. Unrigged replacement models can supply a mesh named `paint` for garage colors.

The three bundled cars use their source wheel hubs to establish forward, up and steering pivots. Each garage finish has a matched 2K body atlas with two tapered deck stripes and retains the source material detail. A separate UV mask drives brake illumination. To rebuild the finishes from the bundled models, run `python3 scripts/bake_vehicle_finishes.py` with NumPy, Pillow and OpenUSD's Python bindings.
