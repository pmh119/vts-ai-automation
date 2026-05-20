Add-Type -AssemblyName System.Windows.Forms
$p = "C:\Program Files\WGC\VCCS\Client\Record"

$f = {

  $d0 = Get-Date; $d1 = $d0.AddDays(-1)

  $res = @($d1, $d0) | % {

    $dt = $_.ToString("yyyy_MM_dd")

    $dt2 = $_.ToString("M월 d일")

    $t = Join-Path $p $dt

    $c = if (Test-Path $t) { (gci $t -filter "*TX*" | ? {$_.Length -ge 16kb}).count } else { 0 }

    "$dt2 교신량: $($c)건"

  }

  $l.Text = $res -join "`n"

}

$obj = New-Object Windows.Forms.Form

$obj.Width=410; $obj.Height=230; $obj.Text="교신량 집계"; $obj.Topmost=1

$l = New-Object Windows.Forms.Label

$l.SetBounds(20,20,410,100); $l.Font="맑은 고딕, 24pt"

$btn = New-Object Windows.Forms.Button

$btn.SetBounds(20,130,100,30); $btn.Text="새로고침"

$btn.Add_Click($f)

$tmr = New-Object Windows.Forms.Timer

$tmr.Interval = 5000

$tmr.Add_Tick($f)

$tmr.Start()

$bt2 = New-Object Windows.Forms.Button

$bt2.SetBounds(130,130,140,30); $bt2.Text="자동 새로고침: ON"

$bt2.TextAlign="MiddleLeft"

$bt2.Add_Click({

  $tmr.Enabled = !$tmr.Enabled

  if ($tmr.Enabled) { $bt2.Text="자동 새로고침: ON" } else { $bt2.Text="자동 새로고침: OFF" }

})

$ta = New-Object Windows.Forms.Timer

$ta.Interval=500

$ta.Add_Tick({

  if($tmr.Enabled){

    if($bt2.Text -like "*●*"){ $bt2.Text="자동 새로고침: ON" }

    elseif($bt2.Text -eq "자동 새로고침: ON") { $bt2.Text="자동 새로고침: ON " }

    else{ $bt2.Text+="●" }

  }

})

$ta.Start()

$obj.Controls.AddRange(@($l, $btn, $bt2))

&$f

[void]$obj.ShowDialog()
