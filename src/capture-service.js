async function captureCurrentClipboard({ readText, append, filePath, now }) {
  try {
    return await append({
      text: readText(),
      capturedAt: now(),
      filePath
    });
  } catch (error) {
    return {
      status: 'error',
      message: error instanceof Error ? error.message : String(error)
    };
  }
}

module.exports = { captureCurrentClipboard };
