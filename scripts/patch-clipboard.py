#!/usr/bin/env python3
"""
Patch atotto/clipboard/clipboard_unix.go 的 init() 函数
绕过 Android seccomp faccessat2 bug + 省启动时间

原 init() 调多次 exec.LookPath (xclip/xsel/wlcopy/termux-clipboard-set/...)
每次 LookPath → findExecutable → fstatat/faccessat 系列 syscall
Android seccomp 拒绝 faccessat2 → SIGSYS: bad system call
(GOOS=android 时不发 faccessat2 不会 SIGSYS, 但 fallback 仍走多次 fstatat)

patch 后: 直接固定 termux-clipboard-get/set, 不调 LookPath
用户要剪贴板功能可 pkg install termux-api (提供 termux-clipboard-get/set)

鲁棒性说明:
  - 用括号计数定位 init() 边界, 正确处理嵌套大括号
    (旧版正则 [^}]*? 会在第一个内层 } 处截断, patch 出括号不匹配的编译错误)
  - patch 后自动清理因此不再使用的 import ("os"), 避免 "imported and not used" 编译错误
  - 幂等: 已 patch 的文件直接跳过
"""
import sys
import re
import os
import stat

PATCH_MARKER = '// Patched by reasonix-termux'

NEW_INIT_BODY = '''
\t// Patched by reasonix-termux workflow
\t// 原实现调多次 exec.LookPath, 浪费启动时间且可能触发被 Android seccomp
\t// 拦截的 syscall; 直接固定 termux-clipboard-get/set (需 pkg install termux-api)
\tpasteCmdArgs = termuxPasteArgs
\tcopyCmdArgs = termuxCopyArgs
'''


def replace_init_body(content, new_body):
    """括号计数定位 init() 函数体并替换 (正确处理嵌套大括号)"""
    m = re.search(r'^func init\(\) \{', content, re.MULTILINE)
    if not m:
        return None
    open_idx = m.end() - 1  # '{' 的位置
    depth = 0
    for i in range(open_idx, len(content)):
        if content[i] == '{':
            depth += 1
        elif content[i] == '}':
            depth -= 1
            if depth == 0:
                # content[i] 是 init 的收尾 '}', 保留它
                return content[:open_idx + 1] + new_body + content[i:]
    return None


def remove_unused_import(content, pkg):
    """从 import 块中移除指定包 (仅当补丁后不再被使用)"""
    # 判断除 import 外是否仍使用该包: 粗略统计 `pkg.` 引用次数
    body_refs = len(re.findall(r'\b' + re.escape(pkg) + r'\.', content))
    if body_refs > 0:
        return content
    new_content, n = re.subn(
        r'^\t"' + re.escape(pkg) + r'"$\n', '', content, flags=re.MULTILINE)
    if n:
        print(f"  removed now-unused import: \"{pkg}\"")
    return new_content


def write_file(path, content):
    """写入文件; GOMODCACHE 中的文件是只读的 (go 保证模块缓存不可变),
    需先加写权限, 写完恢复 0444 以维持缓存语义"""
    try:
        with open(path, 'w') as f:
            f.write(content)
    except PermissionError:
        os.chmod(path, stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IROTH)
        with open(path, 'w') as f:
            f.write(content)
        os.chmod(path, stat.S_IRUSR | stat.S_IRGRP | stat.S_IROTH)  # 恢复只读


def main():
    if len(sys.argv) != 2:
        print("Usage: patch-clipboard.py <clipboard_unix.go>", file=sys.stderr)
        sys.exit(1)

    path = sys.argv[1]

    with open(path, 'r') as f:
        content = f.read()

    if PATCH_MARKER in content:
        print(f"  skip {path} (already patched)")
        return

    # 必要的符号必须存在 (v0.1.4 已确认, 其他版本若变动则明确报错不盲改)
    for sym in ('termuxPasteArgs', 'termuxCopyArgs', 'pasteCmdArgs', 'copyCmdArgs'):
        if sym not in content:
            print(f"ERROR: 符号 {sym} 不存在于 {path}, 上游依赖可能已升级, 需人工确认",
                  file=sys.stderr)
            sys.exit(1)

    new_content = replace_init_body(content, NEW_INIT_BODY)
    if new_content is None:
        print("ERROR: could not find init() function", file=sys.stderr)
        sys.exit(1)

    # init() 不再调 os.Getenv → "os" import 变为未使用, 必须移除否则编译失败
    new_content = remove_unused_import(new_content, 'os')

    write_file(path, new_content)

    print(f"Patched: {path}")
    print(f"Removed {len(content) - len(new_content)} bytes of LookPath calls")


if __name__ == '__main__':
    main()
