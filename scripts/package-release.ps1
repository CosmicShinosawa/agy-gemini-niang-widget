param([Parameter(Mandatory)][string]$OutputDir)
$ErrorActionPreference='Stop'
$null=[IO.Directory]::CreateDirectory($OutputDir)
$zip=Join-Path ([IO.Path]::GetFullPath($OutputDir)) 'gemini-niang-widget.zip'
$version=(git show HEAD:antigravity-plugin/plugin.json | Out-String | ConvertFrom-Json).version
if(!$version){throw 'Missing release version in HEAD'}
git archive --format=zip "--output=$zip" HEAD
if($LASTEXITCODE){throw 'Git archive failed'}
$manifest=@{version=$version;sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash}
[IO.File]::WriteAllText((Join-Path $OutputDir 'gemini-niang-update.json'),($manifest|ConvertTo-Json))
