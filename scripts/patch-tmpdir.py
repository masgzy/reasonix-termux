#!/usr/bin/env python3
"""
Patch Reasonix 源码, 解决 Termux/Android 上 /tmp 只读的问题

1. cmd/reasonix/main.go: 在 main() 入口设 TMPDIR=~/.reasonix/tmp/
2. internal/config/mutate.go: 把硬编码的 /tmp/reasonix-config-locks-* 改成 os.TempDir()
"""
import sys
import re
import os

def patch_main_go(path):
    """在 main() 入口注入 TMPDIR 设置"""
    with open(path, 'r') as f:
        content = f.read()

    if 'reasonixTmp := home + "/.reasonix/tmp"' in content:
        print(f"  skip {path} (already patched)")
        return

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
    match = re.search(r'(func main\(\) \{)', content)
    if not match:
        print(f"  ERROR: could not find func main() in {path}", file=sys.stderr)
        return False

    new_content = content[:match.end()] + patch_code + content[match.end():]
    with open(path, 'w') as f:
        f.write(new_content)
    print(f"  patched {path} (TMPDIR setup in main)")
    return True

def patch_mutate_go(path):
    """把硬编码的 /tmp/reasonix-config-locks-* 改成 os.TempDir()"""
    if not os.path.exists(path):
        print(f"  skip {path} (not found)")
        return True

    with open(path, 'r') as f:
        content = f.read()

    if 'os.TempDir()' in content and 'reasonix-config-locks' in content:
        # 检查是否已经 patch 过
        if 'Patched by reasonix-termux' in content:
            print(f"  skip {path} (already patched)")
            return True

    # 匹配: filepath.Join(string(filepath.Separator), "tmp", fmt.Sprintf(...))
    # 替换成: filepath.Join(os.TempDir(), fmt.Sprintf(...))
    old = 'filepath.Join(string(filepath.Separator), "tmp", fmt.Sprintf("reasonix-config-locks-%x", digest[:8]))'
    new = 'filepath.Join(os.TempDir(), fmt.Sprintf("reasonix-config-locks-%x", digest[:8])) // Patched by reasonix-termux'

    if old in content:
        content = content.replace(old, new, 1)
        # 确保 os 包已导入
        if '"os"' not in content:
            content = content.replace('import (', 'import (\n\t"os"', 1)
        with open(path, 'w') as f:
            f.write(content)
        print(f"  patched {path} (/tmp → os.TempDir())")
        return True
    else:
        print(f"  warning: pattern not found in {path}", file=sys.stderr)
        return True

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: patch-tmpdir.py <upstream-root-dir>", file=sys.stderr)
        sys.exit(1)

    root = sys.argv[1]
    print(f"Patching Reasonix source at: {root}")

    ok = True
    # 1. main.go
    ok &= patch_main_go(os.path.join(root, 'cmd/reasonix/main.go'))
    # 2. mutate.go
    ok &= patch_mutate_go(os.path.join(root, 'internal/config/mutate.go'))

    if ok:
        print("✓ All patches applied")
    else:
        print("✗ Some patches failed", file=sys.stderr)
        sys.exit(1)
