const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');

const { appendCapture } = require('../src/capture-store');

async function makeTemporaryCapture(t) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'universal-capture-'));
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  return path.join(root, 'nested', 'captures.md');
}

test('目标目录不存在时创建目录并追加中文多行记录', async (t) => {
  const filePath = await makeTemporaryCapture(t);

  const result = await appendCapture({
    text: '第一行\n第二行中文',
    capturedAt: new Date(2026, 7, 16, 14, 30, 5),
    filePath
  });

  assert.deepEqual(result, { status: 'saved', filePath });
  assert.equal(
    await fs.readFile(filePath, 'utf8'),
    '## 2026-08-16 14:30:05\n\n第一行\n第二行中文\n\n---\n\n'
  );
});

test('空白内容不创建采集文件', async (t) => {
  const filePath = await makeTemporaryCapture(t);

  const result = await appendCapture({
    text: ' \n\t ',
    capturedAt: new Date(2026, 7, 16, 14, 30, 5),
    filePath
  });

  assert.deepEqual(result, { status: 'empty' });
  await assert.rejects(fs.access(filePath), { code: 'ENOENT' });
});

test('第二条记录追加在第一条之后且不覆盖原内容', async (t) => {
  const filePath = await makeTemporaryCapture(t);

  await appendCapture({
    text: '第一条',
    capturedAt: new Date(2026, 7, 16, 9, 0, 0),
    filePath
  });
  await appendCapture({
    text: '第二条',
    capturedAt: new Date(2026, 7, 16, 9, 1, 0),
    filePath
  });

  assert.equal(
    await fs.readFile(filePath, 'utf8'),
    '## 2026-08-16 09:00:00\n\n第一条\n\n---\n\n## 2026-08-16 09:01:00\n\n第二条\n\n---\n\n'
  );
});
