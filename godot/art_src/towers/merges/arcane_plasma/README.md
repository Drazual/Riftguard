# Starbolt (arcane+plasma) — Riftguard merge tower
Recipe `arcane+plasma` ("Starbolt", #FF6FD8). The slim Arcane Bolt column holds a small glowing four-point star made from the Plasma Cannon's teal energy cell between its 3 stone petals; a band of plasma radiator fins wraps the column under the collar and two plasma canisters sit low on the sides. It aims (yaw + pitch). 1.61 m tall.

- `starbolt.glb`: model with embedded textures; 21,091 tris (v1.1); yaw "Turret", pitch "Turret/Gun"; spin node `Star`. Clips: idle 4.0 s (loop), fire 0.45 s (SHOT 0.15 s), supernova 0.45 s (SHOT 0.15 s, bigger), spawn 1.2 s.
- `starbolt_accent_mask.png` (A = arcane), `starbolt_accent_mask_b.png` (B = plasma): R trim, G glow, B detail.
- `tower.json`: Merge3D config + SUGGESTED attack keys (bolt_speed, nova_every, nova_dmg, nova_splash, nova_stars, nova_linger, nova_linger_dps).
- `fx/starbolt_fx.*`: 2D board FX (class StarboltFX): bolt, star splash, supernova + falling stars.
- `CLAUDE_NOTES.md`: integration notes and the mechanic.
