const button = document.querySelector('#capture-button');
const status = document.querySelector('#status');

const messages = {
  saved: '已保存',
  empty: '剪贴板没有文本',
  error: '保存失败',
  'vault-not-found': '未找到 Obsidian 仓库'
};

button.addEventListener('click', async () => {
  if (button.disabled) return;

  button.disabled = true;
  status.textContent = '正在保存…';

  try {
    const result = await window.universalCapture.captureClipboard();
    status.textContent = messages[result.status] || '保存失败';
  } catch {
    status.textContent = '保存失败';
  }

  window.setTimeout(() => {
    status.textContent = '点击保存';
    button.disabled = false;
  }, 1200);
});
