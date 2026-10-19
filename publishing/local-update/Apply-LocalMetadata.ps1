#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$RepositoryDir)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath($RepositoryDir)
if(-not(Test-Path -LiteralPath (Join-Path $repo 'filelist.xml')) -or -not(Test-Path -LiteralPath (Join-Path $repo 'Desktop/BaroEditor/README.md'))){throw 'Choose the local baroeditor source repository root'}
$config=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'update-package.json') -Raw | ConvertFrom-Json
$destinations=@{InGame='publishing';Desktop='Desktop/BaroEditor/Publishing'}
$mapping=@{'title.zh-CN.txt'='title.zh-CN.txt';'title.en.txt'='title.en.txt';'description.zh-CN.bbcode.txt'='steam-zh.txt';'description.en.bbcode.txt'='steam-en.txt'}
$backup=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) ('BaroEditor/MetadataBackups/'+[DateTime]::UtcNow.ToString('yyyyMMdd_HHmmss')+'-'+[Guid]::NewGuid().ToString('N'))
foreach($edition in $config.editions){
    if(-not $destinations.ContainsKey($edition)){throw 'Unexpected edition'}
    foreach($name in $mapping.Keys){
        $source=Join-Path $PSScriptRoot "WorkshopMetadata/$edition/$name"
        $relative=$destinations[$edition]+'/'+$mapping[$name]
        $destination=Join-Path $repo $relative
        if(Test-Path -LiteralPath $destination){
            $original=Join-Path $backup $relative
            New-Item -ItemType Directory -Path (Split-Path $original -Parent) -Force | Out-Null
            Copy-Item -LiteralPath $destination -Destination $original
        }
        New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $destination -Force
    }
    $folder=Join-Path $repo $destinations[$edition]
    $combined=[IO.File]::ReadAllText((Join-Path $folder 'steam-zh.txt')).Trim()+"`n`n[b]English[/b]`n"+[IO.File]::ReadAllText((Join-Path $folder 'steam-en.txt')).Trim()+"`n"
    $name=if($edition -eq 'InGame'){'steam-combined.txt'}else{'steam.txt'}
    $destination=Join-Path $folder $name
    if(Test-Path -LiteralPath $destination){
        $original=Join-Path $backup ($destinations[$edition]+'/'+$name)
        New-Item -ItemType Directory -Path (Split-Path $original -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $destination -Destination $original
    }
    [IO.File]::WriteAllText($destination,$combined,[Text.UTF8Encoding]::new($false))
}
Write-Output "Local metadata updated. Existing files backed up to: $backup"
Write-Output 'Application sources, binaries, projects and Steam metadata were not modified by this local-copy command.'
