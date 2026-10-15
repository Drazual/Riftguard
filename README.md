# Riftguard

A roguelike tower defense game. You control a hero who fights, blocks the path and builds towers. Towers level up to 10 with unique upgrades and merge into hybrids. Bosses drop heroic powers, and Rift Shards earned each run buy permanent hero upgrades.

Built with [Phaser 3](https://phaser.io) and [Vite](https://vitejs.dev).

## Play on Windows

Go to [the latest release](https://github.com/Drazual/riftguard/releases/latest) and download:

- **Riftguard-x.y.z-setup.exe** to install the game with a desktop shortcut, or
- **Riftguard-x.y.z-portable.exe** to play without installing.

Windows may show a "Windows protected your PC" warning because the app isn't code-signed yet. Click **More info**, then **Run anyway**. Press F11 for fullscreen.

A new release is built automatically every time `main` changes.

## Run it from source

```bash
npm install
npm run dev      # local dev server with hot reload
npm run build    # production build in dist/
npm run desktop  # run as a desktop app (Electron)
npm run dist:win # build the Windows .exe files into release/
```

## Project layout

- `index.html`: page layout (HUD, build bar, panels)
- `src/main.js`: the whole game for now (data, rules, rendering)
- `src/style.css`: UI styles
- `electron/main.cjs`: desktop app window
- `.github/workflows/desktop.yml`: builds and publishes the Windows app
- `docs/game-design.md`: design notes

## Roadmap

- Split `src/main.js` into modules (data, systems, scenes, UI)
- Mobile: wrap the build with [Capacitor](https://capacitorjs.com) for iOS and Android, and add touch-first controls
- Real art and sound
