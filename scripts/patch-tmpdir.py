#!/usr/bin/env python3
"""
Patch Reasonix 的 main.go, 在 main() 最开头设置 TMPDIR=~/.reasonix/tmp/
解决 Termux/Android 上 /tmp 只读导致 os.MkdirTemp 失败的问题

原因: Go 的 os.TempDir() 默认返回 /tmp, os.MkdirTemp("", ...) 也用 /tmp
      Termux 上 /tmp 不存在或只读 → "mkdir /tmp/...: permission denied"
修复: 在 main() 入口设置 TMPDIR 环境变量, Go runtime 会自动用它
"""
import sys
import re

if len(sys.argv) != 2:
    print("Usage: patch-tmpdir.py <main.go>", file=sys.stderr)
    sys.exit(1)

path = sys.argv[1]

with open(path, 'r') as f:
    content = f.read()

# 在 func main() { 后面注入 TMPDIR 设置代码
# 匹配 "func main() {" 然后在新行插入
patch_code = '''
\t// Patched by reasonix-termux workflow
\t// Termux/Android 上 /tmp 只读, 把临时目录设到 ~/.reasonix/tmp/
\tif tmpdir := os.Getenv("TMPDIR"); tmpdir == "" {
\t\tif home, err := os.UserHomeDir(); err == nil {
\t\t\treasonixTmp := home + "/.reasonix/tmp"
\t\t\t_ = os.MkdirAll(reasonixTmp, 0755)
\t\t\tos.Setenv("TMPDIR", reasonixTmp)
\t\t}
\t}
'''

# 找 func main() {
pattern = r'(func main\(\) \{)'
match = re.search(pattern, content)
if not match:
    print("ERROR: could not find func main() in", path, file=sys.stderr)
    sys.exit(1)

# 在 func main() { 后插入 patch 代码
insert_pos = match.end()
new_content = content[:insert_pos] + patch_code + content[insert_pos:]

with open(path, 'w') as f:
    f.write(new_content)

print(f"Patched: {path}")
print(f"Injected TMPDIR setup at func main() entry")
