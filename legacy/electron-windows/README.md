# Legacy Electron Windows Client

This directory preserves the original Windows/Electron capture client as migration reference material.

It is no longer a production entry point. Active macOS and Windows development happens in the shared Flutter project at [`../../app`](../../app).

The legacy client is retained for its compact floating-widget interaction and its user-visible `Universal Capture` Vault organization. Its Node storage implementation and Electron runtime must not be used for new product work.

For historical verification only:

```powershell
npm install
npm test
npm start
```

The supported cross-platform commands are documented in the repository root README.
