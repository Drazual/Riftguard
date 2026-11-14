# Pixel art test: one 768 grid for everything

Settings > **"Pixel art test (one 768 pixel grid, crisp, live 3D)"** switches it on (`Save.settings.pixel_grid`).
It's off by default, so the game looks the same until you turn it on.

## What it does
- **Maps stay 768 pixel art.** Every map is drawn from its 768x416 pixels, including Ocean Drive, which uses its 1x bake in
  `assets/maps/map1_miami/px1/`. Each map pixel is a whole number of screen pixels.
- **Units get the screen's own pixels ("clear").** The board is drawn at `Board.pixel_detail()` board pixels per map pixel:
  - That's 2 on 1080p and 3 on 1440p, from the map's whole-multiple scale on the screen.
  - Heroes, towers, enemies and effects (the live 3D layer included) are crisp at one screen pixel each.
  - With every unit squeezed onto the 768 grid, they turned into unreadable blobs.
  - `StyleSettings.detail` 1 brings back the all-768 chunky look.
- **No smoothing.** The board is only ever shown at a whole multiple of real screen pixels, with nearest filtering:
  - 2x on 1080p.
  - 3x on 1440p, trimming up to 8% of the map's top and bottom edge (`Board.PIXEL_TRIM`).
  - Zoom goes straight from 1x to 2x.
  - The view and the screen shake sit on whole pixels.
- **Models made for the grid** (`StyleSettings.pixel()`):
  - Heroes and towers are drawn 1.35x their size.
  - Gale uses his flat-colour albedo (`px/*_flat.png`), with no blurred texture reads. Towers keep their own atlases
    (`flat_towers` off), because the automatic flats washed them out.
  - A 1 px outline and rim at the final size.
  - The palette snap (`quantize`) and the 2x averaging (`supersample`) are still there, but off: both muddied colours and edges.

## Rebuilding the baked assets
`python3 godot/tools/pixel_art/bake_pixel.py` (needs Pillow), then reopen the project so Godot re-imports it.
- **The palette** is cut from Coral's art and Ocean Drive at 1x, plus a fixed set of neon accents.
- **Ocean Drive 1x:**
  - The ground and sprites are averaged over 2x2 blocks, given hard alpha and locked to the palette.
  - The glints keep every other pixel, because they hold data.
  - Each sprite starts on an even 2x pixel, so it lands on whole board pixels.
- **Flat textures** are a quick automatic stand-in for a real repaint:
  - Gale's noisy albedo becomes 2 body tones plus big cyan blobs.
  - Tower atlases become 8 tones with a mode filter, with near-white pulled down a step.

## Check
`tests/pixel_grid.tscn -- <out dir> <canal | coral> <old | pixel>` checks:
- the grid sizes and the whole-multiple scale;
- nearest filtering;
- the model scale, the flat textures and the palette;
- the 1x/2x zoom steps, and switching back to the shipped look.

It also saves full-screen shots and close-ups cut from the real screen.
