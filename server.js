const express = require("express");
const cors = require("cors");
const { execFile } = require("child_process");
const fs = require("fs");
const path = require("path");
const { v4: uuidv4 } = require("uuid");
const rateLimit = require("express-rate-limit");

const app = express();
const PORT = process.env.PORT || 3000;
const TEMP_DIR = path.join(__dirname, "temp");
const LUMARGE_CLI = path.join(__dirname, "lumarge", "cli.lua");

// ── Middleware ────────────────────────────────────────────────────────────────
app.use(cors());
app.use(express.json({ limit: "2mb" }));
app.use(express.static(path.join(__dirname, "public")));

const limiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: "Too many requests. Please wait a moment." },
});
app.use("/api/", limiter);

// ── Ensure temp dir exists ────────────────────────────────────────────────────
if (!fs.existsSync(TEMP_DIR)) fs.mkdirSync(TEMP_DIR, { recursive: true });

// ── Helpers ───────────────────────────────────────────────────────────────────
function cleanupFiles(...files) {
  for (const f of files) {
    try {
      if (fs.existsSync(f)) fs.unlinkSync(f);
    } catch (_) {}
  }
}

function luaAvailable() {
  const { execSync } = require("child_process");
  const candidates = [
    "lua5.4", "lua54", "lua5.3", "lua53", "lua",
    "/usr/bin/lua5.4", "/usr/bin/lua",
    "/usr/local/bin/lua5.4", "/usr/local/bin/lua",
  ];
  for (const cmd of candidates) {
    try {
      execSync(`"${cmd}" -v`, { stdio: "ignore" });
      return cmd;
    } catch (_) {}
  }
  try {
    const found = execSync("which lua5.4 || which lua", { encoding: "utf8" }).trim().split("\n")[0];
    if (found) return found;
  } catch (_) {}
  return null;
}

function lumargePath() {
  // Support both "lumarge/cli.lua" and "cli.lua" at root
  const candidates = [
    path.join(__dirname, "lumarge", "cli.lua"),
    path.join(__dirname, "cli.lua"),
  ];
  for (const p of candidates) {
    if (fs.existsSync(p)) return p;
  }
  return null;
}

// ── API: Health check ─────────────────────────────────────────────────────────
app.get("/api/health", (req, res) => {
  const luaCmd = luaAvailable();
  const cli = lumargePath();
  res.json({
    status: "ok",
    lua: luaCmd || "not found",
    lumarge: cli ? "found" : "not found",
    lumargeReady: !!(luaCmd && cli),
  });
});

// ── API: Obfuscate ────────────────────────────────────────────────────────────
app.post("/api/obfuscate", async (req, res) => {
  const {
    code,
    version,   // lua51 | lua54 | luau
    preset,    // minify | weak | medium | strong
    seed,
    pretty,
    renVariables,
    bundle,
    watermark,
  } = req.body;

  // Validation
  if (!code || typeof code !== "string") {
    return res.status(400).json({ error: "No code provided." });
  }
  if (code.length > 500_000) {
    return res.status(400).json({ error: "Code too large (max 500KB)." });
  }

  const luaCmd = luaAvailable();
  if (!luaCmd) {
    return res.status(500).json({
      error: "Lua interpreter not found. Please install Lua 5.4 on the server.",
    });
  }

  const cliPath = lumargePath();
  if (!cliPath) {
    return res.status(500).json({
      error:
        "Lumarge CLI not found. Run `bash setup.sh` or place cli.lua at the project root.",
    });
  }

  // Write input to temp file
  const id = uuidv4();
  const inputFile = path.join(TEMP_DIR, `${id}_input.lua`);
  const outputFile = path.join(TEMP_DIR, `${id}_output.lua`);

  fs.writeFileSync(inputFile, code, "utf8");

  // Working dir must be the lumarge folder so Lua can resolve its own modules
  const lumargeDir = path.dirname(cliPath);

  // Build args — use just the cli filename (relative), input/output as absolute
  const args = [path.basename(cliPath), inputFile, outputFile];

  if (version && ["lua51", "lua54", "luau"].includes(version)) {
    args.push("--version", version);
  }
  if (preset && ["minify", "weak", "medium", "strong"].includes(preset)) {
    args.push("--preset", preset);
  }
  if (seed && /^\d+$/.test(String(seed))) {
    args.push("--seed", String(seed));
  }
  if (pretty === true || pretty === "true") {
    args.push("--pretty");
  }
  if (
    renVariables &&
    ["enable", "disable", "true", "false", "number", "mangled", "mangledShuffled"].includes(
      renVariables
    )
  ) {
    args.push("--renvadiables", renVariables);
  }
  if (bundle === true || bundle === "true") {
    args.push("--bundle");
  }

  // Execute
  const startTime = Date.now();
  execFile(luaCmd, args, { timeout: 30_000, maxBuffer: 10 * 1024 * 1024, cwd: lumargeDir }, (err, stdout, stderr) => {
    const elapsed = Date.now() - startTime;

    if (err) {
      cleanupFiles(inputFile, outputFile);
      const errMsg = stderr || stdout || err.message || "Unknown error";
      return res.status(500).json({
        error: `Obfuscation failed:\n${errMsg.slice(0, 2000)}`,
      });
    }

    // Read output
    let obfuscated = "";
    try {
      obfuscated = fs.readFileSync(outputFile, "utf8");
    } catch (_) {
      cleanupFiles(inputFile, outputFile);
      return res.status(500).json({
        error: "Obfuscator ran but produced no output file.",
      });
    }

    cleanupFiles(inputFile, outputFile);

    // Stats
    const originalSize = Buffer.byteLength(code, "utf8");
    const obfuscatedSize = Buffer.byteLength(obfuscated, "utf8");

    return res.json({
      success: true,
      code: obfuscated,
      stats: {
        originalSize,
        obfuscatedSize,
        ratio: ((obfuscatedSize / originalSize) * 100).toFixed(1),
        elapsed,
      },
      stdout: stdout || undefined,
    });
  });
});

// ── Start ─────────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  console.log(`\n🔮 Lumarge Web running at http://localhost:${PORT}`);
  const lua = luaAvailable();
  const cli = lumargePath();
  console.log(`   Lua  : ${lua || "❌ NOT FOUND – install Lua 5.4"}`);
  console.log(`   CLI  : ${cli || "❌ NOT FOUND – run bash setup.sh"}`);
  console.log("");
});
