const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');

const { resolveObsidianCapturePath } = require('../src/obsidian-vault');

async function makeTemporaryRoot(t) {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'universal-capture-obsidian-'));
  t.after(() => fs.rm(root, { recursive: true, force: true }));
  return root;
}

test('优先选择当前打开且真实存在的 Obsidian 仓库', async (t) => {
  const root = await makeTemporaryRoot(t);
  const closedVault = path.join(root, 'closed-vault');
  const openVault = path.join(root, 'open-vault');
  const configPath = path.join(root, 'obsidian.json');
  await fs.mkdir(closedVault);
  await fs.mkdir(openVault);
  await fs.writeFile(configPath, JSON.stringify({
    vaults: {
      closed: { path: closedVault },
      open: { path: openVault, open: true }
    }
  }), 'utf8');

  const result = await resolveObsidianCapturePath({
    configPath,
    capturedAt: new Date(2026, 7, 16, 23, 59, 59)
  });

  assert.equal(result, path.join(openVault, 'Universal Capture', '2026-08-16.md'));
});

test('同一天复用同一个文件且不同日期生成不同文件', async (t) => {
  const root = await makeTemporaryRoot(t);
  const vault = path.join(root, 'vault');
  const configPath = path.join(root, 'obsidian.json');
  await fs.mkdir(vault);
  await fs.writeFile(configPath, JSON.stringify({
    vaults: {
      current: { path: vault, open: true }
    }
  }), 'utf8');

  const dayOneMorning = await resolveObsidianCapturePath({
    configPath,
    capturedAt: new Date(2026, 7, 16, 8, 0, 0)
  });
  const dayOneNight = await resolveObsidianCapturePath({
    configPath,
    capturedAt: new Date(2026, 7, 16, 23, 59, 59)
  });
  const dayTwo = await resolveObsidianCapturePath({
    configPath,
    capturedAt: new Date(2026, 7, 17, 0, 0, 1)
  });

  assert.equal(dayOneMorning, path.join(vault, 'Universal Capture', '2026-08-16.md'));
  assert.equal(dayOneNight, dayOneMorning);
  assert.equal(dayTwo, path.join(vault, 'Universal Capture', '2026-08-17.md'));
});

test('Obsidian 配置不存在时返回明确错误', async (t) => {
  const root = await makeTemporaryRoot(t);

  await assert.rejects(
    resolveObsidianCapturePath({ configPath: path.join(root, 'missing.json') }),
    /未找到 Obsidian 仓库/
  );
});

test('Obsidian 配置格式无效时返回明确错误', async (t) => {
  const root = await makeTemporaryRoot(t);
  const configPath = path.join(root, 'obsidian.json');
  await fs.writeFile(configPath, '{not json', 'utf8');

  await assert.rejects(
    resolveObsidianCapturePath({ configPath }),
    /未找到 Obsidian 仓库/
  );
});

test('配置中的仓库均不存在时返回明确错误', async (t) => {
  const root = await makeTemporaryRoot(t);
  const configPath = path.join(root, 'obsidian.json');
  await fs.writeFile(configPath, JSON.stringify({
    vaults: {
      missing: { path: path.join(root, 'missing-vault'), open: true }
    }
  }), 'utf8');

  await assert.rejects(
    resolveObsidianCapturePath({ configPath }),
    /未找到 Obsidian 仓库/
  );
});
