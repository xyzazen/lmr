# 🔮 Lumarge Web

Web interface untuk **Lumarge** — Lua/Luau Obfuscator berbasis [Prometheus](https://github.com/prometheus-lua/Prometheus).

## ✨ Fitur

- **Target Version** — Lua 5.1, Lua 5.4, Luau
- **Preset** — Minify / Weak / Medium / Strong
- **Rename Variables** — Number, Mangled, Mangled Shuffled, dll
- **Random Seed** — Control hasil randomization
- **Pretty Print** — Output yang readable
- **Lua Bundle** — Multi-file → single script
- Upload file `.lua` / `.luau`
- Copy & Download output
- Stats: ukuran, rasio, waktu obfuscasi
- Line numbers, Tab support
- Rate limiting (30 req/mnt)

## 🚀 Quick Start

### Opsi A — Setup otomatis (recommended)
```bash
git clone https://github.com/YOUR_USERNAME/lumarge-web
cd lumarge-web
bash setup.sh
npm start
```
Script `setup.sh` akan otomatis:
- Cek Node.js & Lua
- Install Lua jika belum ada (apt / brew / pkg)
- Clone Lumarge CLI
- Install npm dependencies

### Opsi B — Manual
```bash
# Install Lua 5.4
# Ubuntu/Debian:
sudo apt install lua5.4

# macOS:
brew install lua

# Termux:
pkg install lua54

# Clone project ini
git clone https://github.com/YOUR_USERNAME/lumarge-web
cd lumarge-web

# Clone Lumarge ke subfolder
git clone https://github.com/tlredz/Lumarge lumarge

# Install dependencies
npm install

# Jalankan server
npm start
```

Buka browser di `http://localhost:3000`

## 📁 Struktur Project

```
lumarge-web/
├── server.js          # Express backend
├── package.json
├── setup.sh           # Auto-setup script
├── public/
│   └── index.html     # Web UI
├── lumarge/           # Lumarge CLI (auto-cloned)
│   ├── cli.lua
│   ├── configs.json
│   └── source/
└── temp/              # Temp files (auto-created)
```

## ⚙️ Environment Variables

| Variable | Default | Keterangan |
|----------|---------|------------|
| `PORT`   | `3000`  | Port server |

## 🐳 Codespaces / Dev Container

Di GitHub Codespaces, jalankan:
```bash
bash setup.sh
npm start
```
Port 3000 akan otomatis forwarded.

## API

### `POST /api/obfuscate`
```json
{
  "code": "-- lua code here",
  "version": "lua51 | lua54 | luau",
  "preset": "minify | weak | medium | strong",
  "seed": 12345,
  "pretty": false,
  "renVariables": "mangled | mangledShuffled | number | enable | disable",
  "bundle": false
}
```

Response:
```json
{
  "success": true,
  "code": "-- obfuscated output",
  "stats": {
    "originalSize": 256,
    "obfuscatedSize": 1024,
    "ratio": "400.0",
    "elapsed": 312
  }
}
```

### `GET /api/health`
```json
{
  "status": "ok",
  "lua": "lua5.4",
  "lumarge": "found",
  "lumargeReady": true
}
```

## Credits

- **Lumarge** oleh [tlredz](https://github.com/tlredz/Lumarge)
- Berbasis **Prometheus Obfuscator**
