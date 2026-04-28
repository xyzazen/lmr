#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Lumarge Web Setup Script
# ─────────────────────────────────────────────────────────────────────────────
set -e
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; RESET='\033[0m'; BOLD='\033[1m'

echo ""
echo -e "${CYAN}${BOLD}🔮  Lumarge Web Setup${RESET}"
echo -e "${CYAN}────────────────────────────────────────${RESET}"

# ── 1. Node.js check ──────────────────────────────────────────────────────────
echo -e "\n${BOLD}[1/4] Checking Node.js...${RESET}"
if ! command -v node &>/dev/null; then
  echo -e "${RED}✗ Node.js not found. Please install Node.js >= 18${RESET}"
  exit 1
fi
NODE_VER=$(node -v)
echo -e "${GREEN}✓ Node.js ${NODE_VER}${RESET}"

# ── 2. Lua check ──────────────────────────────────────────────────────────────
echo -e "\n${BOLD}[2/4] Checking Lua...${RESET}"
LUA_CMD=""
for cmd in lua5.4 lua54 lua5.3 lua53 lua; do
  if command -v $cmd &>/dev/null; then
    LUA_CMD=$cmd
    break
  fi
done

if [ -z "$LUA_CMD" ]; then
  echo -e "${YELLOW}⚠ Lua not found. Installing...${RESET}"
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -q && sudo apt-get install -y -q lua5.4
    LUA_CMD="lua5.4"
  elif command -v brew &>/dev/null; then
    brew install lua
    LUA_CMD="lua"
  elif command -v pkg &>/dev/null; then
    pkg install lua54
    LUA_CMD="lua5.4"
  else
    echo -e "${RED}✗ Cannot auto-install Lua. Please install Lua 5.4 manually.${RESET}"
    echo "   Ubuntu/Debian: sudo apt install lua5.4"
    echo "   macOS:         brew install lua"
    echo "   Termux:        pkg install lua54"
    exit 1
  fi
fi
LUA_VER=$($LUA_CMD -v 2>&1 | head -1)
echo -e "${GREEN}✓ ${LUA_VER} (${LUA_CMD})${RESET}"

# ── 3. Clone Lumarge ──────────────────────────────────────────────────────────
echo -e "\n${BOLD}[3/4] Setting up Lumarge CLI...${RESET}"
if [ -f "lumarge/cli.lua" ]; then
  echo -e "${GREEN}✓ Lumarge already present${RESET}"
elif [ -f "cli.lua" ]; then
  echo -e "${GREEN}✓ cli.lua found at root${RESET}"
else
  if command -v git &>/dev/null; then
    echo "  Cloning tlredz/Lumarge..."
    git clone --depth=1 https://github.com/tlredz/Lumarge lumarge
    echo -e "${GREEN}✓ Lumarge cloned to ./lumarge/${RESET}"
  else
    echo -e "${RED}✗ git not found. Please install git and re-run.${RESET}"
    exit 1
  fi
fi

# ── 4. npm install ────────────────────────────────────────────────────────────
echo -e "\n${BOLD}[4/4] Installing Node.js dependencies...${RESET}"
npm install --silent
echo -e "${GREEN}✓ Dependencies installed${RESET}"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}────────────────────────────────────────${RESET}"
echo -e "${GREEN}${BOLD}✅  Setup complete!${RESET}"
echo ""
echo -e "  Start server : ${BOLD}npm start${RESET}"
echo -e "  Dev mode     : ${BOLD}npm run dev${RESET}"
echo -e "  Open browser : ${BOLD}http://localhost:3000${RESET}"
echo ""
