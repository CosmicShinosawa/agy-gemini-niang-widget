param([Parameter(Mandatory)][string]$DataDir,[switch]$Refresh)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes

function Get-QuotaPeriod([string]$name) {
    switch -Regex ($name.Trim()) {
        '^(5h|Five Hour|五小时)$' {return @{minutes=300;label='5 小时'}}
        '^(weekly|每周)$' {return @{minutes=10080;label='每周'}}
        '^(daily|每日|每天)$' {return @{minutes=1440;label='每日'}}
        '^(monthly|每月)$' {return @{minutes=$null;label='每月'}}
        '^(\d{1,8})\s*(m|min|分钟|h|hours?|小时|d|days?|天|w|weeks?|周)$' {
            $count=[long]$Matches[1]
            $unit=switch -Regex ($Matches[2]) {
                '^(m|分钟)' {@(1,'分钟')}
                '^(h|小时)' {@(60,'小时')}
                '^(d|天)' {@(1440,'天')}
                '^(w|周)' {@(10080,'周')}
            }
            return @{minutes=$count*$unit[0];label="$count $($unit[1])"}
        }
        default {return @{minutes=$null;label=$name.Trim()}}
    }
}

function Convert-QuotaGroups($groups) {
    foreach($group in $groups){
        if(!$group.displayName){continue}
        foreach($bucket in $group.buckets){
            if(!$bucket.window -or $null -eq $bucket.remainingFraction){continue}
            $period=Get-QuotaPeriod $bucket.window
            $fraction=0.0
            if(![double]::TryParse([string]$bucket.remainingFraction,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$fraction) -or !($fraction -ge 0 -and $fraction -le 1)){continue}
            $reset=$null
            if($bucket.resetTime){try{$reset=([DateTimeOffset]$bucket.resetTime).ToUnixTimeSeconds()}catch{}}
            $remaining=[Math]::Round(100*[double]$fraction,4)
            [pscustomobject]@{group=$group.displayName;label=$period.label;minutes=$period.minutes;remaining=$remaining;used=[Math]::Round(100-$remaining,4);resetsAt=$reset}
        }
    }
}

function Read-AntigravityRows {
    $desktop=Get-Process Antigravity -ErrorAction SilentlyContinue | Where-Object Path | Select-Object -First 1
    if(!$desktop){return}
    $binary=Join-Path (Split-Path $desktop.Path) 'resources\bin\language_server.exe'
    $serverIds=@(Get-Process language_server -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $binary -and $_.SessionId -eq $desktop.SessionId} | Select-Object -ExpandProperty Id)
    if(!$serverIds.Count){return}
    $directory=Join-Path $env:USERPROFILE '.gemini\antigravity\daemon'
    foreach($file in (Get-ChildItem -LiteralPath $directory -Filter 'hub_*.json' -File | Sort-Object LastWriteTimeUtc -Descending)){
        try{$hub=[IO.File]::ReadAllText($file.FullName) | ConvertFrom-Json}catch{continue}
        if($hub.pid -notin $serverIds -or !$hub.csrfToken -or $hub.httpPort -lt 1 -or $hub.httpPort -gt 65535){continue}
        $listener=Get-NetTCPConnection -LocalPort $hub.httpPort -State Listen -OwningProcess $hub.pid -ErrorAction SilentlyContinue
        if(!$listener){continue}
        Add-Type -AssemblyName System.Net.Http
        $handler=[Net.Http.HttpClientHandler]::new()
        $handler.UseProxy=$false;$handler.AllowAutoRedirect=$false
        $client=[Net.Http.HttpClient]::new($handler)
        $body=[Net.Http.StringContent]::new('{}',[Text.Encoding]::UTF8,'application/json')
        try{
            $client.Timeout=[TimeSpan]::FromSeconds(5)
            $client.DefaultRequestHeaders.Add('X-Codeium-Csrf-Token',[string]$hub.csrfToken)
            $client.DefaultRequestHeaders.Add('Connect-Protocol-Version','1')
            $uri="http://127.0.0.1:$($hub.httpPort)/exa.language_server_pb.LanguageServerService/RetrieveUserQuotaSummary"
            $response=$client.PostAsync($uri,$body).GetAwaiter().GetResult()
            $null=$response.EnsureSuccessStatusCode()
            $result=$response.Content.ReadAsStringAsync().GetAwaiter().GetResult() | ConvertFrom-Json
            return Convert-QuotaGroups $result.response.groups
        }finally{if($response){$response.Dispose()};$body.Dispose();$client.Dispose()}
    }
}

function Get-QuotaPageText {
    $element=[Windows.Automation.AutomationElement]
    $scope=[Windows.Automation.TreeScope]
    $textCondition=[Windows.Automation.PropertyCondition]::new($element::ControlTypeProperty,[Windows.Automation.ControlType]::Text)
    $desktopWindows=$element::RootElement.FindAll($scope::Children,[Windows.Automation.Condition]::TrueCondition)
    $processIds=@(Get-Process Antigravity -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
    foreach($window in $desktopWindows){
        if($window.Current.ProcessId -notin $processIds){continue}
        # Only read a settings window/document; chat content can contain arbitrary labels and percentages.
        $settings=$window
        if($settings.Current.Name -notmatch '^(?:Settings|设置)(?:\s*[-–—|·].*)?$'){
            $names=[Windows.Automation.OrCondition]::new(
                [Windows.Automation.PropertyCondition]::new($element::NameProperty,'Settings'),
                [Windows.Automation.PropertyCondition]::new($element::NameProperty,'设置'))
            $condition=[Windows.Automation.AndCondition]::new($names,[Windows.Automation.PropertyCondition]::new($element::ControlTypeProperty,[Windows.Automation.ControlType]::Window))
            $settings=$window.FindFirst($scope::Descendants,$condition)
        }
        if(!$settings){continue}
        $texts=@($settings.FindAll($scope::Descendants,$textCondition) | ForEach-Object {$_.Current.Name.Trim()})
        if($texts -match '^(Models & Usage|模型(与|和)用量)'){
            if($Refresh){
                $refreshName=[Windows.Automation.OrCondition]::new(
                    [Windows.Automation.PropertyCondition]::new($element::NameProperty,'Refresh quota and credits data'),
                    [Windows.Automation.PropertyCondition]::new($element::NameProperty,'刷新配额和点数数据'))
                $button=$settings.FindFirst($scope::Descendants,$refreshName)
                if($button){
                    $button.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern).Invoke()
                    for($attempt=0;$attempt -lt 12;$attempt++){
                        Start-Sleep -Milliseconds 250
                        if($button.Current.IsEnabled -and $attempt -ge 3){break}
                    }
                    $texts=@($settings.FindAll($scope::Descendants,$textCondition) | ForEach-Object {$_.Current.Name.Trim()})
                }
            }
            return $texts
        }
    }
}

function Read-QuotaRows($lines) {
    $group='';$label='';$minutes=0
    for($i=1;$i -lt $lines.Count;$i++){
        $line=$lines[$i]
        if($line -match '^(?:(?<group>.+?)\s+)?(?:(?<period>Weekly|Five Hour|Daily|Monthly|\d+\s*(?:Hours?|Days?|Weeks?|min|[mhdw]))\s+Limit(?: Remaining)?|(?<period>每周|五小时|每日|每天|每月|\d+\s*(?:分钟|小时|天|周))剩余额度)$' -or
           $line -match '^(?:(?<period>.+?)\s+Limit Remaining|(?<period>.+?)剩余额度)$'){
            $prefix=$Matches['group']
            $period=Get-QuotaPeriod $Matches['period']
            $minutes=$period.minutes;$label=$period.label
            $previous=''
            for($j=$i-1;$j -ge 0;$j--){
                $candidate=$lines[$j].Trim()
                if(!$candidate -or $candidate -match '^[iⓘℹ️]$'){continue}
                $previous=$candidate;break
            }
            if($prefix){$group=$prefix}
            elseif($previous -and $previous -notmatch '^\d+(\.\d+)?\s*%$'){$group=$previous}
        }elseif($label -and $line -match '^(\d+(?:\.\d+)?)\s*%$'){
            $value=[double]::Parse($Matches[1],[Globalization.CultureInfo]::InvariantCulture)
            if($value -le 100 -and $group){
                [pscustomobject]@{group=$group;label=$label;minutes=$minutes;remaining=$value;used=100-$value;resetsAt=$null}
            }
            $label=''
        }
    }
}

$null=[IO.Directory]::CreateDirectory($DataDir)
$file=Join-Path $DataDir 'status.json'
$now=[DateTimeOffset]::Now
try {
    try{$rows=@(Read-AntigravityRows)}catch{$rows=@()}
    $source='Antigravity 本机额度接口';$plan=''
    if(!$rows.Count){
        $lines=@(Get-QuotaPageText)
        $rows=@(Read-QuotaRows $lines)
        if(!$rows.Count){throw '当前额度不可用'}
        $source='Antigravity 设置页'
        $planIndex=[array]::IndexOf($lines,'Your Plan:')
        if($planIndex -ge 0 -and $planIndex+1 -lt $lines.Count){$plan=$lines[$planIndex+1]}
    }
    $result=@{ok=$true;queryOk=$true;source=$source;observedAt=$now.ToUnixTimeMilliseconds();planLabel=$plan;windows=$rows;error=$null}
}catch{
    $result=$null
    foreach($saved in @($file,($file+'.bak'))){
        if(![IO.File]::Exists($saved)){continue}
        try{$previous=[IO.File]::ReadAllText($saved) | ConvertFrom-Json}catch{continue}
        if($previous.windows -and $previous.observedAt){$result=$previous;break}
    }
    if(!$result){$result=[pscustomobject]@{ok=$false;observedAt=0;windows=@()}}
    $result|Add-Member -Force NoteProperty queryOk $false
    $result|Add-Member -Force NoteProperty error '后台额度暂不可用，可打开设置 → Models 读取'
}
$temp=$file+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
try{
    [IO.File]::WriteAllText($temp,($result | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
    if([IO.File]::Exists($file)){
        if($result.queryOk){[IO.File]::Replace($temp,$file,($file+'.bak'),$true)}
        else{[IO.File]::Replace($temp,$file,[System.Management.Automation.Language.NullString]::Value)}
    }else{[IO.File]::Move($temp,$file)}
}finally{if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)}}
