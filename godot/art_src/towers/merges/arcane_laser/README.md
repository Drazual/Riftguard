# Prism Lance v2: Arcane Bolt × Prism Laser merge (`arcane+laser`, #FF6FA0)

The model is the same as v1: the Prism Laser head on the Arcane Bolt column, with the arcane crystal as the lance tip.

**v2 attack:** a continuous beam from the crystal tip that heats up the longer it stays on one target.
- **Beam by heat:** cold laser cyan, then pink, then hot arcane magenta with a white core. It gets wider, brighter and flickers more as it heats.
- **Sparks:** on every damage tick, magenta arcane sparks arc off the impact point to nearby enemies and pop on hit. There are more and bigger sparks at higher heat.
- **Model clips:**

  | clip | length |
  |---|---|
  | `idle` | 4.0 s, loops |
  | `charge` | 0.3 s warm-up |
  | `fire` | 0.8 s sustained loop |
  | `spawn` | 1.2 s |

- **Heat look:** `fx/prism_lance_heat.gd` brightens and heats the glows and speeds the clip as heat rises.
- **Effect files:** `fx/` holds the 2D board effects (beam shader and script, spark script).

v1 (the charged bolt) is kept in `../final_v1/` and in the `*_v1.zip` files.

Previews (`previews/`):
- `prism_lance_beam_heat_sparks.gif`: in-engine, heat 0 → 1, sparks jumping to 2–3 dummies.
- `prism_lance_heat_strip.png`: heat 0 / 0.33 / 0.66 / 1.
- `prism_lance_idle_charge_fire.gif`
- `prism_lance_contact_sheet.png`
- `prism_lance_recolor_demo.png`
- `prism_lance_atlas_masks.png`
- `prism_lance_vs_parents.png`
