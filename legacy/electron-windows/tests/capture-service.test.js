const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');

const { appendCapture } = require('../src/capture-store');
const { captureCurrentClipboard } = require('../src/capture-service');

async function makeTemporaryCapture(t) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'universal-capture-service-'));
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  return path.join(root, 'captures.md');
}

test('读取文本后通过真实写入模块保存', async (t) => {
  const filePath = await makeTemporaryCapture(t);

  const result = await captureCurrentClipboard({
    readText: () => '剪贴板文本',
    append: appendCapture,
    filePath,
    now: () => new Date(2026, 7, 16, 15, 0, 0)
  });

  assert.deepEqual(result, { status: 'saved', filePath });
  assert.equal(
    await fs.readFile(filePath, 'utf8'),
    '## 2026-08-16 15:00:00\n\n剪贴板文本\n\n---\n\n'
  );
});

test('空剪贴板返回 empty 且不创建文件', async (t) => {
  const filePath = await makeTemporaryCapture(t);

  const result = await captureCurrentClipboard({
    readText: () => '  ',
    append: appendCapture,
    filePath,
    now: () => new Date(2026, 7, 16, 15, 0, 0)
  });

  assert.deepEqual(result, { status: 'empty' });
  await assert.rejects(fs.access(filePath), { code: 'ENOENT' });
});

test('写入异常转换为界面可处理的 error 结果', async () => {
  const result = await captureCurrentClipboard({
    readText: () => '内容',
    append: async () => {
      throw new Error('disk full');
    },
    filePath: 'unused.md',
    now: () => new Date(2026, 7, 16, 15, 0, 0)
  });

  assert.deepEqual(result, { status: 'error', message: 'disk full' });
});
