#!/usr/bin/env bash
# Fix semua case sensitivity bug di Lumarge (Linux case-sensitive filesystem)
# Jalankan ini setelah git clone Lumarge

set -e
DIR="${1:-lumarge}"

if [ ! -f "$DIR/cli.lua" ]; then
  echo "Error: $DIR/cli.lua not found"
  exit 1
fi

python3 << PYEOF
import os, shutil, re

base = os.path.abspath("$DIR")

# ── 1. Fix semua require path yang lowercase tapi file/folder camelCase ──────
requires = set()
for root, dirs, files in os.walk(base):
    for f in files:
        if not f.endswith('.lua'): continue
        try:
            content = open(os.path.join(root, f)).read()
            for m in re.findall(r'require\s*\(\s*["\']([^"\']+)["\']\s*\)', content):
                requires.add(m)
        except: pass

fixed = 0
for req in sorted(requires):
    if not req.startswith('source'): continue
    parts = req.split('.')
    fpath = os.path.join(base, *parts) + '.lua'
    dpath = os.path.join(base, *parts, 'init.lua')
    if os.path.exists(fpath) or os.path.exists(dpath): continue

    cur = base
    resolved = []
    ok = True
    for part in parts:
        if not os.path.isdir(cur): ok = False; break
        entries = {e.lower(): e for e in os.listdir(cur)}
        key = part.lower()
        if key in entries:
            resolved.append(entries[key]); cur = os.path.join(cur, entries[key])
        elif key + '.lua' in entries:
            resolved.append(entries[key + '.lua']); cur = os.path.join(cur, entries[key + '.lua']); break
        else: ok = False; break
    if not ok: continue

    src = os.path.join(base, *resolved)
    dst_parts = [p.lower() for p in parts]
    if os.path.isfile(src):
        dst = os.path.join(base, *dst_parts) + '.lua'
        if not os.path.exists(dst):
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(src, dst); fixed += 1
    elif os.path.isdir(src):
        dst = os.path.join(base, *dst_parts)
        if not os.path.exists(dst):
            shutil.copytree(src, dst); fixed += 1

# ── 2. Unparser & compiler: AstKind.Name = PascalCase, files = camelCase ────
for d in ["source/obfuscator/compiler/compilers",
          "source/unparser/unparsers",
          "source/obfuscator/step/steps"]:
    full = os.path.join(base, d)
    if not os.path.isdir(full): continue
    for f in os.listdir(full):
        if not f.endswith('.lua'): continue
        name = f[:-4]
        pascal = name[0].upper() + name[1:]
        src = os.path.join(full, f)
        dst = os.path.join(full, pascal + '.lua')
        if not os.path.exists(dst): shutil.copy2(src, dst); fixed += 1

# ── 3. nameGenerators/mangledShuffled ────────────────────────────────────────
ng = os.path.join(base, "source/obfuscator/namegenerators")
if os.path.isdir(ng):
    for f in os.listdir(ng):
        if not f.endswith('.lua'): continue
        dst = os.path.join(ng, f.lower())
        src = os.path.join(ng, f)
        if not os.path.exists(dst): shutil.copy2(src, dst); fixed += 1

# ── 4. source.enum / source.logger shortcuts ─────────────────────────────────
for pair in [("source/utils/enum.lua","source/enum.lua"),
             ("source/utils/logger.lua","source/logger.lua")]:
    s = os.path.join(base, pair[0])
    d = os.path.join(base, pair[1])
    if os.path.exists(s) and not os.path.exists(d): shutil.copy2(s, d); fixed += 1

# ── 5. source.lumarge.* → map to existing modules ────────────────────────────
lm = os.path.join(base, "source/lumarge")
os.makedirs(lm, exist_ok=True)
for pair in [("source/obfuscator/tokenizer.lua","source/lumarge/tokenizer.lua"),
             ("source/obfuscator/scope.lua","source/lumarge/scope.lua"),
             ("source/obfuscator/ast.lua","source/lumarge/ast.lua"),
             ("source/utils/tools.lua","source/lumarge/utils.lua")]:
    s = os.path.join(base, pair[0])
    d = os.path.join(base, pair[1])
    if os.path.exists(s) and not os.path.exists(d): shutil.copy2(s, d); fixed += 1

print(f"Fixed {fixed} case issues.")
PYEOF

# ── 6. Patch presets: hapus Vmify (compiler-nya incomplete di Lumarge) ────────
python3 << PYEOF2
import re
path = "$DIR/source/init/presets.lua"
content = open(path).read()
# Remove Vmify step
content = re.sub(r'\s*\{ Name = "Vmify" \},?', '', content)
# Fix NumbersToExpressions typo
content = content.replace('"NumbersToExpressions"', '"NumbersToExpression"')
# Add Strong preset if missing
if 'Preset.Strong' not in content or 'Steps' not in content.split('Preset.Strong')[-1][:100]:
    content += '''
PresetRegistry:Register(Enum.Preset.Strong, {
    Steps = {
        { Name = "AntiTamper" },
        { Name = "EncryptStrings" },
        { Name = "ProtectConstants" },
        { Name = "NumbersToExpression" },
        { Name = "ProxifyLocals" },
        { Name = "AddVararg" },
        { Name = "WrapInFunction" },
    },
})
'''
open(path, 'w').write(content)
print("Patched presets.lua (removed Vmify, fixed typos, added Strong preset)")
PYEOF2

echo "✅ Lumarge fix complete"
