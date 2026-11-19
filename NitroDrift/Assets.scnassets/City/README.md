# Quayside

Three 150 m city blocks share curtain-wall textures, recessed glass storefronts and modular stonework. Their meshes stay within 62 m of the block center to leave the collision grid clear. The opening boulevard has a separate six-arch span, iron lattice parapets, a canal, stone piers and instanced date palms. The shared facade emission map lights individual office floors after dark.

Run `python3 scripts/build_city_tiles.py` to rebuild the original Y-up COLLADA geometry. Run `python3 scripts/bake_facade.py` with Pillow to rebuild the two facade maps. The runtime also accepts an optional CityBlock.usdz using the same footprint.
