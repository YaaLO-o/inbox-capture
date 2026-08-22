const fs = require('node:fs/promises');
const path = require('node:path');

function twoDigits(value) {
  return String(value).padStart(2, '0');
}

function formatTimestamp(date) {
  return [
    `${date.getFullYear()}-${twoDigits(date.getMonth() + 1)}-${twoDigits(date.getDate())}`,
    `${twoDigits(date.getHours())}:${twoDigits(date.getMinutes())}:${twoDigits(date.getSeconds())}`
  ].join(' ');
}

async function appendCapture({ text, capturedAt, filePath }) {
  if (typeof text !== 'string' || text.trim().length === 0) {
    return { status: 'empty' };
  }

  await fs.mkdir(path.dirname(filePath), { recursive: true });
  const entry = `## ${formatTimestamp(capturedAt)}\n\n${text}\n\n---\n\n`;
  await fs.appendFile(filePath, entry, 'utf8');

  return { status: 'saved', filePath };
}

module.exports = { appendCapture, formatTimestamp };
