// Exposes a few desktop-only controls to the game (fullscreen and quit).
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('desktop', {
  setFullscreen: (on) => ipcRenderer.send('fullscreen', !!on),
  quit: () => ipcRenderer.send('quit'),
});
