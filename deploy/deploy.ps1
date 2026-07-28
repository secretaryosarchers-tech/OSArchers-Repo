<#
  Imperial & Metric Challenge · FTP deploy
  Deploys ONLY the challenge.osarchers.co.uk/ subdomain folder - nothing else in this repo.

  Usage:
    powershell -File deploy/deploy.ps1            # dry run — shows what would change
    powershell -File deploy/deploy.ps1 -Apply      # actually uploads/deletes over FTP

  Reads connection details from .env (see .env.example). FTP_REMOTE_ROOT should point at the
  challenge.osarchers.co.uk document root on the server - local challenge.osarchers.co.uk/index.html
  maps to FTP_REMOTE_ROOT/index.html, not FTP_REMOTE_ROOT/challenge.osarchers.co.uk/index.html.

  Deploy set = files git would track under challenge.osarchers.co.uk/ (respects .gitignore,
  includes untracked-but-not-ignored files) minus repo-management files that don't belong on
  the live site (.idea, .claude, package.json, etc). Only new/changed files are uploaded,
  tracked via .deploy-manifest.json so re-runs are fast.
#>

param(
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$SiteDir = 'challenge.osarchers.co.uk'
$SiteRoot = Join-Path $RepoRoot $SiteDir
$EnvPath = Join-Path $SiteRoot '.env'
$ManifestPath = Join-Path $RepoRoot '.deploy-manifest.json'

function Load-DotEnv([string]$Path) {
    if (-not (Test-Path $Path)) {
        throw "No .env file found at $Path. Copy .env.example to .env and fill in your FTP credentials."
    }
    $vars = @{}
    foreach ($line in Get-Content $Path) {
        $t = $line.Trim()
        if ($t -eq '' -or $t.StartsWith('#')) { continue }
        $idx = $t.IndexOf('=')
        if ($idx -lt 0) { continue }
        $vars[$t.Substring(0, $idx).Trim()] = $t.Substring($idx + 1).Trim()
    }
    return $vars
}

function Get-ParentRel([string]$RelPath) {
    $clean = $RelPath -replace '\\', '/'
    $idx = $clean.LastIndexOf('/')
    if ($idx -lt 0) { return '' }
    return $clean.Substring(0, $idx)
}

function Get-LeafRel([string]$RelPath) {
    $clean = $RelPath -replace '\\', '/'
    $idx = $clean.LastIndexOf('/')
    if ($idx -lt 0) { return $clean }
    return $clean.Substring($idx + 1)
}

$envVars = Load-DotEnv $EnvPath

$FtpHost = $envVars['FTP_HOST']
$FtpPort = if ($envVars['FTP_PORT']) { $envVars['FTP_PORT'] } else { '21' }
$FtpUser = $envVars['FTP_USER']
$FtpPass = $envVars['FTP_PASSWORD']
$RemoteRoot = if ($envVars['FTP_REMOTE_ROOT']) { $envVars['FTP_REMOTE_ROOT'] } else { '/' }

if (-not $FtpHost -or -not $FtpUser -or -not $FtpPass) {
    throw 'FTP_HOST, FTP_USER and FTP_PASSWORD must all be set in .env'
}
if (-not $RemoteRoot.StartsWith('/')) { $RemoteRoot = '/' + $RemoteRoot }
if (-not $RemoteRoot.EndsWith('/')) { $RemoteRoot += '/' }

# ── Build the deploy file set (scoped to challenge.osarchers.co.uk/ only) ──
Push-Location $RepoRoot
try {
    $gitFilesRaw = git ls-files -z -c -o --exclude-standard -- $SiteDir
} finally {
    Pop-Location
}
$sitePrefix = "$SiteDir/"
$gitFiles = $gitFilesRaw -split "`0" | Where-Object { $_ -ne '' -and $_.StartsWith($sitePrefix) }
$siteRelFiles = $gitFiles | ForEach-Object { $_.Substring($sitePrefix.Length) }

$excludePrefixes = @('.idea/', '.claude/')
$excludeBasenames = @('.gitignore', '.gitattributes', '.editorconfig', 'package.json', 'package-lock.json', '.env.example')

$deployFiles = $siteRelFiles | Where-Object {
    $f = $_
    if ($excludeBasenames -contains (Get-LeafRel $f)) { return $false }
    foreach ($p in $excludePrefixes) { if ($f.StartsWith($p)) { return $false } }
    return $true
}

# ── Current state (size + mtime per file, keyed relative to challenge.osarchers.co.uk/) ──
$current = @{}
foreach ($rel in $deployFiles) {
    $full = Join-Path $SiteRoot $rel
    if (-not (Test-Path $full -PathType Leaf)) { continue }
    $fi = Get-Item $full
    $current[$rel] = @{ Size = $fi.Length; Modified = $fi.LastWriteTimeUtc.ToString('o') }
}

# ── Previous state ──
$manifest = @{}
if (Test-Path $ManifestPath) {
    try {
        $manifestObj = Get-Content $ManifestPath -Raw | ConvertFrom-Json
        foreach ($prop in $manifestObj.PSObject.Properties) {
            $manifest[$prop.Name] = @{ Size = $prop.Value.Size; Modified = $prop.Value.Modified }
        }
    } catch {
        $manifest = @{}
    }
}

# ── Diff ──
$new = @(); $changed = @(); $unchanged = @()
foreach ($rel in $current.Keys) {
    if (-not $manifest.ContainsKey($rel)) {
        $new += $rel
    } elseif ($manifest[$rel].Size -ne $current[$rel].Size -or $manifest[$rel].Modified -ne $current[$rel].Modified) {
        $changed += $rel
    } else {
        $unchanged += $rel
    }
}
$deleted = @($manifest.Keys | Where-Object { -not $current.ContainsKey($_) })
$toUpload = @($new + $changed) | Sort-Object

Write-Host 'Deploy plan:'
Write-Host ("  New:       {0}" -f $new.Count)
Write-Host ("  Changed:   {0}" -f $changed.Count)
Write-Host ("  Unchanged: {0} (skipped)" -f $unchanged.Count)
Write-Host ("  Deleted:   {0}" -f $deleted.Count)
if ($new.Count -gt 0) { Write-Host ''; Write-Host 'New files:'; $new | Sort-Object | ForEach-Object { Write-Host "  + $_" } }
if ($changed.Count -gt 0) { Write-Host ''; Write-Host 'Changed files:'; $changed | Sort-Object | ForEach-Object { Write-Host "  * $_" } }
if ($deleted.Count -gt 0) { Write-Host ''; Write-Host 'Removed locally (will be deleted remotely):'; $deleted | Sort-Object | ForEach-Object { Write-Host "  - $_" } }

if (-not $Apply) {
    Write-Host ''
    Write-Host 'Dry run only - no files were uploaded. Re-run with -Apply to deploy.'
    exit 0
}

if ($toUpload.Count -eq 0 -and $deleted.Count -eq 0) {
    Write-Host ''
    Write-Host 'Nothing to deploy - remote is already up to date.'
    exit 0
}

# ── FTP helpers ──
function New-FtpUri([string]$RelPath) {
    $clean = ($RelPath -replace '\\', '/').Trim('/')
    if ($clean -eq '') { return "ftp://$FtpHost`:$FtpPort$RemoteRoot" }
    $relUrl = ($clean -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/'
    return "ftp://$FtpHost`:$FtpPort$RemoteRoot$relUrl"
}

function Invoke-FtpRequest([string]$Uri, [string]$Method, [byte[]]$UploadBytes) {
    $req = [System.Net.FtpWebRequest]::Create($Uri)
    $req.Credentials = New-Object System.Net.NetworkCredential($FtpUser, $FtpPass)
    $req.Method = $Method
    $req.UsePassive = $true
    $req.UseBinary = $true
    $req.KeepAlive = $false
    if ($UploadBytes) {
        $req.ContentLength = $UploadBytes.Length
        $stream = $req.GetRequestStream()
        $stream.Write($UploadBytes, 0, $UploadBytes.Length)
        $stream.Close()
    }
    $resp = $req.GetResponse()
    $resp.Close()
}

function Ensure-RemoteDir([string]$RelDir) {
    if ([string]::IsNullOrWhiteSpace($RelDir)) { return }
    try {
        Invoke-FtpRequest (New-FtpUri $RelDir) ([System.Net.WebRequestMethods+Ftp]::MakeDirectory) $null
    } catch {
        # almost always "directory already exists" - genuine problems surface on the file upload below
    }
}

# ── Create any new remote directories, shallowest first ──
$allDirs = New-Object System.Collections.Generic.HashSet[string]
foreach ($rel in $toUpload) {
    $dir = Get-ParentRel $rel
    while ($dir -ne '') {
        [void]$allDirs.Add($dir)
        $dir = Get-ParentRel $dir
    }
}
$allDirs | Sort-Object { ($_ -split '/').Count } | ForEach-Object { Ensure-RemoteDir $_ }

# ── Upload new/changed files ──
$uploaded = 0
$failed = @()
foreach ($rel in $toUpload) {
    try {
        $bytes = [System.IO.File]::ReadAllBytes((Join-Path $SiteRoot $rel))
        Invoke-FtpRequest (New-FtpUri $rel) ([System.Net.WebRequestMethods+Ftp]::UploadFile) $bytes
        $uploaded++
        Write-Host "  uploaded: $rel"
    } catch {
        Write-Host "  FAILED upload: $rel - $($_.Exception.Message)"
        $failed += $rel
    }
}

# ── Delete files removed locally ──
$deletedCount = 0
foreach ($rel in $deleted) {
    try {
        Invoke-FtpRequest (New-FtpUri $rel) ([System.Net.WebRequestMethods+Ftp]::DeleteFile) $null
        $deletedCount++
        Write-Host "  deleted remote: $rel"
    } catch {
        Write-Host "  FAILED delete: $rel - $($_.Exception.Message)"
        $failed += $rel
    }
}

Write-Host ''
Write-Host ("Deploy complete: {0} uploaded, {1} deleted, {2} failed." -f $uploaded, $deletedCount, $failed.Count)

# ── Persist manifest, retrying failures on next run ──
$newManifest = @{}
foreach ($rel in $unchanged) { $newManifest[$rel] = $manifest[$rel] }
foreach ($rel in $toUpload) { if ($failed -notcontains $rel) { $newManifest[$rel] = $current[$rel] } }
foreach ($rel in $deleted) { if ($failed -contains $rel) { $newManifest[$rel] = $manifest[$rel] } }

$newManifest | ConvertTo-Json -Depth 5 | Set-Content -Path $ManifestPath -Encoding utf8

if ($failed.Count -gt 0) { exit 1 }
