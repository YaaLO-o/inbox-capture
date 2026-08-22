const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('universalCapture', {
  captureClipboard: () => ipcRenderer.invoke('capture:clipboard'),
  moveWindow: (x, y) => ipcRenderer.send('window:move', { x, y })
});
