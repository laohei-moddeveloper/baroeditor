# BaroEditor 双版本中英工坊简介更新

分别准备游戏内版 **0.1.1** 与 Windows 独立版 **0.2.2** 的简短标题、中英文简介及 GitHub 链接。两版均有独立下载包，也提供合并包。

程序文件直接沿用对应的既有 Release，并核对原始 ZIP 的 SHA256。本次没有重编译、测试或程序功能改动。新文案说明每一版的功能、要求和预览范围，不增加新的验证或功能承诺。Steam 更新尚未执行，由创作者在本机完成。

| 版本 | 中文标题 | English title | 现有工坊 ID |
| --- | --- | --- | --- |
| 游戏内 | BaroEditor \| 潜渊症事件编辑器·游戏内 | BaroEditor \| In-game Event Editor | 3819517380 |
| 独立版 | BaroEditor \| 潜渊症事件编辑器·独立版 | BaroEditor \| Standalone Event Editor | 3819572370 |

下载 `BaroEditor-Both-Editions-Bilingual-Update.zip` 可一次处理两版。解压后：

- `WorkshopMetadata`：分版本、分语言的标题与 BBCode 简介，全部附 GitHub 链接。
- `Programs`：原始程序文件；已有对应版本时无需替换。游戏内版需 LuaCs；独立版需 .NET 10 Windows Desktop Runtime x64。
- `Apply-LocalMetadata.ps1`：将文案同步到本机源码仓库，旧文案先备份。
- `Update-WorkshopLanguages.ps1`：核对登录账号对两个条目的归属，仅更新标题、简介，并独立读回两种语言；不上传程序、创建条目或启动游戏。
- `update-package.json`：对应版本、工坊 ID、原始 Release 哈希及包内文件清单。

更新本机源码仓库文案（替换为你的路径）：

```powershell
pwsh -NoProfile -File .\Apply-LocalMetadata.ps1 -RepositoryDir 'D:\你的路径\baroeditor'
```

更新现有工坊中英标题与简介（保持创作者账号 Steam 登录）：

```powershell
pwsh -NoProfile -File .\Update-WorkshopLanguages.ps1 -GameDir 'D:\steam\steamapps\common\Barotrauma'
```

默认处理所下载包的全部版本，合并包可用 `-Edition InGame` 或 `-Edition Desktop` 单独处理。`-VerifyOnly` 仅读回，不提交修改。需要 PowerShell 7；Steam SDK 来自所指定游戏目录。Steam 按用户语言选择 `schinese` / `english` 内容。

## English

Concise localized Workshop titles and descriptions for the **in-game 0.1.1** and **standalone Windows 0.2.2** editions. Both include GitHub links. Download either edition separately or the combined package.

Application files are reused from the existing releases after SHA256 verification. No rebuilds, tests or application changes were performed. Steam updates have not been submitted by this cloud task.

Extract the whole package. `Apply-LocalMetadata.ps1 -RepositoryDir <local repository>` copies the metadata to the local source checkout with backups. `Update-WorkshopLanguages.ps1 -GameDir <Barotrauma folder>` verifies ownership of the existing items, submits separate Chinese/English titles and descriptions, and independently reads them back. It never launches the game, creates a new item or uploads application content. PowerShell 7 and the owning Steam account are required.

Source and documentation: https://github.com/laohei-moddeveloper/baroeditor
