# Canal Crossing art

`compose.py` draws `assets/maps/canal_backdrop.png` and writes the road, water and blocked tiles to
`canal_layout.json`. The sprites in `spr/` were cut from the Neon City sheets with `props.py` and `cut.py`
(the sheets themselves aren't in the repo).

Run `python3 compose.py` here (needs Pillow, numpy and scipy), copy `canal_backdrop.png` to
`assets/maps/`, and if you moved the road, water or props, rebuild the Ground and Props layers of
`maps/canal_crossing.tscn` to match `canal_layout.json`.
