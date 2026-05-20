# encoding: ANSI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# 1. DLL 로드
$wv2Core     = "C:\WebView2\Microsoft.Web.WebView2.Core.dll"
$wv2WinForms = "C:\WebView2\Microsoft.Web.WebView2.WinForms.dll"
if (-not (Test-Path $wv2Core) -or -not (Test-Path $wv2WinForms)) {
    [System.Windows.Forms.MessageBox]::Show("C:\WebView2\ 폴더에 DLL 파일이 없습니다.", "WebView2 DLL 오류")
    exit
}
Add-Type -Path $wv2Core
Add-Type -Path $wv2WinForms

# 2. 환경 변수 설정
$now = Get-Date
if ($now.Hour -lt 9) { $now = $now.AddDays(-1) }
$targetMonth   = $now.Month
$targetDay     = $now.Day
$targetDateStr = $now.ToString("yyyy-MM-dd")

$PORTMIS_LOGIN_URL = "https://new.portmis.go.kr/portmis/websquare/websquare.jsp?w2xPath=/portmis/w2/main/intro.xml"
$FIELD_LOGIN_URL   = "http://hp.kcg.internal/FisdOBS/index.jsp"
$FIELD_DIARY_URL   = "http://hp.kcg.internal/FisdOBS/vt/vtsWorkDiary.do?progrm_id=OBS0501"
$WV2_DATA_DIR_PM   = "$env:TEMP\VTS_WV2_PM"
$WV2_DATA_DIR_FP   = "$env:TEMP\VTS_WV2_FP"

$cfgAppData = [Environment]::GetFolderPath("ApplicationData")
$cfgLogin   = [System.IO.Path]::Combine($cfgAppData, "VTS_Login_PM.txt")
$cfgLoginF  = [System.IO.Path]::Combine($cfgAppData, "VTS_Login_Field.txt")
$cfgExcel1  = [System.IO.Path]::Combine($cfgAppData, "VTS_Excel1.txt")
$cfgExcel2  = [System.IO.Path]::Combine($cfgAppData, "VTS_Excel2.txt")

$script:dataDict  = @{}
$script:pmDataObj = $null
$script:colorIdx  = 0
$script:btnActive = $false # 초기엔 포트미스 완료 전까지 false

$rainbowColors = @(
    [System.Drawing.Color]::FromArgb(255,200,200), [System.Drawing.Color]::FromArgb(255,220,180),
    [System.Drawing.Color]::FromArgb(255,255,200), [System.Drawing.Color]::FromArgb(200,255,200),
    [System.Drawing.Color]::FromArgb(200,220,255), [System.Drawing.Color]::FromArgb(230,200,255)
)

# 3. 폼/색상 설정
$clrDark  = [System.Drawing.Color]::FromArgb(40,40,40); $clrPanel = [System.Drawing.Color]::FromArgb(245,245,248)
$clrHdr   = [System.Drawing.Color]::FromArgb(220,225,245); $clrRowLbl= [System.Drawing.Color]::FromArgb(235,235,245); $clrSub   = [System.Drawing.Color]::FromArgb(70,70,130)

$fntTitle = New-Object System.Drawing.Font("맑은 고딕", 11, [System.Drawing.FontStyle]::Bold)
$fntSub   = New-Object System.Drawing.Font("맑은 고딕", 8,  [System.Drawing.FontStyle]::Bold)
$fntNorm  = New-Object System.Drawing.Font("맑은 고딕", 9,  [System.Drawing.FontStyle]::Regular)
$fntSmall = New-Object System.Drawing.Font("맑은 고딕", 8,  [System.Drawing.FontStyle]::Regular)
$fntCell  = New-Object System.Drawing.Font("맑은 고딕", 8,  [System.Drawing.FontStyle]::Regular)
$fntBtn   = New-Object System.Drawing.Font("맑은 고딕", 13, [System.Drawing.FontStyle]::Bold)
$fntLog   = New-Object System.Drawing.Font("맑은 고딕", 8,  [System.Drawing.FontStyle]::Regular)

$colHeaders = @("진입","입항","출항","이동","통과","선박교통정보","선박안전","도선정보","항행안전방송","선박운항통제","닻끌림 예방")
$rowHeaders = @("1섹터","2섹터","3섹터")
$colCount = $colHeaders.Count; $rowCount = $rowHeaders.Count

$cellW = 54; $cellH = 22; $labelW = 40; $hdrH = 30; $padX = 12
$gridW = $labelW + $colCount * $cellW
$formW = $gridW + $padX * 2 + 4
if ($formW -lt 760) { $formW = 760 }

$form = New-Object System.Windows.Forms.Form
$form.Text = "평택VTS 관제일보 자동결산 시스템 ver.0514"
$form.Width  = $formW; $form.Height = 100
$form.StartPosition = "CenterScreen"; $form.BackColor = $clrPanel
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle; $form.MaximizeBox = $false

function New-Sep($y) {
    $s = New-Object System.Windows.Forms.Label; $s.Text = ""; $s.BorderStyle = [System.Windows.Forms.BorderStyle]::Fixed3D
    $s.Location = New-Object System.Drawing.Point(8, $y); $s.Size = New-Object System.Drawing.Size(($formW - 36), 2); $form.Controls.Add($s)
}
function New-SLabel($text,$x,$y,$w,$h) {
    $l = New-Object System.Windows.Forms.Label; $l.Text = $text; $l.Font = $fntSub; $l.ForeColor = $clrSub
    $l.Location = New-Object System.Drawing.Point($x,$y); $l.Size = New-Object System.Drawing.Size($w,$h); $form.Controls.Add($l)
}

$cy = 10
$lT = New-Object System.Windows.Forms.Label; $lT.Text = "평택VTS 관제일보 자동결산 시스템"; $lT.Font = $fntTitle; $lT.ForeColor = $clrDark
$lT.Location = New-Object System.Drawing.Point($padX,$cy); $lT.Size = New-Object System.Drawing.Size(($formW-24),24); $form.Controls.Add($lT)
$cy += 26

$lD = New-Object System.Windows.Forms.Label; $lD.Text = ("{0}년 {1}월 {2}일 기준" -f $now.Year,$targetMonth,$targetDay)
$lD.Font = $fntSub; $lD.ForeColor = [System.Drawing.Color]::FromArgb(90,90,160)
$lD.Location = New-Object System.Drawing.Point($padX,$cy); $lD.Size = New-Object System.Drawing.Size(300,16); $form.Controls.Add($lD)
$cy += 20; New-Sep $cy; $cy += 6

New-SLabel "① 관제일지 수동입력  (1섹터 · 2섹터 · 3섹터  ×  11개 항목)" $padX $cy ($formW-24) 16
$cy += 18

for ($c=0; $c -lt $colCount; $c++) {
    $h = New-Object System.Windows.Forms.Label; $h.Text = $colHeaders[$c]; $h.Font = $fntCell; $h.ForeColor = [System.Drawing.Color]::FromArgb(40,40,90)
    $h.BackColor = $clrHdr; $h.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter; $h.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $h.Location = New-Object System.Drawing.Point(($padX+$labelW+$c*$cellW),$cy); $h.Size = New-Object System.Drawing.Size($cellW,$hdrH); $form.Controls.Add($h)
}
$cy += $hdrH

$script:gridCells = @{}; $tabOrder = @()

for ($r=0; $r -lt $rowCount; $r++) {
    $rl = New-Object System.Windows.Forms.Label; $rl.Text = $rowHeaders[$r]; $rl.Font = $fntCell; $rl.ForeColor = [System.Drawing.Color]::FromArgb(50,50,50)
    $rl.BackColor = $clrRowLbl; $rl.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter; $rl.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $rl.Location = New-Object System.Drawing.Point($padX,($cy+$r*$cellH)); $rl.Size = New-Object System.Drawing.Size($labelW,$cellH); $form.Controls.Add($rl)

    for ($c=0; $c -lt $colCount; $c++) {
        $tb = New-Object System.Windows.Forms.TextBox; $tb.Font = $fntCell; $tb.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
        $tb.Location = New-Object System.Drawing.Point(($padX+$labelW+$c*$cellW),($cy+$r*$cellH)); $tb.Size = New-Object System.Drawing.Size($cellW,$cellH)
        $form.Controls.Add($tb); $script:gridCells["${r}_${c}"] = $tb; $tabOrder += $tb
    }
}
$cy += $rowCount*$cellH + 8; New-Sep $cy; $cy += 6

$vhfColW = 66
New-SLabel "② VHF 교신량  (A14~C14)" $padX $cy 220 16
$pilotLblX = $padX + 3*($vhfColW+2) + 18
$lPilotHdr = New-Object System.Windows.Forms.Label
$lPilotHdr.Text = "③ 도선횟수"
$lPilotHdr.Font = $fntCell; $lPilotHdr.ForeColor = [System.Drawing.Color]::FromArgb(40,40,90)
$lPilotHdr.BackColor = $clrHdr; $lPilotHdr.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lPilotHdr.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$lPilotHdr.Location = New-Object System.Drawing.Point($pilotLblX, $cy)
$lPilotHdr.Size = New-Object System.Drawing.Size(90, 16)
$form.Controls.Add($lPilotHdr)

$cy += 18

$script:vhfCells = @()
for ($i=0; $i -lt 3; $i++) {
    $lv = New-Object System.Windows.Forms.Label; $lv.Text = ("" + ($i+1) + "섹터"); $lv.Font = $fntCell; $lv.ForeColor = [System.Drawing.Color]::FromArgb(40,40,90)
    $lv.BackColor = $clrHdr; $lv.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter; $lv.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $lv.Location = New-Object System.Drawing.Point(($padX+$i*($vhfColW+2)),$cy); $lv.Size = New-Object System.Drawing.Size($vhfColW,16); $form.Controls.Add($lv)

    $tv = New-Object System.Windows.Forms.TextBox; $tv.Font = $fntCell; $tv.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
    $tv.Location = New-Object System.Drawing.Point(($padX+$i*($vhfColW+2)),($cy+16)); $tv.Size = New-Object System.Drawing.Size($vhfColW,$cellH)
    $form.Controls.Add($tv); $script:vhfCells += $tv; $tabOrder += $tv
}

$pilotTb = New-Object System.Windows.Forms.TextBox; $pilotTb.Font = $fntCell; $pilotTb.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
$pilotTb.Location = New-Object System.Drawing.Point($pilotLblX,($cy+16)); $pilotTb.Size = New-Object System.Drawing.Size(90,$cellH)
$form.Controls.Add($pilotTb); $tabOrder += $pilotTb

$cy += 16+$cellH+10; New-Sep $cy; $cy += 6

$credCol1X = $padX; $credCol2X = $padX + 260; $credCol3X = $padX + 520
New-SLabel "PORT-MIS 계정" $credCol1X $cy 180 16
New-SLabel "현장업무포털 계정" $credCol2X $cy 180 16
New-SLabel "① 일일통계 계산표" $credCol3X $cy ($formW-$credCol3X-12) 16
$cy += 18

$lPmId = New-Object System.Windows.Forms.Label; $lPmId.Text="ID"; $lPmId.Font=$fntSmall; $lPmId.Location=New-Object System.Drawing.Point($credCol1X,$cy); $lPmId.Size=New-Object System.Drawing.Size(30,22); $form.Controls.Add($lPmId)
$txtPmId = New-Object System.Windows.Forms.TextBox; $txtPmId.Font=$fntNorm; $txtPmId.Location=New-Object System.Drawing.Point(($credCol1X+30),$cy); $txtPmId.Size=New-Object System.Drawing.Size(120,22); $form.Controls.Add($txtPmId)
$chkSavePm = New-Object System.Windows.Forms.CheckBox; $chkSavePm.Text="저장"; $chkSavePm.Font=$fntSmall; $chkSavePm.Location=New-Object System.Drawing.Point(($credCol1X+155),$cy); $chkSavePm.Size=New-Object System.Drawing.Size(48,22); $form.Controls.Add($chkSavePm)

$lFpId = New-Object System.Windows.Forms.Label; $lFpId.Text="ID"; $lFpId.Font=$fntSmall; $lFpId.Location=New-Object System.Drawing.Point($credCol2X,$cy); $lFpId.Size=New-Object System.Drawing.Size(30,22); $form.Controls.Add($lFpId)
$txtFpId = New-Object System.Windows.Forms.TextBox; $txtFpId.Font=$fntNorm; $txtFpId.Location=New-Object System.Drawing.Point(($credCol2X+30),$cy); $txtFpId.Size=New-Object System.Drawing.Size(120,22); $form.Controls.Add($txtFpId)
$chkSaveFp = New-Object System.Windows.Forms.CheckBox; $chkSaveFp.Text="저장"; $chkSaveFp.Font=$fntSmall; $chkSaveFp.Location=New-Object System.Drawing.Point(($credCol2X+155),$cy); $chkSaveFp.Size=New-Object System.Drawing.Size(48,22); $form.Controls.Add($chkSaveFp)

$txtExcel1 = New-Object System.Windows.Forms.TextBox; $txtExcel1.Font=$fntSmall; $txtExcel1.Location=New-Object System.Drawing.Point($credCol3X,$cy); $txtExcel1.Size=New-Object System.Drawing.Size(($formW-$credCol3X-66),22)
if ([System.IO.File]::Exists($cfgExcel1)) { $txtExcel1.Text=[System.IO.File]::ReadAllText($cfgExcel1,[System.Text.Encoding]::UTF8) } else { $txtExcel1.Text="C:\webview2\일일통계 계산표.xlsx" }
$form.Controls.Add($txtExcel1)
$btnB1 = New-Object System.Windows.Forms.Button; $btnB1.Text="..."; $btnB1.Font=$fntSmall; $btnB1.Location=New-Object System.Drawing.Point(($formW-62),$cy); $btnB1.Size=New-Object System.Drawing.Size(30,22); $form.Controls.Add($btnB1)
$cy += 24

$lPmPw = New-Object System.Windows.Forms.Label; $lPmPw.Text="PW"; $lPmPw.Font=$fntSmall; $lPmPw.Location=New-Object System.Drawing.Point($credCol1X,$cy); $lPmPw.Size=New-Object System.Drawing.Size(30,22); $form.Controls.Add($lPmPw)
$txtPmPw = New-Object System.Windows.Forms.TextBox; $txtPmPw.Font=$fntNorm; $txtPmPw.PasswordChar='*'; $txtPmPw.Location=New-Object System.Drawing.Point(($credCol1X+30),$cy); $txtPmPw.Size=New-Object System.Drawing.Size(120,22); $form.Controls.Add($txtPmPw)

$lFpPw = New-Object System.Windows.Forms.Label; $lFpPw.Text="PW"; $lFpPw.Font=$fntSmall; $lFpPw.Location=New-Object System.Drawing.Point($credCol2X,$cy); $lFpPw.Size=New-Object System.Drawing.Size(30,22); $form.Controls.Add($lFpPw)
$txtFpPw = New-Object System.Windows.Forms.TextBox; $txtFpPw.Font=$fntNorm; $txtFpPw.PasswordChar='*'; $txtFpPw.Location=New-Object System.Drawing.Point(($credCol2X+30),$cy); $txtFpPw.Size=New-Object System.Drawing.Size(120,22); $form.Controls.Add($txtFpPw)

$lbl2 = New-Object System.Windows.Forms.Label; $lbl2.Text="② VTS 운영실적"; $lbl2.Font=$fntSub; $lbl2.ForeColor=$clrSub; $lbl2.Location=New-Object System.Drawing.Point($credCol3X,$cy); $lbl2.Size=New-Object System.Drawing.Size(160,16); $form.Controls.Add($lbl2)
$txtExcel2 = New-Object System.Windows.Forms.TextBox; $txtExcel2.Font=$fntSmall; $txtExcel2.Location=New-Object System.Drawing.Point($credCol3X,($cy+18)); $txtExcel2.Size=New-Object System.Drawing.Size(($formW-$credCol3X-66),22)
if ([System.IO.File]::Exists($cfgExcel2)) { $txtExcel2.Text=[System.IO.File]::ReadAllText($cfgExcel2,[System.Text.Encoding]::UTF8) } else { $txtExcel2.Text="C:\webview2\VTS 운영실적.xls" }
$form.Controls.Add($txtExcel2)
$btnB2 = New-Object System.Windows.Forms.Button; $btnB2.Text="..."; $btnB2.Font=$fntSmall; $btnB2.Location=New-Object System.Drawing.Point(($formW-62),($cy+18)); $btnB2.Size=New-Object System.Drawing.Size(30,22); $form.Controls.Add($btnB2)
$cy += 46

if ([System.IO.File]::Exists($cfgLogin)) { try { $sl=[System.IO.File]::ReadAllLines($cfgLogin,[System.Text.Encoding]::UTF8); if($sl.Length -ge 2){$txtPmId.Text=$sl[0];$txtPmPw.Text=$sl[1];$chkSavePm.Checked=$true} } catch {} }
if ([System.IO.File]::Exists($cfgLoginF)) { try { $slf=[System.IO.File]::ReadAllLines($cfgLoginF,[System.Text.Encoding]::UTF8); if($slf.Length -ge 2){$txtFpId.Text=$slf[0];$txtFpPw.Text=$slf[1];$chkSaveFp.Checked=$true} } catch {} }

$btnB1.Add_Click({ $dlg=New-Object System.Windows.Forms.OpenFileDialog; $dlg.Filter="Excel Files|*.xls;*.xlsx;*.xlsm"; try{$d=[System.IO.Path]::GetDirectoryName($txtExcel1.Text);if([System.IO.Directory]::Exists($d)){$dlg.InitialDirectory=$d}}catch{}; if($dlg.ShowDialog()-eq[System.Windows.Forms.DialogResult]::OK){$txtExcel1.Text=$dlg.FileName;try{[System.IO.File]::WriteAllText($cfgExcel1,$dlg.FileName,[System.Text.Encoding]::UTF8)}catch{}} })
$btnB2.Add_Click({ $dlg=New-Object System.Windows.Forms.OpenFileDialog; $dlg.Filter="Excel Files|*.xls;*.xlsx;*.xlsm"; try{$d=[System.IO.Path]::GetDirectoryName($txtExcel2.Text);if([System.IO.Directory]::Exists($d)){$dlg.InitialDirectory=$d}}catch{}; if($dlg.ShowDialog()-eq[System.Windows.Forms.DialogResult]::OK){$txtExcel2.Text=$dlg.FileName;try{[System.IO.File]::WriteAllText($cfgExcel2,$dlg.FileName,[System.Text.Encoding]::UTF8)}catch{}} })
New-Sep $cy; $cy += 6

# 체크박스 및 재시도 버튼 추가 영역
$chkShowBrowser = New-Object System.Windows.Forms.CheckBox
$chkShowBrowser.Text = "진행과정(웹 브라우저) 숨기기 해제"
$chkShowBrowser.Font = $fntSmall; $chkShowBrowser.ForeColor = [System.Drawing.Color]::FromArgb(40,40,90)
$chkShowBrowser.Location = New-Object System.Drawing.Point($padX, $cy)
$chkShowBrowser.Size = New-Object System.Drawing.Size(250, 22)
$chkShowBrowser.Checked = $false
$form.Controls.Add($chkShowBrowser)

$btnRetryPM = New-Object System.Windows.Forms.Button
$btnRetryPM.Text = "포트미스 집계 재시도"
$btnRetryPM.Font = $fntSmall; $btnRetryPM.ForeColor = [System.Drawing.Color]::White; $btnRetryPM.BackColor = [System.Drawing.Color]::IndianRed
$btnRetryPM.Location = New-Object System.Drawing.Point(($padX + 260), $cy)
$btnRetryPM.Size = New-Object System.Drawing.Size(140, 22)
$btnRetryPM.Visible = $false
$btnRetryPM.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$form.Controls.Add($btnRetryPM)
$cy += 28

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "포트미스 백그라운드 집계 대기 중..."
$btnRun.Font = $fntBtn; $btnRun.ForeColor = $clrDark; $btnRun.BackColor = [System.Drawing.Color]::FromArgb(180,180,180)
$btnRun.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat; $btnRun.FlatAppearance.BorderSize = 2; $btnRun.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(180,160,0)
$btnRun.Location = New-Object System.Drawing.Point(8,$cy); $btnRun.Size = New-Object System.Drawing.Size(($formW-36),44)
$btnRun.Enabled = $false
$form.Controls.Add($btnRun)
$cy += 52

$pnlStatus = New-Object System.Windows.Forms.Panel
$pnlStatus.Location = New-Object System.Drawing.Point(8,$cy); $pnlStatus.Size = New-Object System.Drawing.Size(($formW-36),148)
$pnlStatus.BackColor = [System.Drawing.Color]::FromArgb(28,28,36); $pnlStatus.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$form.Controls.Add($pnlStatus)

$statusDefs = @(
    @{ Text="PORT-MIS 집계 대기 중...";            Key="pm_status" },
    @{ Text="일일통계 계산표 Excel 입력 대기 중..."; Key="excel1"    },
    @{ Text="VTS 운영실적 Excel 입력 대기 중...";    Key="excel2"    },
    @{ Text="현장업무포털 실적 입력 대기 중...";     Key="fp_status" }
)

$script:statusControls = @{}; $lineH = 28
for ($i=0; $i -lt $statusDefs.Count; $i++) {
    $info=$statusDefs[$i]
    $dot=New-Object System.Windows.Forms.Label; $dot.Text="●"; $dot.Font=New-Object System.Drawing.Font("맑은 고딕",7)
    $dot.ForeColor=[System.Drawing.Color]::FromArgb(70,70,80); $dot.Location=New-Object System.Drawing.Point(10,(6+$i*$lineH)); $dot.Size=New-Object System.Drawing.Size(14,20); $pnlStatus.Controls.Add($dot)
    $lbl=New-Object System.Windows.Forms.Label; $lbl.Text=$info.Text; $lbl.Font=$fntLog
    $lbl.ForeColor=[System.Drawing.Color]::FromArgb(120,120,130); $lbl.Location=New-Object System.Drawing.Point(26,(6+$i*$lineH)); $lbl.Size=New-Object System.Drawing.Size(($formW-60),20); $pnlStatus.Controls.Add($lbl)
    $script:statusControls[$info.Key]=@{dot=$dot;lbl=$lbl}
}
$lblErrLog=New-Object System.Windows.Forms.Label; $lblErrLog.Text=""; $lblErrLog.Font=New-Object System.Drawing.Font("맑은 고딕", 9, [System.Drawing.FontStyle]::Bold)
$lblErrLog.ForeColor=[System.Drawing.Color]::FromArgb(255,100,100); $lblErrLog.Location=New-Object System.Drawing.Point(10,(6+$statusDefs.Count*$lineH))
$lblErrLog.Size=New-Object System.Drawing.Size(($formW-40),20); $pnlStatus.Controls.Add($lblErrLog)
$cy += 156; $form.Height = $cy + 46

for ($i=0; $i -lt ($tabOrder.Count-1); $i++) {
    $nxt=$tabOrder[$i+1]
    $tabOrder[$i].Add_KeyDown({ param($s,$e); if($e.KeyCode-eq[System.Windows.Forms.Keys]::Tab){$e.SuppressKeyPress=$true;$nxt.Focus()} }.GetNewClosure())
}

function Set-StatusActive($key, $text=$null) {
    $c=$script:statusControls[$key]; if($null-eq$c){return}
    if ($text) { $c.lbl.Text = $text }
    $c.dot.ForeColor=[System.Drawing.Color]::FromArgb(255,200,0); $c.lbl.ForeColor=[System.Drawing.Color]::FromArgb(255,220,80); $c.lbl.Font=New-Object System.Drawing.Font("맑은 고딕",8,[System.Drawing.FontStyle]::Bold); [System.Windows.Forms.Application]::DoEvents()
}
function Set-StatusDone($key, $text=$null) {
    $c=$script:statusControls[$key]; if($null-eq$c){return}
    if ($text) { $c.lbl.Text = $text }
    $c.dot.ForeColor=[System.Drawing.Color]::FromArgb(60,210,90); $c.lbl.ForeColor=[System.Drawing.Color]::FromArgb(80,230,110); $c.lbl.Font=New-Object System.Drawing.Font("맑은 고딕",8,[System.Drawing.FontStyle]::Bold); [System.Windows.Forms.Application]::DoEvents()
}
function Set-StatusError($key, $msg, $text=$null) {
    $c=$script:statusControls[$key]; if($null-eq$c){return}
    if ($text) { $c.lbl.Text = $text }
    $c.dot.ForeColor=[System.Drawing.Color]::FromArgb(255,70,70); $c.lbl.ForeColor=[System.Drawing.Color]::FromArgb(255,100,100); $c.lbl.Font=New-Object System.Drawing.Font("맑은 고딕",8,[System.Drawing.FontStyle]::Bold); $lblErrLog.Text=("오류: "+$msg); $lblErrLog.ForeColor=[System.Drawing.Color]::FromArgb(255,100,100); [System.Windows.Forms.Application]::DoEvents()
}
function Reset-AllStatus {
    foreach($key in $script:statusControls.Keys){
        $c=$script:statusControls[$key]
        $c.dot.ForeColor=[System.Drawing.Color]::FromArgb(70,70,80); $c.lbl.ForeColor=[System.Drawing.Color]::FromArgb(120,120,130); $c.lbl.Font=$fntLog
        if ($key -eq "pm_status") { $c.lbl.Text = "PORT-MIS 집계 대기 중..." }
        if ($key -eq "excel1") { $c.lbl.Text = "일일통계 계산표 Excel 입력 대기 중..." }
        if ($key -eq "excel2") { $c.lbl.Text = "VTS 운영실적 Excel 입력 대기 중..." }
        if ($key -eq "fp_status") { $c.lbl.Text = "현장업무포털 실적 입력 대기 중..." }
    }
    $lblErrLog.Text=""; $lblErrLog.ForeColor=[System.Drawing.Color]::FromArgb(255,100,100); [System.Windows.Forms.Application]::DoEvents()
}
function Unlock-Btn {
    $script:btnActive=$true; $btnRun.Enabled=$true; $btnRun.BackColor=[System.Drawing.Color]::FromArgb(255,255,200)
    $btnRun.Text = "엑셀(운영실적) 및 현장업무포털 실적 입력 실행 >Click<"
}
function End-WithError($key, $msg, $text=$null) { Set-StatusError $key $msg $text; Unlock-Btn }

$timer=New-Object System.Windows.Forms.Timer; $timer.Interval=250
$timer.Add_Tick({
    $script:colorIdx=($script:colorIdx+1)%6; if($script:btnActive){$btnRun.BackColor=$rainbowColors[$script:colorIdx]}
})
$timer.Start()

function Get-SafeNum($v) {
    if ($null -eq $v -or [System.DBNull]::Value.Equals($v)) { return 0 }
    $str = $v.ToString().Trim() -replace "[^0-9.]", ""; if ([string]::IsNullOrWhiteSpace($str)) { return 0 }
    try { return [double]$str } catch { return 0 }
}

# UI가 멈추지 않도록 하는 딜레이 함수
function Wait-UI($ms) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $ms) {
        [System.Windows.Forms.Application]::DoEvents()
        [System.Threading.Thread]::Sleep(10)
    }
    $sw.Stop()
}

function Wait-Condition($conditionScript,$timeoutSec) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while($sw.Elapsed.TotalSeconds -lt $timeoutSec) {
        [System.Windows.Forms.Application]::DoEvents()
        if(& $conditionScript){return $true}
        [System.Threading.Thread]::Sleep(10)
    }
    return $false
}
function Invoke-WV2Script($wv,$js) {
    $task = $wv.CoreWebView2.ExecuteScriptAsync($js)
    while (-not $task.IsCompleted) { [System.Windows.Forms.Application]::DoEvents(); [System.Threading.Thread]::Sleep(10) }
    return $task.Result
}
function WV2-ExecAndWait($wv,$js,$resultPattern,$timeoutSec=30) {
    $script:wv2Msg=$null
    $handler=[EventHandler[Microsoft.Web.WebView2.Core.CoreWebView2WebMessageReceivedEventArgs]]{ param($s,$e) $script:wv2Msg=$e.TryGetWebMessageAsString() }
    $wv.CoreWebView2.add_WebMessageReceived($handler)
    Invoke-WV2Script $wv $js | Out-Null
    $ok=Wait-Condition {$null -ne $script:wv2Msg -and $script:wv2Msg -match $resultPattern} $timeoutSec
    $wv.CoreWebView2.remove_WebMessageReceived($handler)
    return @{ok=$ok;msg=$script:wv2Msg}
}
function Navigate-AndWait($wv,$url,$timeoutSec=30) {
    $script:navDone=$false
    $handler=[EventHandler[Microsoft.Web.WebView2.Core.CoreWebView2NavigationCompletedEventArgs]]{ param($s,$e) $script:navDone=$true }
    $wv.CoreWebView2.add_NavigationCompleted($handler); $wv.CoreWebView2.Navigate($url)
    $ok=Wait-Condition {$script:navDone} $timeoutSec
    $wv.CoreWebView2.remove_NavigationCompleted($handler); return $ok
}
function Wait-WV2Nav($wv,$timeoutSec=30) {
    $script:navDone=$false
    $handler=[EventHandler[Microsoft.Web.WebView2.Core.CoreWebView2NavigationCompletedEventArgs]]{ param($s,$e) $script:navDone=$true }
    $wv.CoreWebView2.add_NavigationCompleted($handler)
    $ok=Wait-Condition {$script:navDone} $timeoutSec
    $wv.CoreWebView2.remove_NavigationCompleted($handler); return $ok
}

# 브라우저 폼 생성 (체크박스 연동)
function Create-BrowserForm($title) {
    $f = New-Object System.Windows.Forms.Form
    $f.Text = $title
    $f.Width = 1120; $f.Height = 740
    $f.StartPosition = "Manual"
    if ($chkShowBrowser.Checked) {
        $f.Location = New-Object System.Drawing.Point(100, 100)
    } else {
        $f.Location = New-Object System.Drawing.Point(-20000, -20000)
        $f.ShowInTaskbar = $false
    }
    $f.Add_FormClosing({ param($s,$e) if($e.CloseReason -eq 'UserClosing'){$e.Cancel=$true; $s.Location=New-Object System.Drawing.Point(-20000,-20000); $s.ShowInTaskbar=$false} })
    return $f
}

$chkShowBrowser.Add_CheckedChanged({
    $pt = if($chkShowBrowser.Checked){ New-Object System.Drawing.Point(100,100) }else{ New-Object System.Drawing.Point(-20000,-20000) }
    if ($script:frmPM) { $script:frmPM.Location = $pt; $script:frmPM.ShowInTaskbar = $chkShowBrowser.Checked; if($chkShowBrowser.Checked){$script:frmPM.Focus()} }
    if ($script:frmFP) { $script:frmFP.Location = $pt; $script:frmFP.ShowInTaskbar = $chkShowBrowser.Checked; if($chkShowBrowser.Checked){$script:frmFP.Focus()} }
})

# =====================================================================
# 백그라운드 PORT-MIS 비동기 집계 로직
# =====================================================================
function Start-PMJob {
    if ($txtPmId.Text.Trim() -eq "" -or $txtPmPw.Text -eq "") {
        Set-StatusError "pm_status" "PORT-MIS 계정이 입력되지 않아 자동 집계를 대기합니다. ID/PW 입력 후 재시도하세요." "PORT-MIS 집계 대기 중..."
        $btnRetryPM.Visible = $true
        return
    }

    $btnRetryPM.Visible = $false
    $script:btnActive = $false
    $btnRun.Enabled = $false
    $btnRun.Text = "포트미스 백그라운드 집계 중... (수동입력 가능)"
    $btnRun.BackColor = [System.Drawing.Color]::FromArgb(180,180,180)
   
    $pmId=$txtPmId.Text.Trim(); $pmPw=$txtPmPw.Text
    $startVal=$now.ToString("yyyyMMdd")+"0000"
    $endVal=$now.ToString("yyyyMMdd")+"2359"

    if($chkSavePm.Checked){try{[System.IO.File]::WriteAllLines($cfgLogin,@($pmId,$pmPw),[System.Text.Encoding]::UTF8)}catch{}}

    Set-StatusActive "pm_status" "PORT-MIS 로그인 중..."
   
    if (-not $script:frmPM) {
        $script:frmPM = Create-BrowserForm "PORT-MIS (자동처리중)"
        $script:wvPM = New-Object Microsoft.Web.WebView2.WinForms.WebView2
        $script:wvPM.Dock = "Fill"
        $script:frmPM.Controls.Add($script:wvPM)
        $script:frmPM.Show()
    }

    try {
        $envTask = [Microsoft.Web.WebView2.Core.CoreWebView2Environment]::CreateAsync($null,$WV2_DATA_DIR_PM,$null)
        while (-not $envTask.IsCompleted) { Wait-UI 10 }
        $envPM = $envTask.Result

        $initTask = $script:wvPM.EnsureCoreWebView2Async($envPM)
        while (-not $initTask.IsCompleted) { Wait-UI 10 }
       
        $script:wvPM.CoreWebView2.Settings.AreDefaultScriptDialogsEnabled=$false
        Navigate-AndWait $script:wvPM $PORTMIS_LOGIN_URL 30 | Out-Null; Wait-UI 1500

        $safeId=$pmId -replace "'","\'"; $safePw=$pmPw -replace "'","\'"
        $loginJS=@"
(async function(){
    var idEl = document.getElementById('mf_frameLogin1_login1_id');
    var pwEl = document.getElementById('mf_frameLogin1_login1_pw');
    if(idEl && pwEl){
        idEl.focus(); idEl.value='$safeId';
        idEl.dispatchEvent(new Event('input',{bubbles:true})); idEl.dispatchEvent(new Event('change',{bubbles:true}));
        await new Promise(r=>setTimeout(r,300));
        pwEl.focus(); pwEl.value='$safePw';
        pwEl.dispatchEvent(new Event('input',{bubbles:true})); pwEl.dispatchEvent(new Event('change',{bubbles:true}));
        await new Promise(r=>setTimeout(r,300));
        window.alert=function(){return true;}; window.confirm=function(){return true;};
        document.getElementById('mf_frameLogin1_btnLogin').click();
    }
    window.chrome.webview.postMessage('LOGIN_DONE');
})();
"@
        WV2-ExecAndWait $script:wvPM $loginJS "LOGIN_DONE" 10 | Out-Null
        Wait-WV2Nav $script:wvPM 30 | Out-Null; Wait-UI 1500

        $navigateListJS=@"
(async function(){
    for(let attempt = 0; attempt < 5; attempt++) {
        var t=document.getElementById('mf_side_wframe_side_tab_tab_tabs2_tabHTML');
        if(t) t.click();
        await new Promise(r=>setTimeout(r, 1500));
        var anchors=document.querySelectorAll('a');
        for(var i=0;i<anchors.length;i++){
            if(anchors[i].innerText.includes('LIST') || anchors[i].innerText.includes('list')){
                anchors[i].click(); break;
            }
        }
        for(var j=0; j<35; j++){
            if(document.body.innerText.match(/총\s*\d+\s*건/)) {
                window.chrome.webview.postMessage('LIST_READY');
                return;
            }
            await new Promise(r=>setTimeout(r, 100));
        }
    }
    window.chrome.webview.postMessage('LIST_FAIL');
})();
"@
        $navResult = WV2-ExecAndWait $script:wvPM $navigateListJS "LIST_READY" 30
        if (-not $navResult.ok -or $navResult.msg -eq 'LIST_FAIL') {
            throw "나의 메뉴 클릭 및 관제입력 LIST 로딩에 실패했습니다."
        }

        Set-StatusActive "pm_status" "PORT-MIS 관제입력LIST 집계 중..."
       
        $pmSuccess = $false; $retryCount = 0
        while (-not $pmSuccess -and $retryCount -lt 3) {
            $retryCount++
            $extractJS = @"
(async function(){
    function getVis(sel){
        var els=document.querySelectorAll(sel);
        for(var i=0;i<els.length;i++){if(els[i].offsetParent!==null)return els[i];}
        return null;
    }
    var selectBox=getVis("select[title='작업종류 선택']");
    var searchBtn=getVis("[id*='btnSearch']");
    var sEl=getVis("input[id*='calBeginCntr']");
    var eEl=getVis("input[id*='calEndCntr']");

    function setDate(el,val){
        if(!el)return;
        el.focus();
        try{
            var compId=el.id.replace('_input','');
            var comp=window.WebSquare?WebSquare.util.getComponentById(compId):null;
            if(comp&&typeof comp.setValue==='function'){comp.setValue(val);}else{el.value=val;}
        }catch(err){el.value=val;}
        el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true})); el.blur();
    }
    function triggerSearch(){
        try{
            var comp=window.WebSquare?WebSquare.util.getComponentById(searchBtn.id):null;
            if(comp&&typeof comp.trigger==='function'){comp.trigger('click');return;}
        }catch(err){}
        var fb=getVis("[id*='btnSearch'] a")||searchBtn;
        if(fb)fb.click();
    }

    if(sEl&&eEl){
        setDate(sEl,'$startVal'); await new Promise(r=>setTimeout(r,300));
        setDate(eEl,'$endVal'); await new Promise(r=>setTimeout(r,300));
        document.body.click(); await new Promise(r=>setTimeout(r,300));
    }
   
    async function resetToAll() {
        var opt = Array.from(selectBox.options).find(o => o.text.includes('전체'));
        if(!opt) return;
        selectBox.focus(); selectBox.value = opt.value;
        selectBox.dispatchEvent(new Event('change',{bubbles:true})); selectBox.blur();
        await new Promise(r=>setTimeout(r, 200));
        triggerSearch();
        await new Promise(r=>setTimeout(r, 1500));
    }

    async function doSearch(name, isRetry) {
        var opt = Array.from(selectBox.options).find(o => o.text.includes(name));
        if(!opt) return "0";
        selectBox.focus(); selectBox.value = opt.value;
        selectBox.dispatchEvent(new Event('change',{bubbles:true})); selectBox.blur();

        var prev = document.body.innerText.match(/총\s*\d+\s*건/);
        var prevVal = prev ? prev[0] : "초기화";

        await new Promise(r=>setTimeout(r, 200));
        triggerSearch();

        for(var i=0; i<60; i++) {
            await new Promise(r=>setTimeout(r,100));
            var cur = document.body.innerText.match(/총\s*\d+\s*건/);
            if(cur && cur[0] !== prevVal) return cur[0].match(/\d+/)[0];
        }

        // 변화 없음 감지 → 재시도 (1회만)
        if(!isRetry) {
            await resetToAll();
            return await doSearch(name, true);
        }

        // 재시도도 실패 → 현재 화면값 그대로 반환
        var fallback = document.body.innerText.match(/총\s*\d+\s*건/);
        return fallback ? fallback[0].match(/\d+/)[0] : "0";
    }

    await doSearch('전체'); await doSearch('대양'); await doSearch('전체');
    var clickTargets=['대양','입항','출항','이안','양묘','전체'];
    var results={};
    for(var target of clickTargets){ results[target] = await doSearch(target); }
    window.chrome.webview.postMessage('EXTRACT:'+JSON.stringify(results));
})();
"@
            $rEx = WV2-ExecAndWait $script:wvPM $extractJS "EXTRACT:" 90
            $pmData = ($rEx.msg -replace "EXTRACT:","") | ConvertFrom-Json

            $valTotal = [int]$pmData.전체
            $maxIndiv = ([int]$pmData.입항, [int]$pmData.출항, [int]$pmData.대양, [int]$pmData.이안, [int]$pmData.양묘 | Measure-Object -Maximum).Maximum

            if ($valTotal -gt 0 -and $valTotal -ge $maxIndiv) {
                $pmSuccess = $true
            } else {
                $lblErrLog.Text = "포트미스 데이터 지연 감지 ($retryCount/3). 안전하게 재조회합니다..."
                Wait-UI 2000
            }
        }

        if (-not $pmSuccess) {
            $ans = [System.Windows.Forms.MessageBox]::Show("3회 재조회 후에도 포트미스 데이터가 0건이거나 비정상입니다.`n네트워크 지연일 수 있습니다. 이 값을 그대로 확정하시겠습니까?", "집계 확인", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
            if ($ans -ne [System.Windows.Forms.DialogResult]::Yes) {
                throw "포트미스 데이터 이상으로 인한 사용자 취소"
            }
        }
       
        $script:pmDataObj = $pmData
        Set-StatusDone "pm_status" "PORT-MIS 집계 완료"
       
        $lblErrLog.Text = "▶ 포트미스 집계 완료! [전체:$($pmData.전체) / 입항:$($pmData.입항) / 출항:$($pmData.출항) / 대양:$($pmData.대양) / 이안:$($pmData.이안) / 양묘:$($pmData.양묘)]"
        $lblErrLog.ForeColor = [System.Drawing.Color]::FromArgb(80,230,110)
        Unlock-Btn

    } catch {
        Set-StatusError "pm_status" $_.Exception.Message "PORT-MIS 집계 실패"
        $btnRetryPM.Visible = $true
        $btnRun.Text = "포트미스 집계가 실패하여 대기중입니다."
    }
}

$btnRetryPM.Add_Click({
    Reset-AllStatus
    Start-PMJob
})

# =====================================================================
# 메인 자동화 로직 (엑셀 + 현장업무포털)
# =====================================================================
$btnRun.Add_Click({
    $vhf1=$script:vhfCells[0].Text.Trim(); $vhf2=$script:vhfCells[1].Text.Trim(); $vhf3=$script:vhfCells[2].Text.Trim(); $pilot=$pilotTb.Text.Trim()
    if($vhf1-eq""-or$vhf2-eq""-or$vhf3-eq""){[System.Windows.Forms.MessageBox]::Show("VHF 교신량을 모두 입력해주세요.");return}
    if($pilot-eq""){[System.Windows.Forms.MessageBox]::Show("도선횟수를 입력해주세요.");return}
    if($txtFpId.Text.Trim()-eq""-or$txtFpPw.Text-eq""){[System.Windows.Forms.MessageBox]::Show("현장포털 ID/PW를 입력해주세요.");return}
    if($null -eq $script:pmDataObj){[System.Windows.Forms.MessageBox]::Show("포트미스 데이터가 없습니다. 재시도 버튼을 눌러주세요.");return}

    $fpId=$txtFpId.Text.Trim(); $fpPw=$txtFpPw.Text
    $excel1Path=$txtExcel1.Text.Trim(); $excel2Path=$txtExcel2.Text.Trim()
   
    if($chkSaveFp.Checked){try{[System.IO.File]::WriteAllLines($cfgLoginF,@($fpId,$fpPw),[System.Text.Encoding]::UTF8)}catch{}}

    $script:btnActive=$false; $btnRun.Enabled=$false; $btnRun.BackColor=[System.Drawing.Color]::FromArgb(180,180,180)

    # ── STEP 2: 일일통계 계산표 및 운영실적 엑셀 입력 ──
    $excel=$null
    try{
        $excel=New-Object -ComObject Excel.Application
        $excel.Visible=$true; $excel.DisplayAlerts=$false

        $wb1=$excel.Workbooks.Open($excel1Path)
        try {
            $ws1=$wb1.Sheets.Item(1)

            for($r=0;$r -lt 3;$r++){
                for($c=0;$c -lt 11;$c++){
                    $ws1.Cells.Item(3+$r, 2+$c).Value2 = [int](Get-SafeNum $script:gridCells["${r}_${c}"].Text)
                }
            }

            $ws1.Cells.Item(10,1).Value2  = Get-SafeNum $script:pmDataObj.입항
            $ws1.Cells.Item(10,3).Value2  = Get-SafeNum $script:pmDataObj.출항
            $ws1.Cells.Item(10,5).Value2  = Get-SafeNum $script:pmDataObj.대양
            $ws1.Cells.Item(10,7).Value2  = Get-SafeNum $script:pmDataObj.이안
            $ws1.Cells.Item(10,9).Value2  = Get-SafeNum $script:pmDataObj.양묘
            $ws1.Cells.Item(10,11).Value2 = Get-SafeNum $script:pmDataObj.전체
            $ws1.Range("A14").Value2 = Get-SafeNum $vhf1; $ws1.Range("B14").Value2 = Get-SafeNum $vhf2; $ws1.Range("C14").Value2 = Get-SafeNum $vhf3
            $ws1.Range("N10").Value2 = Get-SafeNum $pilot

            $wb1.Save(); Set-StatusDone "excel1" "일일통계 계산표 Excel 입력 완료"

            $dataRow20=$ws1.Range("A20:M20").Value2
            $dataRow14=$ws1.Range("A14:C14").Value2
           
            $oa=$ws1.Range("A28").Value2; $ob=$ws1.Range("B28").Value2; $oc=$ws1.Range("C28").Value2; $od=$ws1.Range("D28").Value2; $oe=$ws1.Range("E28").Value2; $of=$ws1.Range("F28").Value2; $og=$ws1.Range("G28").Value2
            $ca=$ws1.Range("A34").Value2; $cb=$ws1.Range("B34").Value2; $cc=$ws1.Range("C34").Value2; $cd=$ws1.Range("D34").Value2; $ce=$ws1.Range("E34").Value2; $cf=$ws1.Range("F34").Value2; $cg=$ws1.Range("G34").Value2
        } finally {
            try { $wb1.Close($false) } catch {}
        }

        $wb2=$excel.Workbooks.Open($excel2Path)
        try {
            $targetSheetName=($now.Month).ToString()+"월"
            $wsT=$wb2.Sheets.Item($targetSheetName)
            $wsT.Activate()

            $tRow=0
            for($r=6;$r -le 36;$r++){ if((Get-SafeNum $wsT.Cells.Item($r,1).Value2) -eq $targetDay){$tRow=$r; break} }

            if($tRow -gt 0){
                # [안전장치 1] 운영실적 기존 데이터 여부 검사
                $writeColumns = @(2,3,4,5,6,7,8,9,10,14,15,16,17,18,19)
                $hasData = $false
                foreach($c in $writeColumns){
                    $v = $wsT.Cells.Item($tRow, $c).Value2
                    if($null -ne $v -and $v.ToString().Trim() -ne "" -and (Get-SafeNum $v) -ne 0){ $hasData = $true; break }
                }
                if($hasData){
                    $ans = [System.Windows.Forms.MessageBox]::Show("VTS 운영실적 엑셀표의 $targetDay 일 란에 이미 입력된 내용이 존재합니다.`n덮어쓰기를 진행하시겠습니까?", "데이터 보호 알림", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
                    if($ans -ne [System.Windows.Forms.DialogResult]::Yes){
                        throw "기존 데이터 보호를 위해 운영실적 엑셀 입력을 취소했습니다."
                    }
                }

                $wsT.Cells.Item($tRow,2).Value2  = Get-SafeNum $dataRow20[1,1]
                $wsT.Cells.Item($tRow,3).Value2  = Get-SafeNum $dataRow20[1,2]
                $wsT.Cells.Item($tRow,4).Value2  = Get-SafeNum $dataRow20[1,3]
                $wsT.Cells.Item($tRow,5).Value2  = Get-SafeNum $dataRow20[1,4]
                $wsT.Cells.Item($tRow,6).Value2  = Get-SafeNum $dataRow20[1,5]
                $wsT.Cells.Item($tRow,7).Value2  = Get-SafeNum $dataRow20[1,6]
                $wsT.Cells.Item($tRow,8).Value2  = Get-SafeNum $dataRow14[1,1]
                $wsT.Cells.Item($tRow,9).Value2  = Get-SafeNum $dataRow14[1,2]
                $wsT.Cells.Item($tRow,10).Value2 = Get-SafeNum $dataRow14[1,3]
                $wsT.Cells.Item($tRow,14).Value2 = Get-SafeNum $dataRow20[1,8]
                $wsT.Cells.Item($tRow,15).Value2 = Get-SafeNum $dataRow20[1,9]
                $wsT.Cells.Item($tRow,16).Value2 = Get-SafeNum $dataRow20[1,10]
                $wsT.Cells.Item($tRow,17).Value2 = Get-SafeNum $dataRow20[1,11]
                $wsT.Cells.Item($tRow,18).Value2 = Get-SafeNum $dataRow20[1,12]
                $wsT.Cells.Item($tRow,19).Value2 = Get-SafeNum $dataRow20[1,13]
                $wb2.Save(); Set-StatusDone "excel2" "VTS 운영실적 Excel 입력 완료"
            }
        } finally {
            try { $wb2.Close($false) } catch {}
        }
    } catch { End-WithError "excel1" $_.Exception.Message "Excel 입력 실패"; return }
    finally { try{ $excel.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)|Out-Null }catch{} }

    # ── STEP 3: 현장업무포털 자동입력 ──
    Set-StatusActive "fp_status" "현장업무포털 로그인 중..."
   
    if (-not $script:frmFP) {
        $script:frmFP = Create-BrowserForm "현장업무포털 (자동처리중)"
        $script:wvFP = New-Object Microsoft.Web.WebView2.WinForms.WebView2
        $script:wvFP.Dock = "Fill"
        $script:frmFP.Controls.Add($script:wvFP)
        $script:frmFP.Show()
    }

    try{
        $envTask2 = [Microsoft.Web.WebView2.Core.CoreWebView2Environment]::CreateAsync($null,$WV2_DATA_DIR_FP,$null)
        while (-not $envTask2.IsCompleted) { Wait-UI 10 }
        $envFP = $envTask2.Result

        $initTask2 = $script:wvFP.EnsureCoreWebView2Async($envFP)
        while (-not $initTask2.IsCompleted) { Wait-UI 10 }
       
        $script:wvFP.CoreWebView2.Settings.AreDefaultScriptDialogsEnabled=$false
        Navigate-AndWait $script:wvFP $FIELD_LOGIN_URL 30 | Out-Null; Wait-UI 1500

        $safeFpId=$fpId -replace "'","\'"; $safeFpPw=$fpPw -replace "'","\'"
        $fpLoginJS=@"
(async function(){
    var idEl = document.getElementById('wrkr_id');
    var pwEl = document.getElementById('secret_no');
    if(idEl && pwEl){
        idEl.focus(); idEl.value='$safeFpId'; idEl.dispatchEvent(new Event('input',{bubbles:true})); idEl.dispatchEvent(new Event('change',{bubbles:true}));
        await new Promise(r=>setTimeout(r,300));
        pwEl.focus(); pwEl.value='$safeFpPw'; pwEl.dispatchEvent(new Event('input',{bubbles:true})); pwEl.dispatchEvent(new Event('change',{bubbles:true}));
        window.alert=function(){return true;}; window.confirm=function(){return false;};
        document.getElementById('login').click();
    }
    window.chrome.webview.postMessage('FP_LOGIN_SUBMITTED');
})();
"@
        WV2-ExecAndWait $script:wvFP $fpLoginJS "FP_LOGIN_SUBMITTED" 10 | Out-Null
        Wait-WV2Nav $script:wvFP 30 | Out-Null; Wait-UI 1500

        $closeModalJS=@"
(function(){
    var c=document.getElementById('closeBtn');
    if(c){c.click();}
    window.chrome.webview.postMessage('MODAL_HANDLED');
})();
"@
        WV2-ExecAndWait $script:wvFP $closeModalJS "MODAL_HANDLED" 5 | Out-Null
       
        Set-StatusActive "fp_status" "현장업무포털 실적 입력 중..."
        Navigate-AndWait $script:wvFP $FIELD_DIARY_URL 30 | Out-Null; Wait-UI 2000

        $oa=Get-SafeNum $oa; $ob=Get-SafeNum $ob; $oc=Get-SafeNum $oc; $od=Get-SafeNum $od; $oe=Get-SafeNum $oe; $of=Get-SafeNum $of; $og=Get-SafeNum $og
        $ca=Get-SafeNum $ca; $cb=Get-SafeNum $cb; $cc=Get-SafeNum $cc; $cd=Get-SafeNum $cd; $ce=Get-SafeNum $ce; $cf=Get-SafeNum $cf; $cg=Get-SafeNum $cg

        # 현장포털 데이터 밀어넣기 및 안전장치 스캔
        $fpInputJS=@"
(async function(){
    var rows=document.querySelectorAll('#list_tbody tr');
    for(var i=0;i<rows.length;i++){ if(rows[i].innerText.includes('$targetDateStr')){ rows[i].click(); break; } }
    await new Promise(r=>setTimeout(r,2000));

    function sv(name, idx, val){
        var els = document.querySelectorAll('input[name="'+name+'"]');
        var el = els.length > idx ? els[idx] : els[0];
        if(!el) return;
        el.focus(); el.value=val;
        el.dispatchEvent(new Event('input',{bubbles:true})); el.dispatchEvent(new Event('change',{bubbles:true})); el.blur();
    }
   
    function clickBtn(id){
        var btn = document.getElementById(id);
        if(!btn) return;
        try{
            var comp=window.WebSquare?WebSquare.util.getComponentById(id):null;
            if(comp&&typeof comp.trigger==='function'){comp.trigger('click');}else{btn.click();}
        }catch(ex){btn.click();}
    }
   
    function scanDirty(tabIndex){
    var tabPanels = document.querySelectorAll('.tabs-inner');
    var panel = tabPanels[tabIndex];
    if(!panel) return false;
    var inputs = panel.querySelectorAll('input[name*="_acmslt_co"]');
    for(var k=0; k<inputs.length; k++){
        if(inputs[k].offsetParent !== null &&
           inputs[k].value !== '0' &&
           inputs[k].value !== '') return true;
    }
    return false;
}

    document.querySelectorAll('span.tabs-title')[2].click();
    await new Promise(r=>setTimeout(r,1500));
   
    // [안전장치 2] 탭 3 스캔
    if(scanDirty(2)) {
        window.chrome.webview.postMessage('FP_DIRTY_3');
        return;
    }

    sv('a_acmslt_co',0,'$oa'); sv('b_acmslt_co',0,'$ob'); sv('c_acmslt_co',0,'$oc'); sv('d_acmslt_co',0,'$od'); sv('e_acmslt_co',0,'$oe'); sv('f_acmslt_co',0,'$of'); sv('g_acmslt_co',0,'$og');
    window.confirm=function(){return true;}; window.alert=function(){return true;};
    clickBtn('tab3_b_Insert');
    await new Promise(r=>setTimeout(r,3000));

    document.querySelectorAll('span.tabs-title')[3].click();
    await new Promise(r=>setTimeout(r,1500));
   
    // [안전장치 2] 탭 4 스캔
    if(scanDirty(3)) {
        window.chrome.webview.postMessage('FP_DIRTY_4');
        return;
    }

    sv('a_acmslt_co',1,'$ca'); sv('b_acmslt_co',1,'$cb'); sv('c_acmslt_co',1,'$cc'); sv('d_acmslt_co',1,'$cd'); sv('e_acmslt_co',1,'$ce'); sv('f_acmslt_co',1,'$cf'); sv('g_acmslt_co',1,'$cg');
    window.confirm=function(){return true;}; window.alert=function(){return true;};
    clickBtn('tab4_b_Insert');
    await new Promise(r=>setTimeout(r,3000));

    window.chrome.webview.postMessage('FP_INPUT_DONE');
})();
"@
        $fpRes = WV2-ExecAndWait $script:wvFP $fpInputJS "(FP_INPUT_DONE|FP_DIRTY_3|FP_DIRTY_4)" 60
        if($fpRes.msg -match "FP_DIRTY") {
            $ans = [System.Windows.Forms.MessageBox]::Show("현장업무포털의 해당 탭에 기본값 '0'이 아닌 정보가 이미 입력되어 있습니다.`n(기존 입력자료를 덮어쓰지 않고 중단합니다.)`n강제로 덮어쓰시려면 기존 내용을 삭제 후 다시 시도해주세요.", "데이터 보호 알림", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            throw "현장업무포털 데이터 보호를 위해 입력을 중단했습니다."
        }

        Set-StatusDone "fp_status" "현장업무포털 실적 입력 완료"
        $lblErrLog.Text = "모든 작업이 완벽하게 완료되었습니다! [전체:$($script:pmDataObj.전체) / 입항:$($script:pmDataObj.입항) / 출항:$($script:pmDataObj.출항) / 대양:$($script:pmDataObj.대양) / 이안:$($script:pmDataObj.이안) / 양묘:$($script:pmDataObj.양묘)]"
        $lblErrLog.ForeColor = [System.Drawing.Color]::FromArgb(80,230,110)
    } catch { End-WithError "fp_status" $_.Exception.Message "현장업무포털 실적 입력 실패" }
    finally { Unlock-Btn }
})

# 폼 종료 시 리소스 정리
$form.Add_FormClosed({
    try { if ($script:wvPM) { $script:wvPM.Dispose() } } catch {}
    try { if ($script:frmPM) { $script:frmPM.Dispose() } } catch {}
    try { if ($script:wvFP) { $script:wvFP.Dispose() } } catch {}
    try { if ($script:frmFP) { $script:frmFP.Dispose() } } catch {}
    [System.Environment]::Exit(0)
})

# 폼이 띄워지자마자 실행
$form.Add_Shown({
    Wait-UI 500
    Start-PMJob
})

$form.ShowDialog() | Out-Null
