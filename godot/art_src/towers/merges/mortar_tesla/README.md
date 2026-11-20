# Thunder Battery (mortar+tesla)
Merge tower #9. The real Siege Mortar, tesla'd (a copper winding, coil collars, cyan glow), with 3 small Tesla coils
on its gear ring that charge a lightning ball at the mouth (a visible ~0.6–0.85 s charge). The mortar then fires it
very fast (1500 px/s, low lob) into a big crackling AoE blast.
38,186 tris (35.9k body + 2.3k FX), 1.37 m tall (ball at 1.41 m). Clips idle 4.0 s / fire 1.2 s (shot 0.85 s) / spawn 1.2 s.
See CLAUDE_NOTES.md for the node tree, clips and mechanic. Built with the Blender 4.2 pipeline from the parents' .blend files
(scripts in source/scripts). blender-skills QA was run as advisory only: no --fix, and nothing installed into skills dirs.

v1.1: the charge arcs (3D and the 2D overlay) start exactly on each coil's tip (CoilTip0-2 markers + tower.json charge_tips).
