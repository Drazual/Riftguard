# Coral Spiral art

`cut.py` cuts the animated sprites (6 frames each) out of the Coral Spiral sheets into `spr/`: palms, umbrellas,
flags, the neon palm, arcade sign, fan and lamp, the boats and buoys, the fountain, the water tiles and the shore
foam. The sheets sit on a blurred gradient, so each frame's background is fitted from the cell border and
removed. Pass the folder holding the sheets (props.png, city.png, boats.png, water.png, foam.png) as the first
argument; they aren't in the repo.

`compose.py` draws the six backdrop frames into `out/` and writes the road, water and blocked tiles to
`coral_layout.json`. It also uses the Neon City buildings in `../canal_art/spr`.

Run `python3 compose.py` here (needs Pillow, numpy and scipy), copy `out/coral_0.png` ... `coral_5.png` to
`assets/maps/`, and if you moved the road, water or props, rebuild the Ground and Props layers of
`maps/coral_spiral.tscn` to match `coral_layout.json`.
