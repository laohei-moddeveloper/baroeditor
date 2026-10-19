#!/usr/bin/env python3
"""Package existing releases with bilingual Workshop metadata; no builds/tests."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import stat
import urllib.request
import zipfile
import io

ROOT = Path(__file__).resolve().parents[1]
BASES = {
    'InGame': {
        'version': '0.1.1', 'item': '3819517380', 'metadata': 'publishing',
        'url': 'https://github.com/laohei-moddeveloper/baroeditor/releases/download/v0.1.1/BaroEditor-0.1.1.zip',
        'sha256': '191d204c00e383f335e7823a7507bbce9b49d48ebc2199d5bf90295f2c3a6159',
        'folder': 'BaroEditor', 'cache': 'ingame.zip',
    },
    'Desktop': {
        'version': '0.2.2', 'item': '3819572370', 'metadata': 'Desktop/BaroEditor/Publishing',
        'url': 'https://github.com/laohei-moddeveloper/baroeditor/releases/download/v0.2.2-desktop/BaroEditor-Desktop-0.2.2.zip',
        'sha256': '8763aa92ac5c58227c7addfc146187febe19c81305b8d1e753f1cbb67d3e1128',
        'folder': 'BaroEditor-Standalone', 'cache': 'desktop.zip',
    },
}
README = '''# BaroEditor 中英工坊文案更新 / Bilingual Workshop metadata update

包含游戏内版 0.1.1 与/或 Windows 独立版 0.2.2（见 update-package.json）。
程序文件沿用现有 GitHub Release，SHA256 已核对；本次只整理文案与更新工具，没有构建、测试或功能改动。
两版均有独立的中英文标题、简介和 GitHub 链接。不会自动执行任何更新。

## 更新本机源码仓库文案

解压后在本目录运行（将路径换为本机 baroeditor 仓库）：

    pwsh -NoProfile -File .\\Apply-LocalMetadata.ps1 -RepositoryDir 'D:\\你的路径\\baroeditor'

旧文案备份至 %LOCALAPPDATA%/BaroEditor/MetadataBackups。此命令只同步文案，不上传工坊。
也可以直接从 WorkshopMetadata 中复制所需的标题和简介。

## 更新工坊语言信息（创作者账号）

保持 Steam 登录，在 Windows 本目录执行：

    pwsh -NoProfile -File .\\Update-WorkshopLanguages.ps1 -GameDir 'D:\\steam\\steamapps\\common\\Barotrauma'

默认更新本包包含的版本。合并包可加 -Edition InGame 或 -Edition Desktop 单独更新。
只更新原条目的中英文标题与简介，不上传程序内容或创建新条目。
脚本先核对归属账号，再分别提交 schinese / english 并读回；Steam 按用户语言展示。
没有启动游戏、安装运行时或修改游戏 DLL 的步骤。需要 PowerShell 7 与游戏自带的 Steam SDK。

## 程序文件

Programs/InGame/BaroEditor：游戏内版，放入 LocalMods 后启用，需要 LuaCs 客户端 C# 支持。
Programs/Desktop/BaroEditor-Standalone：独立版，保留整个文件夹并打开 BaroEditor.exe，
需要 .NET 10 Windows Desktop Runtime x64。已有对应版本时无需替换程序。
安装目录取决于所下载包；单版包只包含对应版本。用户工程与 XML 不在本包中。

## English

Existing in-game 0.1.1 and/or desktop 0.2.2 releases plus concise Chinese/English Workshop titles,
descriptions and GitHub links. Original release archives are SHA256-verified. No rebuilds, tests
or application behavior changes were performed. Extract the complete folder.

Apply-LocalMetadata.ps1 -RepositoryDir <local baroeditor repository> copies metadata with backups.
Update-WorkshopLanguages.ps1 -GameDir <Barotrauma folder> updates the existing owned Workshop
items, then reads back both language entries. It runs only when invoked; no game launch is needed.
Programs contains the original application files. The desktop edition requires .NET 10 Windows
Desktop Runtime x64; the in-game edition requires LuaCs client C# support.

GitHub: https://github.com/laohei-moddeveloper/baroeditor
In-game: https://steamcommunity.com/sharedfiles/filedetails/?id=3819517380
Desktop: https://steamcommunity.com/sharedfiles/filedetails/?id=3819572370
'''


def sha(data):
    return hashlib.sha256(data).hexdigest()


def base_files(edition, cache):
    spec = BASES[edition]
    path = cache / spec['cache'] if cache else None
    if path and path.is_file():
        data = path.read_bytes()
    else:
        with urllib.request.urlopen(spec['url'], timeout=90) as response:
            data = response.read(16 * 1024 * 1024)
    if sha(data) != spec['sha256']:
        raise ValueError(f'Original release checksum mismatch: {edition}')
    files = {}
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        for entry in archive.infolist():
            name = PurePosixPath(entry.filename)
            if name.is_absolute() or '..' in name.parts or '\\' in entry.filename or ':' in entry.filename:
                raise ValueError('Unsafe archive path')
            if stat.S_ISLNK(entry.external_attr >> 16):
                raise ValueError('Linked archive entry')
            if entry.is_dir():
                continue
            if not name.parts or name.parts[0] != spec['folder'] or entry.file_size > 8 * 1024 * 1024:
                raise ValueError('Unexpected original release entry')
            key = f'Programs/{edition}/{name.as_posix()}'
            if key in files:
                raise ValueError('Duplicate archive entry')
            files[key] = archive.read(entry)
    return files


def build(output, editions, program_files):
    files = {'README-更新说明.md': README.encode('utf-8')}
    for script in ('Apply-LocalMetadata.ps1', 'Update-WorkshopLanguages.ps1'):
        files[script] = (ROOT / 'publishing/local-update' / script).read_bytes()
    for edition in editions:
        files.update(program_files[edition])
        metadata = ROOT / BASES[edition]['metadata']
        mapping = {'title.zh-CN.txt': 'title.zh-CN.txt', 'title.en.txt': 'title.en.txt',
                   'description.zh-CN.bbcode.txt': 'steam-zh.txt', 'description.en.bbcode.txt': 'steam-en.txt'}
        for target, source in mapping.items():
            data = (metadata / source).read_bytes()
            text = data.decode('utf-8').strip()
            if not text or (target.startswith('title') and len(text.encode('utf-8')) >= 128):
                raise ValueError('Invalid Workshop title')
            if target.startswith('description') and 'https://github.com/laohei-moddeveloper/baroeditor' not in text:
                raise ValueError('Description missing GitHub link')
            files[f'WorkshopMetadata/{edition}/{target}'] = data
    manifest = {
        'format': 1, 'update': 'bilingual-workshop-20261019', 'editions': editions,
        'application_changes': False, 'tests_run': False, 'workshop_uploaded': False,
        'git_url': 'https://github.com/laohei-moddeveloper/baroeditor',
        'base_releases': {edition: {k: BASES[edition][k] for k in ('version', 'item', 'url', 'sha256')} for edition in editions},
        'files': [{'path': name, 'bytes': len(data), 'sha256': sha(data)} for name, data in sorted(files.items())],
    }
    files['update-package.json'] = (json.dumps(manifest, ensure_ascii=False, indent=2)+'\n').encode('utf-8')
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo(name, date_time=(2026, 10, 19, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--cache-dir', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    programs = {edition: base_files(edition, args.cache_dir) for edition in BASES}
    packages = [
        ('BaroEditor-InGame-0.1.1-Bilingual-Update.zip', ['InGame']),
        ('BaroEditor-Desktop-0.2.2-Bilingual-Update.zip', ['Desktop']),
        ('BaroEditor-Both-Editions-Bilingual-Update.zip', ['InGame', 'Desktop']),
    ]
    hashes = []
    for filename, editions in packages:
        path = args.output / filename
        build(path, editions, programs)
        hashes.append(f'{sha(path.read_bytes())}  {filename}\n')
        print(f'{filename}: {path.stat().st_size} bytes')
    (args.output/'SHA256SUMS.txt').write_text(''.join(hashes), encoding='utf-8')


if __name__ == '__main__':
    main()
