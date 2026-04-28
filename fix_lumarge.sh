#!/usr/bin/env bash
set -e
DIR="${1:-lumarge}"
[ -f "$DIR/cli.lua" ] || { echo "Error: $DIR/cli.lua not found"; exit 1; }

python3 << PYEOF
import os, shutil, re

base = os.path.abspath("$DIR")

# ── 1. Fix semua require path lowercase vs camelCase folder ──────────────────
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
    if os.path.exists(os.path.join(base,*parts)+'.lua') or os.path.exists(os.path.join(base,*parts,'init.lua')): continue
    cur = base; resolved = []; ok = True
    for part in parts:
        if not os.path.isdir(cur): ok=False; break
        entries = {e.lower():e for e in os.listdir(cur)}
        k = part.lower()
        if k in entries: resolved.append(entries[k]); cur=os.path.join(cur,entries[k])
        elif k+'.lua' in entries: resolved.append(entries[k+'.lua']); cur=os.path.join(cur,entries[k+'.lua']); break
        else: ok=False; break
    if not ok: continue
    src = os.path.join(base,*resolved)
    dst_parts = [p.lower() for p in parts]
    if os.path.isfile(src):
        dst = os.path.join(base,*dst_parts)+'.lua'
        if not os.path.exists(dst): os.makedirs(os.path.dirname(dst),exist_ok=True); shutil.copy2(src,dst); fixed+=1
    elif os.path.isdir(src):
        dst = os.path.join(base,*dst_parts)
        if not os.path.exists(dst): shutil.copytree(src,dst); fixed+=1

# ── 2. PascalCase copies untuk dynamic require (compiler, unparser, steps) ───
for d in ["source/obfuscator/compiler/compilers","source/unparser/unparsers","source/obfuscator/step/steps"]:
    full = os.path.join(base,d)
    if not os.path.isdir(full): continue
    for f in os.listdir(full):
        if not f.endswith('.lua'): continue
        name=f[:-4]; pascal=name[0].upper()+name[1:]
        src=os.path.join(full,f); dst=os.path.join(full,pascal+'.lua')
        if not os.path.exists(dst): shutil.copy2(src,dst); fixed+=1

# ── 3. namegenerators lowercase copies ───────────────────────────────────────
ng = os.path.join(base,"source/obfuscator/namegenerators")
if os.path.isdir(ng):
    for f in os.listdir(ng):
        if not f.endswith('.lua'): continue
        dst=os.path.join(ng,f.lower()); src=os.path.join(ng,f)
        if not os.path.exists(dst): shutil.copy2(src,dst); fixed+=1

# ── 4. source.enum / source.logger shortcuts ─────────────────────────────────
for s,d in [("source/utils/enum.lua","source/enum.lua"),("source/utils/logger.lua","source/logger.lua")]:
    s2=os.path.join(base,s); d2=os.path.join(base,d)
    if os.path.exists(s2) and not os.path.exists(d2): shutil.copy2(s2,d2); fixed+=1

# ── 5. source.lumarge.* → map ke existing modules ────────────────────────────
lm=os.path.join(base,"source/lumarge"); os.makedirs(lm,exist_ok=True)
for s,d in [("source/obfuscator/tokenizer.lua","source/lumarge/tokenizer.lua"),
            ("source/obfuscator/scope.lua","source/lumarge/scope.lua"),
            ("source/obfuscator/ast.lua","source/lumarge/ast.lua"),
            ("source/utils/tools.lua","source/lumarge/utils.lua")]:
    s2=os.path.join(base,s); d2=os.path.join(base,d)
    if os.path.exists(s2) and not os.path.exists(d2): shutil.copy2(s2,d2); fixed+=1

print(f"Fixed {fixed} case/path issues.")
PYEOF

# ── 6. Fix unparser: newline(false) → newline(true) biar tidak "dolocal" ─────
find "$DIR/source/unparser/unparsers" -name "*.lua" | xargs sed -i 's/self:newline(false)/self:newline(true)/g'

# ── 7. Patch presets: hapus Vmify (incomplete), fix typo, tambah Strong ──────
python3 << PYEOF2
import re
path = "$DIR/source/init/presets.lua"
content = open(path).read()
content = re.sub(r'\s*\{ Name = "Vmify" \},?', '', content)
content = content.replace('"NumbersToExpressions"', '"NumbersToExpression"')
if 'Steps' not in content.split('Preset.Strong')[-1][:200] if 'Preset.Strong' in content else True:
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
open(path,'w').write(content)
print("Patched presets.lua")
PYEOF2

echo "✅ Lumarge fix complete"
