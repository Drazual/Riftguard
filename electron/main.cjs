const { app, BrowserWindow } = require('electron');
const path = require('path');

function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 960,
    minWidth: 800,
    minHeight: 600,
    backgroundColor: '#0b0f1c',
    title: 'Riftguard',
    autoHideMenuBar: true,
    webPreferences: { contextIsolation: true },
  });
  win.removeMenu();
  win.loadFile(path.join(__dirname, '..', 'dist', 'index.html'));
  // F11 toggles fullscreen.
  win.webContents.on('before-input-event', (event, input) => {
    if (input.type === 'keyDown' && input.key === 'F11') { win.setFullScreen(!win.isFullScreen()); event.preventDefault(); }
  });
}

app.whenReady().then(createWindow);
app.on('window-all-closed', () => app.quit());
