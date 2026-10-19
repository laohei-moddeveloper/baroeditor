#requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$GameDir,
    [ValidateSet('All','InGame','Desktop')][string]$Edition='All',
    [switch]$VerifyOnly
)
$ErrorActionPreference='Stop'
if(-not $IsWindows){throw 'Run on Windows with the owning Steam account logged in. No game launch is needed.'}
$config=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'update-package.json') -Raw | ConvertFrom-Json
$targets=if($Edition -eq 'All'){@($config.editions)}else{@($Edition)}
if(-not $targets.Count -or @($targets | Where-Object {$_ -notin @('InGame','Desktop') -or $_ -notin $config.editions}).Count){throw 'Edition is not present in this update package'}
$ids=@{InGame='3819517380';Desktop='3819572370'}
$env:SteamAppId='602960'
[Reflection.Assembly]::LoadFrom((Join-Path $GameDir 'Facepunch.Steamworks.Win64.dll')) | Out-Null
$flags=[Reflection.BindingFlags]'Public,NonPublic,Static,Instance'
function Read-LocalizedItem($id,[string]$language) {
    # The bundled SDK's Query.InLanguage does not apply its stored field.
    # Set the language through its native interface for a genuine readback.
    $api=([Steamworks.SteamUGC].GetProperty('Internal',$flags)).GetValue($null)
    function Invoke-Ugc([string]$name,[object[]]$arguments){$api.GetType().GetMethod($name,$flags).Invoke($api,$arguments)}
    $handle=Invoke-Ugc 'CreateQueryUGCDetailsRequest' @([Steamworks.Data.PublishedFileId[]]@($id),[uint]1)
    $page=$null
    try {
        if(-not(Invoke-Ugc 'SetLanguage' @($handle,$language))){throw 'SetLanguage refused'}
        if(-not(Invoke-Ugc 'SetReturnLongDescription' @($handle,$true))){throw 'Long description refused'}
        Invoke-Ugc 'SetAllowCachedResponse' @($handle,[uint]0) | Out-Null
        $call=Invoke-Ugc 'SendQueryUGCRequest' @($handle)
        $type=$call.GetType();$deadline=[DateTime]::UtcNow.AddSeconds(45)
        while(-not $type.GetProperty('IsCompleted',$flags).GetValue($call)){
            if([DateTime]::UtcNow -gt $deadline){throw 'Localized query timed out'}
            [Threading.Thread]::Sleep(20)
        }
        $callback=$type.GetMethod('GetResult',$flags).Invoke($call,@())
        if(-not $callback -or $callback.GetType().GetField('Result',$flags).GetValue($callback) -ne [Steamworks.Result]::OK){throw 'Localized query failed'}
        $page=[Activator]::CreateInstance([Steamworks.Ugc.ResultPage])
        [Steamworks.Ugc.ResultPage].GetField('Handle',$flags).SetValue($page,$handle)
        $page.ResultCount=[int]$callback.GetType().GetField('NumResultsReturned',$flags).GetValue($callback)
        $page.TotalCount=[int]$callback.GetType().GetField('TotalMatchingResults',$flags).GetValue($callback)
        $entries=@($page.Entries)
        if($entries.Count -ne 1){throw 'Expected exactly one localized item'}
        return @{title=$entries[0].Title;description=$entries[0].Description;id=[string]$entries[0].Id}
    } finally {
        if($page){$page.Dispose()}else{Invoke-Ugc 'ReleaseQueryUGCRequest' @($handle) | Out-Null}
    }
}
try {
    [Steamworks.SteamClient]::Init(602960,$true)
    if(-not [Steamworks.SteamClient]::IsLoggedOn -or [uint][Steamworks.SteamClient]::AppId -ne 602960){throw 'Expected logged-on Barotrauma Steam account'}
    $work=@()
    # Confirm both target owners and read all metadata before any submission.
    foreach($target in $targets){
        $id=[Steamworks.Data.PublishedFileId]::op_Implicit([ulong]$ids[$target])
        $item=[Steamworks.Ugc.Item]::GetAsync($id,0).WaitAsync([TimeSpan]::FromSeconds(45)).GetAwaiter().GetResult()
        if(-not $item -or $item.Result -ne [Steamworks.Result]::OK -or $item.Owner.Id -ne [Steamworks.SteamClient]::SteamId -or [uint]$item.ConsumerApp -ne 602960){throw "Target not owned by this Barotrauma account: $target"}
        foreach($locale in @(@{code='schinese';suffix='zh-CN'},@{code='english';suffix='en'})){
            $directory=Join-Path $PSScriptRoot "WorkshopMetadata/$target"
            $title=[IO.File]::ReadAllText((Join-Path $directory ('title.'+$locale.suffix+'.txt'))).Trim()
            $description=[IO.File]::ReadAllText((Join-Path $directory ('description.'+$locale.suffix+'.bbcode.txt'))).Trim()
            if(-not $title -or [Text.Encoding]::UTF8.GetByteCount($title) -ge 128 -or -not $description.Contains('https://github.com/laohei-moddeveloper/baroeditor')){throw "Invalid title or missing GitHub link: $target"}
            $work+=@{target=$target;id=$id;language=$locale.code;title=$title;description=$description}
        }
    }
    $verified=@()
    foreach($entry in $work){
        if(-not $VerifyOnly){
            $editor=[Steamworks.Ugc.Editor]::new($entry.id)
            $editor=$editor.InLanguage($entry.language).WithTitle($entry.title).WithDescription($entry.description)
            $result=$editor.SubmitAsync($null,$null).WaitAsync([TimeSpan]::FromSeconds(120)).GetAwaiter().GetResult()
            if(-not $result.Success -or $result.NeedsWorkshopAgreement){throw ('Metadata submit failed or requires Steam agreement: '+$entry.target+' '+$entry.language+' '+$result.Result)}
        }
        $read=Read-LocalizedItem $entry.id $entry.language
        if($read.id -ne [string]$entry.id -or $read.title -cne $entry.title -or $read.description -cne $entry.description){throw ('Localized readback mismatch: '+$entry.target+' '+$entry.language)}
        $verified+=@{edition=$entry.target;id=[string]$entry.id;language=$entry.language;title=$read.title;description_matches=$true}
        Write-Output ('Verified '+$entry.target+' / '+$entry.language+': '+$read.title)
    }
    $verified | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'localization-verification.json') -Encoding utf8
} finally {if([Steamworks.SteamClient]::IsValid){[Steamworks.SteamClient]::Shutdown()}}
