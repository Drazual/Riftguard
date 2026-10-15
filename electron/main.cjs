const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const { autoUpdater } = require('electron-updater');

// Give up and just start the game if GitHub doesn't answer the check, or a download stalls, for this long.
const CHECK_TIMEOUT_MS = 10000;
const DOWNLOAD_STALL_MS = 20000;

let splash;

function createSplash() {
  splash = new BrowserWindow({ width: 420, height: 220, frame: false, resizable: false, center: true, backgroundColor: '#0b0f1c', title: 'Riftguard', webPreferences: { contextIsolation: true } });
  splash.loadFile(path.join(__dirname, 'splash.html'));
}

function setStatus(text, percent) {
  if (!splash || splash.isDestroyed()) return;
  splash.webContents.executeJavaScript(`setStatus(${JSON.stringify(text)}, ${percent == null ? 'null' : percent})`).catch(() => {});
}

// Resolves true when an update was downloaded and is being installed (the app will restart),
// false when the game should just start (no update, offline, error, portable build, or dev run).
function checkForUpdates() {
  return new Promise((resolve) => {
    if (!app.isPackaged || process.env.PORTABLE_EXECUTABLE_DIR) return resolve(false);
    let done = false;
    let timer;
    const finish = (installing) => { if (!done) { done = true; clearTimeout(timer); resolve(installing); } };
    const watchdog = (ms) => { clearTimeout(timer); timer = setTimeout(() => finish(false), ms); };

    autoUpdater.autoDownload = true;
    autoUpdater.autoInstallOnAppQuit = false;
    autoUpdater.on('update-available', (info) => { watchdog(DOWNLOAD_STALL_MS); setStatus(`Downloading update ${info.version}…`, 0); });
    autoUpdater.on('download-progress', (p) => { watchdog(DOWNLOAD_STALL_MS); setStatus(`Downloading update… ${Math.round(p.percent)}%`, p.percent); });
    autoUpdater.on('update-not-available', () => finish(false));
    autoUpdater.on('error', () => finish(false));
    autoUpdater.on('update-downloaded', () => {
      if (done) return;
      finish(true);
      setStatus('Installing update…', 100);
      // Silent install, then relaunch the updated game.
      setTimeout(() => autoUpdater.quitAndInstall(true, true), 500);
    });

    watchdog(CHECK_TIMEOUT_MS);
    // Resolves null when updates aren't supported for this install; nothing else will fire then.
    autoUpdater.checkForUpdates().then((result) => { if (!result) finish(false); }).catch(() => finish(false));
  });
}

function createWindow() {
  // Opens fullscreen by default; the game's settings can switch it off (and remember that).
  const win = new BrowserWindow({ width: 1280, height: 800, minWidth: 800, minHeight: 600, fullscreen: true, backgroundColor: '#0b0f1c', title: 'Riftguard', autoHideMenuBar: true, show: false,
    webPreferences: { contextIsolation: true, preload: path.join(__dirname, 'preload.cjs') } });
  ipcMain.removeAllListeners('fullscreen');
  ipcMain.removeAllListeners('quit');
  ipcMain.on('fullscreen', (_e, on) => win.setFullScreen(on));
  ipcMain.on('quit', () => app.quit());
  win.removeMenu();
  win.loadFile(path.join(__dirname, '..', 'dist', 'index.html'));
  win.once('ready-to-show', () => {
    win.show();
    if (splash && !splash.isDestroyed()) splash.close();
  });
  win.webContents.on('before-input-event', (event, input) => {
    if (input.type === 'keyDown' && input.key === 'F11') {
      win.setFullScreen(!win.isFullScreen());
      event.preventDefault();
    }
  });
}

app.whenReady().then(async () => {
  createSplash();
  const installing = await checkForUpdates();
  if (installing) return;
  setStatus('Starting…', 100);
  createWindow();
});

app.on('window-all-closed', () => app.quit());
