# Canal Crossing art

`compose.py` draws the six backdrop frames into `out/` (copy `out/canal_0.png` ... `canal_5.png` to
`assets/maps/`) and writes the road, water and blocked tiles to `canal_layout.json`. The still sprites in
`spr/` were cut from the Neon City sheets with `props.py` and `cut.py`; the animated ones (`spr/anim_*.png`,
6 frames each: palms, flower beds, umbrellas, lamps, fans, the arcade and diner fronts, the ramen sign, the
boats, the entry gate, arrow and rift, and the canal water) with `cut_anim.py`. The sheets themselves aren't
in the repo.

Run `python3 compose.py` here (needs Pillow, numpy and scipy). If you moved the road, water or props, rebuild
the Ground and Props layers of `maps/canal_crossing.tscn` to match `canal_layout.json`.
