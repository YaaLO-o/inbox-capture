const { app, BrowserWindow, clipboard, ipcMain } = require('electron');
const fs = require('node:fs/promises');
const path = require('node:path');

const { appendCapture } = require('./capture-store');
const { captureCurrentClipboard } = require('./capture-service');
const { resolveObsidianCapturePath } = require('./obsidian-vault');

const isSmokeTest = process.argv.includes('--smoke-test');

function createWindow() {
  const window = new BrowserWindow({
    width: 116,
    height: 132,
    frame: false,
    transparent: true,
    backgroundColor: '#00000000',
    alwaysOnTop: true,
    resizable: false,
    maximizable: false,
    minimizable: false,
    fullscreenable: false,
    skipTaskbar: true,
    hasShadow: false,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true
    }
  });

  window.loadFile(path.join(__dirname, 'renderer', 'index.html'));
}

async function resolveDefaultCapturePath() {
  return resolveObsidianCapturePath({
    configPath: path.join(app.getPath('appData'), 'obsidian', 'obsidian.json')
  });
}

async function captureToObsidian() {
  let filePath;

  try {
    filePath = await resolveDefaultCapturePath();
  } catch (error) {
    return {
      status: 'vault-not-found',
      message: error instanceof Error ? error.message : String(error)
    };
  }

  return captureCurrentClipboard({
    readText: () => clipboard.readText(),
    append: appendCapture,
    filePath,
    now: () => new Date()
  });
}

function registerCaptureHandler() {
  ipcMain.handle('capture:clipboard', captureToObsidian);
}

async function runSmokeTest() {
  const filePath = process.env.UNIVERSAL_CAPTURE_SMOKE_PATH;
  const smokeText = '通用采集器冒烟测试';

  if (!filePath) {
    throw new Error('缺少 UNIVERSAL_CAPTURE_SMOKE_PATH');
  }

  const originalText = clipboard.readText();

  try {
    clipboard.writeText(smokeText);
    const result = await captureCurrentClipboard({
      readText: () => clipboard.readText(),
      append: appendCapture,
      filePath,
      now: () => new Date(2026, 7, 16, 16, 0, 0)
    });
    const markdown = await fs.readFile(filePath, 'utf8');

    if (result.status !== 'saved' || !markdown.includes(smokeText)) {
      throw new Error('剪贴板到 Markdown 的验证结果不正确');
    }

    console.log(`SMOKE_OK ${filePath}`);
  } finally {
    clipboard.writeText(originalText);
  }
}

app.whenReady().then(async () => {
  if (isSmokeTest) {
    try {
      await runSmokeTest();
      app.exit(0);
    } catch (error) {
      console.error(error);
      app.exit(1);
    }
    return;
  }

  registerCaptureHandler();
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  app.quit();
});
