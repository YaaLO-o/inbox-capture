const fs = require('node:fs/promises');
const path = require('node:path');

const VAULT_NOT_FOUND_MESSAGE = '未找到 Obsidian 仓库';

function twoDigits(value) {
  return String(value).padStart(2, '0');
}

function formatDate(date) {
  return `${date.getFullYear()}-${twoDigits(date.getMonth() + 1)}-${twoDigits(date.getDate())}`;
}

async function readVaultConfig(configPath) {
  try {
    return JSON.parse(await fs.readFile(configPath, 'utf8'));
  } catch {
    throw new Error(VAULT_NOT_FOUND_MESSAGE);
  }
}

async function existingVaults(vaults) {
  const candidates = Object.values(vaults || {}).filter(
    (vault) => vault && typeof vault.path === 'string'
  );
  const available = [];

  for (const vault of candidates) {
    try {
      const stats = await fs.stat(vault.path);
      if (stats.isDirectory()) available.push(vault);
    } catch {
      // Obsidian may retain entries for folders that have been moved or removed.
    }
  }

  return available;
}

async function resolveObsidianCapturePath({ configPath, capturedAt = new Date() }) {
  const config = await readVaultConfig(configPath);
  const vaults = await existingVaults(config.vaults);
  const selected = vaults.find((vault) => vault.open === true) || vaults[0];

  if (!selected) {
    throw new Error(VAULT_NOT_FOUND_MESSAGE);
  }

  return path.join(selected.path, 'Universal Capture', `${formatDate(capturedAt)}.md`);
}

module.exports = { resolveObsidianCapturePath };
