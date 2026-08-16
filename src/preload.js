const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('universalCapture', {
  captureClipboard: () => ipcRenderer.invoke('capture:clipboard')
});
