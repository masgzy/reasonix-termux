#!/usr/bin/env python3
"""
Patch Reasonix 源码, 解决 Termux/Android 上 /tmp 只读的问题

1. CLI 入口 main(): 在 main() 入口设 TMPDIR=~/.reasonix/tmp/
2. config mutate 锁文件代码: 把硬编码的 /tmp/reasonix-config-locks-* 改成 os.TempDir()

鲁棒性说明 (v2 教训):
  上游 v2.34.0 重构后 internal/config/mutate.go 移到了 internal/contract/config/mutate.go,
  硬编码路径的 patch 直接失效。所以本版本不再假设具体路径:
  - main.go: 优先 cmd/reasonix/main.go, 找不到则递归搜索唯一的 main 包入口
  - 锁文件代码: 递归搜索所有 .go 文件中包含硬编码 pattern 的位置
  - 文件存在但 pattern 匹配失败 → 报错终止 (说明上游改了写法, 需要人工确认)
  - 文件/pattern 不存在 (可能上游已修复) → warning 跳过, 不阻断构建
"""
import sys
import re
import os
import glob

# 硬编码的锁文件路径 pattern (与上游源码逐字匹配)
LOCK_PATTERN = 'filepath.Join(string(filepath.Separator), "tmp", fmt.Sprintf("reasonix-config-locks-%x", digest[:8])), nil'
LOCK_REPLACEMENT = 'filepath.Join(os.TempDir(), fmt.Sprintf("reasonix-config-locks-%x", digest[:8])), nil // Patched by reasonix-termux'


def find_main_go(root):
    """定位 CLI 入口 main.go: 优先 cmd/reasonix/main.go, 兜底递归搜索"""
    preferred = os.path.join(root, 'cmd/reasonix/main.go')
    if os.path.isfile(preferred):
        return preferred
    # 兜底: 递归搜索 cmd/ 下所有 main.go, 取路径最短的那个 (最可能是主 CLI)
    candidates = sorted(
        glob.glob(os.path.join(root, 'cmd/**/main.go'), recursive=True),
        key=len,
    )
    return candidates[0] if candidates else None


def patch_main_go(path):
    """在 main() 入口注入 TMPDIR 设置"""
    with open(path, 'r') as f:
        content = f.read()

    if 'reasonixTmp := home + "/.reasonix/tmp"' in content:
        print(f"  skip {path} (already patched)")
        return True

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


def find_lock_files(root):
    """递归搜索包含硬编码 /tmp 锁文件 pattern 的 .go 文件 (不再假设目录结构)"""
    hits = []
    for dirpath, dirnames, filenames in os.walk(root):
        # 跳过无关目录
        dirnames[:] = [d for d in dirnames if d not in ('.git', 'node_modules', 'testdata')]
        for fn in filenames:
            if not fn.endswith('.go'):
                continue
            path = os.path.join(dirpath, fn)
            try:
                with open(path, 'r') as f:
                    if LOCK_PATTERN in f.read():
                        hits.append(path)
            except OSError:
                continue
    return hits


def patch_lock_file(path):
    """把硬编码的 /tmp/reasonix-config-locks-* 改成 os.TempDir()"""
    with open(path, 'r') as f:
        content = f.read()

    if 'os.TempDir(), fmt.Sprintf("reasonix-config-locks' in content:
        print(f"  skip {path} (already patched)")
        return True

    new_content = content.replace(LOCK_PATTERN, LOCK_REPLACEMENT, 1)
    # 确保 os 包已导入
    if '"os"' not in new_content:
        new_content = new_content.replace('import (', 'import (\n\t"os"', 1)
    with open(path, 'w') as f:
        f.write(new_content)
    print(f"  patched {path} (/tmp → os.TempDir())")
    return True


def main():
    if len(sys.argv) != 2:
        print("Usage: patch-tmpdir.py <upstream-root-dir>", file=sys.stderr)
        sys.exit(1)

    root = sys.argv[1]
    print(f"Patching Reasonix source at: {root}")

    ok = True

    # 1. main.go 入口 TMPDIR patch (关键: 找不到入口必须失败)
    main_go = find_main_go(root)
    if main_go:
        print(f"[1/2] main entry: {os.path.relpath(main_go, root)}")
        ok &= patch_main_go(main_go)
    else:
        print("  ERROR: 未找到任何 CLI 入口 main.go (cmd/**/main.go)", file=sys.stderr)
        ok = False

    # 2. 锁文件 /tmp 硬编码 patch (鲁棒: 递归搜索; 搜索不到则视为上游已修复)
    lock_files = find_lock_files(root)
    if lock_files:
        print(f"[2/2] lock file pattern found in {len(lock_files)} file(s)")
        for lf in lock_files:
            ok &= patch_lock_file(lf)
    else:
        print("  warning: 未找到 /tmp 锁文件硬编码 pattern (可能上游已改用 os.TempDir()), 跳过")

    if ok:
        print("✓ All patches applied")
    else:
        print("✗ Some patches failed", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
