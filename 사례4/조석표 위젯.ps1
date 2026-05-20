Add-Type -AssemblyName System.Windows.Forms

Add-Type -AssemblyName System.Drawing

# WebView2 DLL ���

Add-Type -Path "C:\webview2\Microsoft.Web.WebView2.WinForms.dll"

$ConfigPath = "$env:LOCALAPPDATA\TideWidget_pos.json"

try {

    Add-Type -TypeDefinition @"

    using System;

    using System.Runtime.InteropServices;

    public class Win32 {

        [DllImport("user32.dll")]

        public static extern bool ReleaseCapture();

        [DllImport("user32.dll")]

        public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);

    }

"@

} catch { }

# -----------------------------

# 1. HTML ���� (��ü �ʺ� 910px -> 895px�� ����)

# -----------------------------

$HtmlContent = @"

<!DOCTYPE html>

<html>

<head>

<meta charset="utf-8">

<style>

    html, body {

        margin: 0; padding: 0; overflow: hidden;

        /* ��ü �ʺ� 15px ���� */

        width: 895px; height: 81px;

        display: flex; background: #2b3b4d;

        user-select: none;

        transition: opacity 0.3s ease;

    }

    

    #drag-overlay {

        position: absolute; top: 0; left: 0;

        width: 100%; height: 100%;

        z-index: 9999;

        cursor: move;

        box-sizing: border-box;

        border: 2px solid transparent;

        transition: border 0.2s ease;

    }

    #drag-overlay:hover {

        border: 2px solid #00d4ff;

    }

    #left-wrapper { width: 320px; height: 81px; overflow: hidden; position: relative; }

    #left-wrapper iframe {

        position: absolute; top: -1529px; left: -95px; 

        width: 1300px; height: 3000px; border: none;

        transform: scale(0.8); transform-origin: 0 0; display: block;

    }

    /* ���� ���� �ʺ� 590px -> 575px�� �����Ͽ� ��ü ���� ���� */

    #right-wrapper { width: 575px; height: 81px; overflow: hidden; position: relative; }

    #right-wrapper iframe {

        position: absolute; 

        top: -2354px; 

        left: -850px; 

        width: 1300px; height: 3000px; border: none;

        transform: scale(1.2); transform-origin: 0 0; display: block;

    }

</style>

</head>

<body oncontextmenu="return false;">

    <div id="drag-overlay"></div>

    <div id="left-wrapper"><iframe src="https://www.khoa.go.kr/swtc/main.do?obsPostId=DT_0002" scrolling="no" tabindex="-1"></iframe></div>

    <div id="right-wrapper"><iframe src="https://www.khoa.go.kr/swtc/main.do?obsPostId=DT_0002" scrolling="no" tabindex="-1"></iframe></div>

    <script>

        const overlay = document.getElementById('drag-overlay');

        

        overlay.addEventListener('mousedown', function(e) {

            if(e.button === 0) window.chrome.webview.postMessage('down');

        });

        overlay.addEventListener('contextmenu', function(e) {

            e.preventDefault();

            window.chrome.webview.postMessage('right_click');

        });

        overlay.addEventListener('mouseenter', () => window.chrome.webview.postMessage('hover_on'));

        overlay.addEventListener('mouseleave', () => window.chrome.webview.postMessage('hover_off'));

    </script>

</body>

</html>

"@

# -----------------------------

# 2. �� �� ���ؽ�Ʈ �޴� ����

# -----------------------------

$form = New-Object Windows.Forms.Form

$form.FormBorderStyle = 'None'

$form.TopMost = $true

$form.BackColor = [System.Drawing.Color]::FromArgb(43,59,77)

$form.StartPosition = "Manual"

$form.ShowInTaskbar = $true 

$form.Opacity = 0.85 

# ���� Ŭ���̾�Ʈ ũ�⵵ 895px�� ����

$form.ClientSize = New-Object System.Drawing.Size(895, 81)

$contextMenu = New-Object Windows.Forms.ContextMenuStrip

$exitMenu = $contextMenu.Items.Add("���� (&X)")

$exitMenu.add_Click({ $form.Close() })

# -----------------------------

# 3. ��ġ ����

# -----------------------------

if (Test-Path $ConfigPath) {

    try {

        $pos = Get-Content $ConfigPath | ConvertFrom-Json

        $form.Left = $pos.X

        $form.Top  = $pos.Y

    } catch {

        $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea

        $form.Left = $wa.Right - $form.Width

        $form.Top  = $wa.Bottom - $form.Height

    }

} else {

    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea

    $form.Left = $wa.Right - $form.Width

    $form.Top  = $wa.Bottom - $form.Height

}

# -----------------------------

# 4. WebView2 ���� �� �޽��� ó��

# -----------------------------

$webView = New-Object Microsoft.Web.WebView2.WinForms.WebView2

$webView.Dock = "Fill"

$webView.DefaultBackgroundColor = [System.Drawing.Color]::FromArgb(43,59,77)

$form.Controls.Add($webView)

$webView.add_WebMessageReceived({

    param($sender, $e)

    $msg = $e.TryGetWebMessageAsString()

    

    switch ($msg) {

        "down" {

            [Win32]::ReleaseCapture()

            [Win32]::SendMessage($form.Handle, 0xA1, 2, 0)

            @{ X = $form.Left; Y = $form.Top } | ConvertTo-Json | Set-Content $ConfigPath

        }

        "right_click" {

            $contextMenu.Show([System.Windows.Forms.Control]::MousePosition)

        }

        "hover_on" {

            $form.Opacity = 1.0 

        }

        "hover_off" {

            $form.Opacity = 0.85 

        }

    }

})

# -----------------------------

# 5. ���� �� ������ �ɼ�

# -----------------------------

$form.Add_Shown({

    $userData = "$env:LOCALAPPDATA\TideWidget_WV2"

    $options = New-Object Microsoft.Web.WebView2.Core.CoreWebView2EnvironmentOptions

    $options.AdditionalBrowserArguments = "--hide-scrollbars"

    $envWV2 = [Microsoft.Web.WebView2.Core.CoreWebView2Environment]::CreateAsync($null, $userData, $options).GetAwaiter().GetResult()

    $webView.EnsureCoreWebView2Async($envWV2)

})

$webView.Add_CoreWebView2InitializationCompleted({

    param($s, $e)

    if ($e.IsSuccess) {

        $s.CoreWebView2.Settings.AreDefaultContextMenusEnabled = $false

        $s.CoreWebView2.Settings.IsZoomControlEnabled = $false

        $s.CoreWebView2.NavigateToString($HtmlContent)

    }

})

# -----------------------------

# 6. �ڵ� ���ΰ�ħ Ÿ�̸�

# -----------------------------

$refreshTimer = New-Object System.Windows.Forms.Timer

$refreshTimer.Interval = 600000 

$refreshTimer.add_Tick({

    if ($webView.CoreWebView2) {

        $webView.CoreWebView2.NavigateToString($HtmlContent)

    }

})

$refreshTimer.Start()

$form.Add_FormClosing({ $refreshTimer.Stop() })

[void]$form.ShowDialog()
