# Rift Creep maps

Maps 4 to 7 (Cracked Avenue, Rift Canal, Chroma Reactor, Rift Islands) go deeper into the rift, one step darker each.
They are all made here from code, Rift Plaza's recipe made general (Coral Spiral's road and tiles on a 15 x 15 diamond
tower grid, at the game's one true isometric camera angle, `StyleRig.PITCH`).

    python3 tools/rift_maps/build.py            # the void props, then every map
    python3 tools/rift_maps/build.py islands    # one map
    python3 tools/rift_maps/build.py --ascii    # a quick text look at every layout
    python3 tools/rift_maps/preview.py assets/maps/map6_islands out.png   # the ground with its sprites laid on

Needs numpy and Pillow.

- `maps.py`: one config per map: its lanes (road corners on the tile grid), canal tiles, island tiles, scars (void
  crystals on the square, no building) and `rift`, 0..1, how far gone the city is.
- `mapgen.py`: ground, glints, glow, build mask and `layout.json`. Several lanes are written as `"paths"`; they must be
  the same length and share the road from where they join (`equalize` in maps.py pads a shorter one off the board).
- `corrupt.py`: the corruption pass on Ocean Drive's sprites: colours drain toward violet, neon shifts magenta,
  glowing cracks, crystals at the foot. Each map keeps its corrupted copies in its own `spr/`.
- `voidprops.py`: the void prop set in `assets/maps/rift_props/`: crystal clusters, monoliths, alien growths,
  floating street chunks, rubble.
