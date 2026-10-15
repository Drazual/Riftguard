# Riftguard

A roguelike tower defense game. You control a hero who fights, blocks the path and builds towers. Towers level up to 12 along 3 of their 5 upgrade paths, ascend into a form named after those paths, and merge into hybrids with unique fusion effects. Boss waves open a shop, and Rift Shards earned each run buy permanent hero upgrades.

See [CHANGELOG.md](CHANGELOG.md) for everything that has changed in each version.

Built with [Phaser 3](https://phaser.io) and [Vite](https://vitejs.dev).

## Play on Windows

Go to [the latest release](https://github.com/Drazual/riftguard/releases/latest) and download:

- **Riftguard-x.y.z-setup.exe** to install the game with a desktop shortcut. The installed game checks for updates every time you open it, installs any it finds, then starts.
- **Riftguard-x.y.z-portable.exe** to play without installing. This one does not update itself.

Windows may show a "Windows protected your PC" warning because the app isn't code-signed yet. Click **More info**, then **Run anyway**. The game opens fullscreen. Press Esc (or the gear) for settings, and F11 to toggle fullscreen.

**Sharing with testers:** send them the [latest release](https://github.com/Drazual/riftguard/releases/latest) link and have them install the setup file. Their copy updates itself just like yours. Progress is saved per computer.

A new release is built automatically every time `main` changes, with the newest [changelog](CHANGELOG.md) section as its release notes. Each build's version is the `major.minor` from `package.json` plus the build number, so installed copies always see it as newer. Updates are downloaded from this repo's releases, so the repo (or wherever releases are published) must be public.

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
- `electron/main.cjs`: desktop app window and update check
- `electron/preload.cjs`: lets the game toggle fullscreen and quit
- `electron/splash.html`: the "Checking for updates" screen
- `.github/workflows/desktop.yml`: builds and publishes the Windows app
- `docs/game-design.md`: design notes

## Roadmap

- Split `src/main.js` into modules (data, systems, scenes, UI)
- Mobile: wrap the build with [Capacitor](https://capacitorjs.com) for iOS and Android, and add touch-first controls
- Real art and sound
