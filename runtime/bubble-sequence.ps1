$script:sequenceIndex=-1
$script:sequenceFile=Join-Path $script:dataDir 'bubble-sequence.json'
$script:defaultSequence=@(
    [pscustomobject]@{type='额度';content='';group='';weight=1}
    [pscustomobject]@{type='语录';content='';group='';weight=1}
)

function Get-BubbleSequence {
    if([IO.File]::Exists($script:sequenceFile)){
        try{
            $saved=[IO.File]::ReadAllText($script:sequenceFile) | ConvertFrom-Json
            if($saved.steps.Count){return $saved.steps}
        }catch{}
    }
    return $script:defaultSequence
}

function Close-ImagePlayer($player) {
    if(!$player){return}
    if($player.timer){$player.timer.Stop();$player.timer.Tag=$null}
    $player.image.Dispose()
}
function Update-ImageFrame($player) {
    $image=$player.image
    if($player.count -gt 1){$null=$image.SelectActiveFrame([Drawing.Imaging.FrameDimension]::Time,$player.index)}
    $factor=[Math]::Min(1,[Math]::Min($player.limit/$image.Width,$player.limit/$image.Height))
    $copy=[Drawing.Bitmap]::new($image,[int][Math]::Max(1,($image.Width*$factor)),[int][Math]::Max(1,($image.Height*$factor)))
    $stream=[IO.MemoryStream]::new()
    try{
        $copy.Save($stream,[Drawing.Imaging.ImageFormat]::Png);$stream.Position=0
        $bitmap=[Windows.Media.Imaging.BitmapImage]::new()
        $bitmap.BeginInit();$bitmap.CacheOption='OnLoad';$bitmap.StreamSource=$stream;$bitmap.EndInit();$bitmap.Freeze()
        $player.target.Source=$bitmap
        if($player.target -eq $script:ui.Girl){
            $alpha=[Windows.Media.Imaging.FormatConvertedBitmap]::new($bitmap,[Windows.Media.PixelFormats]::Bgra32,$null,0)
            $stride=$alpha.PixelWidth*4
            if($script:alphaPixels.Length -ne $stride*$alpha.PixelHeight){$script:alphaPixels=[byte[]]::new($stride*$alpha.PixelHeight)}
            $alpha.CopyPixels($script:alphaPixels,$stride,0);$script:alphaStride=$stride;$script:bitmap=$bitmap
        }
    }finally{$stream.Dispose();$copy.Dispose()}
    if($player.timer){
        $delay=100
        if($player.delays.Length -ge 4*($player.index+1)){$delay=[Math]::Max(30,[BitConverter]::ToInt32($player.delays,4*$player.index)*10)}
        $player.timer.Interval=[TimeSpan]::FromMilliseconds($delay)
        $player.index=($player.index+1)%$player.count
    }
}
function Open-ImagePlayer([string]$path,$target,[int]$limit) {
    $file=Get-Item -LiteralPath $path -ErrorAction Stop
    if($file.Length -gt 20MB){throw '图片大于 20 MB'}
    $image=[Drawing.Image]::FromFile($file.FullName)
    $player=@{image=$image;target=$target;limit=$limit;count=1;index=0;timer=$null;delays=$null}
    try{
        if($image.Width -gt 4096 -or $image.Height -gt 4096){throw '图片边长大于 4096'}
        if($image.FrameDimensionsList -contains [Drawing.Imaging.FrameDimension]::Time.Guid){
            $player.count=$image.GetFrameCount([Drawing.Imaging.FrameDimension]::Time)
        }
        if($player.count -gt 1){
            try{$player.delays=$image.GetPropertyItem(0x5100).Value}catch{}
            $player.timer=[Windows.Threading.DispatcherTimer]::new();$player.timer.Tag=$player
            $player.timer.Add_Tick({param($timer,$event)
                if($timer.Tag.target.IsVisible){try{Update-ImageFrame $timer.Tag}catch{$timer.Stop()}}
            })
        }
        Update-ImageFrame $player
        if($player.timer){$player.timer.Start()}
        return $player
    }catch{Close-ImagePlayer $player;throw}
}
function Stop-BubbleImage {
    Close-ImagePlayer $script:sequenceImage;$script:sequenceImage=$null
    $script:ui.SequenceImage.Source=$null
}
function Set-SequenceContent([string]$Mode) {
    Stop-BubbleImage
    $script:ui.SequenceImage.Visibility='Collapsed'
    if($Mode -eq 'image'){
        try{
            $script:sequenceImage=Open-ImagePlayer $script:sequenceEntry.content $script:ui.SequenceImage 368
        }catch{
            Stop-BubbleImage
            $script:bubbleMode='text';$script:ui.QuoteText.Text='图片暂时打不开。';Fit-QuoteText
        }
    }elseif($Mode -eq 'text'){
        $block=$script:ui.QuoteText
        $block.Text=([string]$script:sequenceEntry.content).Replace('\n',[String][char]10)
        Fit-QuoteText
        $lines=@($block.Text -split '\r?\n')
        $fonts=@(([string]$script:sequenceEntry.font) -split '\|')
        $colors=@(([string]$script:sequenceEntry.color) -split '\|')
        $block.Inlines.Clear()
        for($i=0;$i -lt $lines.Count;$i++){
            if($i){$block.Inlines.Add([Windows.Documents.LineBreak]::new())}
            $run=[Windows.Documents.Run]::new($lines[$i])
            $font=$fonts[[Math]::Min($i,$fonts.Count-1)].Trim()
            $color=$colors[[Math]::Min($i,$colors.Count-1)].Trim()
            if($font){$run.FontFamily=[Windows.Media.FontFamily]::new($font)}
            if($color -match '^#[0-9A-Fa-f]{6}$'){$run.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString($color)}
            $block.Inlines.Add($run)
        }
    }
}
function Show-SequenceStep([int]$index) {
    if($index -eq 0){$script:sequenceSteps=@(Get-BubbleSequence)}
    if($index -ge $script:sequenceSteps.Count){Hide-Quota;return}
    $first=$script:sequenceSteps[$index];$end=$index+1
    if($first.group){
        while($end -lt $script:sequenceSteps.Count -and $script:sequenceSteps[$end].group -eq $first.group){$end++}
    }
    $options=@($script:sequenceSteps[$index..($end-1)])
    $total=($options | Measure-Object weight -Sum).Sum
    $draw=$script:widgetQuoteRandom.NextDouble()*$total
    foreach($entry in $options){$draw-=[double]$entry.weight;if($draw -lt 0){break}}
    $script:sequenceIndex=$end-1
    $script:sequenceEntry=$entry
    $mode=@{'额度'='quota';'语录'='quote';'文本'='text';'图片'='image'}[[string]$entry.type]
    if($mode -eq 'quota'){$script:quotaPage=1;Update-Quota}
    if($script:collapsed){Open-WidgetBubble $mode}else{Switch-Scene $mode}
    if($mode -eq 'quota'){Request-Refresh}
}

function Edit-BubbleSequence {
    $form=[Windows.Forms.Form]::new()
    $form.Text='气泡顺序';$form.Width=860;$form.Height=420
    $form.StartPosition='CenterScreen'
    $hint=[Windows.Forms.Label]::new();$hint.Dock='Top';$hint.Height=45
    $hint.Text="每行一步。类型填 额度、语录、文本 或 图片。图片填本地路径。文本用 \n 换行，字体与 #RRGGBB 颜色用 | 分隔对应各行。`r`n相邻行填同一组名会按权重随机选一项。单击行首后按 Delete 删除。"
    $grid=[Windows.Forms.DataGridView]::new();$grid.Dock='Fill';$grid.AutoSizeColumnsMode='Fill'
    foreach($col in @('类型','文字或图片路径','随机组','权重','字体','颜色')){[void]$grid.Columns.Add($col,$col)}
    $grid.Columns[1].FillWeight=260
    foreach($step in @(Get-BubbleSequence)){[void]$grid.Rows.Add($step.type,$step.content,$step.group,$step.weight,$step.font,$step.color)}
    $save=[Windows.Forms.Button]::new();$save.Text='保存顺序';$save.Dock='Bottom'
    $save.Add_Click({
        $null=$grid.EndEdit()
        try{
            $rows=@(foreach($row in $grid.Rows){
                if($row.IsNewRow){continue}
                $type=([string]$row.Cells[0].Value).Trim()
                $content=([string]$row.Cells[1].Value).Trim()
                if($type -notin @('额度','语录','文本','图片')){throw '请检查类型。'}
                if($type -in @('文本','图片') -and !$content){throw '请填写文字或图片路径。'}
                if($type -eq '图片' -and (![IO.File]::Exists($content) -or ![IO.Path]::IsPathRooted($content))){throw '请选择已有图片的完整路径。'}
                $weight=if($row.Cells[3].Value){[double]$row.Cells[3].Value}else{1.0}
                if(!($weight -gt 0 -and $weight -le 1000)){throw '权重须大于 0 且不超过 1000。'}
                $colors=([string]$row.Cells[5].Value).Trim()
                foreach($color in $colors.Split('|')){if($color.Trim() -and $color.Trim() -notmatch '^#[0-9a-fA-F]{6}$'){throw '颜色请填 #RRGGBB。'}}
                @{type=$type;content=$content;group=([string]$row.Cells[2].Value).Trim();weight=$weight;font=[string]$row.Cells[4].Value;color=$colors}
            })
            if(!$rows.Count){throw '至少保留一步。'}
            Write-WidgetJson $script:sequenceFile @{steps=$rows};$form.Close()
        }catch{[void][Windows.Forms.MessageBox]::Show($form,$_.Exception.Message)}
    })
    $form.Controls.Add($grid);$form.Controls.Add($hint);$form.Controls.Add($save)
    $script:sequenceEditorOpen=$true
    try{[void]$form.ShowDialog()}finally{$script:sequenceEditorOpen=$false;$form.Dispose()}
}
