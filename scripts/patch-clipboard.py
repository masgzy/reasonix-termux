#!/usr/bin/env python3
"""
Patch atotto/clipboard/clipboard_unix.go 的 init() 函数
绕过 Android seccomp faccessat2 bug

原 init() 调多次 exec.LookPath (xclip/xsel/wlcopy/termux-clipboard-set/...)
每次 LookPath → findExecutable → Eaccess → faccessat2 syscall
Android seccomp 拒绝 faccessat2 → SIGSYS: bad system call

patch 后: 直接设 termux-clipboard-get/set, 不调 LookPath
用户要剪贴板功能可 pkg install termux-api (提供 termux-clipboard-get/set)
"""
import sys
import re

if len(sys.argv) != 2:
    print("Usage: patch-clipboard.py <clipboard_unix.go>", file=sys.stderr)
    sys.exit(1)

path = sys.argv[1]

with open(path, 'r') as f:
    content = f.read()

# 匹配整个 init() 函数 (从 "func init() {" 到匹配的 "}")
# 用正则匹配, init 函数体里没有嵌套 func, 所以第一个 "^}" 就是结束
pattern = r'(func init\(\) \{)([^}]*?)(\})'
match = re.search(pattern, content, re.DOTALL | re.MULTILINE)
if not match:
    print("ERROR: could not find init() function", file=sys.stderr)
    sys.exit(1)

# 新的 init() 函数体: 直接用 termux 命令, 不调 LookPath
new_body = '''
\t// Patched by reasonix-termux workflow
\t// 原实现调 exec.LookPath 触发 faccessat2 syscall, Android seccomp 拒绝 → SIGSYS
\t// 直接设 termux-clipboard-get/set, 用户需 pkg install termux-api
\tpasteCmdArgs = termuxPasteArgs
\tcopyCmdArgs = termuxCopyArgs
'''

# 替换函数体
new_content = content[:match.start(2)] + new_body + content[match.end(2):]

with open(path, 'w') as f:
    f.write(new_content)

print(f"Patched: {path}")
print(f"Removed {len(match.group(2))} bytes of LookPath calls")
