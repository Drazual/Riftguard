# Riftguard

A roguelike tower defense game. You control a hero who fights, blocks the path and builds towers. Towers level up to 10 with unique upgrades and merge into hybrids. Bosses drop heroic powers, and Rift Shards earned each run buy permanent hero upgrades.

Built with [Phaser 3](https://phaser.io) and [Vite](https://vitejs.dev).

## Run it

```bash
npm install
npm run dev      # local dev server with hot reload
npm run build    # production build in dist/
```

## Project layout

- `index.html`: page layout (HUD, build bar, panels)
- `src/main.js`: the whole game for now (data, rules, rendering)
- `src/style.css`: UI styles
- `docs/game-design.md`: design notes

## Roadmap

- Split `src/main.js` into modules (data, systems, scenes, UI)
- Mobile: wrap the build with [Capacitor](https://capacitorjs.com) for iOS and Android, and add touch-first controls
- Real art and sound
