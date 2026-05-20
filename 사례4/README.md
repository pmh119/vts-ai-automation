# [사례 4] 실시간 조석(물때) 정보 상시 모니터링 데스크바 위젯 (VTS Tide Monitor)

VTS 관제 업무의 안전성과 실시간 상황 대응 능력을 강화하기 위해 평택항의 실시간 조석(Tide) 정보만을 추출하여 모니터 작업표시줄 상단에 콤팩트한 띠 형태로 상시 표출하는 초경량 투명 오버레이 위젯입니다.

---

## 1. 개발 배경 및 필요성 (AS-IS)
* **조석 정보 모니터링의 중요성:** 수심이 얕고 흘수(Draft) 제약을 받는 선박이 많은 평택항의 특성상 실시간 물때(조석 시간 및 조위) 정보 파악은 선박의 통항 스케줄을 결정하는 관제의 핵심 지표입니다.
* **번거로운 확인 절차:** 매번 정보가 필요할 때마다 외부망 웹 브라우저를 열고 '국립해양조사원 스마트 조석예보' 페이지에 로그인/접속하여 평택항을 검색하고 복잡한 조석 그래프를 확인해야 했습니다.
* **시선 분산 및 대응 지연:** 기상 악화나 긴박한 선박 제어 상황에서 브라우저 로딩 대기 시간 및 정보 탐색 딜레이는 관제사의 집중도를 떨어뜨리고 시선 공백을 유발했습니다.

---

## 2. 해결 방안 및 주요 기능 (TO-BE)
* **데스크바 상시 안착(Taskbar Sticky Widget):** 모니터 하단 작업표시줄 위에 완벽하게 이음새 없이(가로 895px, 세로 81px의 극슬림 띠 규격) 항상 위에 고정(Topmost)되어 상시 가시화됩니다.
* **사용자 친화적 다크 모드 UI:** 고대비 및 눈부심 방지를 고려한 심플 다크 블루 테마 디자인으로 설계되어, 야간 관제 시에도 시인성이 뛰어나며 눈의 피로를 최소화합니다.
* **직관적인 조석 데이터 맵:**
  * **저조(저)/고조(고)** 예측 시간과 조위 센티미터(cm) 단위를 미니멀한 그래픽 뱃지로 요약 표출.
  * 일출/일몰과 낮/밤 상황을 시각적으로 빠르게 교차 검증할 수 있는 디스플레이 유닛 제공.
* **드래그 앤 드롭 위치 조정:** 별도의 크기 변경 없이 위젯 전체를 마우스로 자유롭게 드래그하여 원하는 모니터 영역으로 이동할 수 있습니다.
* **위치 상태 자동 저장(State Preservation):** 위젯의 이동 및 마지막 닫힘 좌표를 로컬 환경의 JSON 파일(`TideWidget_pos.json`)에 자동 기록하여, 시스템 재부팅이나 스크립트 재실행 시 기존의 정밀 세팅 위치로 자동 복원됩니다.

---

## 3. 구현 기술 (Tech Stack)
* **OS Environment:** Windows (VTS 외부망 관제 보조 PC)
* **Language/Script:** Windows PowerShell v5.1+ & HTML5/CSS3/JavaScript
* **GUI Engine:** Microsoft Edge WebView2 (`Microsoft.Web.WebView2.WinForms.dll`)
* **OS Interaction & Windowing:**
  * `ReleaseCapture` 및 `SendMessage` Win32 API를 활용한 무테(Borderless) 윈도우 마우스 드래그 오버레이 제어
  * 파일 I/O를 활용한 JSON 기반 좌표 정보 데이터 영속화

---

## 4. 소스 코드 구조 및 설명
`조석표 위젯.ps1`은 PowerShell을 사용해 로컬 윈도우 창의 무테 및 최상단 정합 설정을 진행하며, 웹뷰를 통해 띠 형태의 HTML 위젯을 직접 고속 렌더링합니다.

```powershell
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -Path "C:\webview2\Microsoft.Web.WebView2.WinForms.dll"

# 좌표 저장용 로컬 설정 파일 경로
$ConfigPath = "$env:LOCALAPPDATA\TideWidget_pos.json"

# 마우스 드래그 이동을 윈도우 메시지로 전달하는 Win32 인터페이스 매핑
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

# HTML UI 소스 코드 정의 (Dark Blue 모던 테마 CSS 탑재)
$HtmlContent = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
    html, body {
        margin: 0; padding: 0; overflow: hidden;
        width: 895px; height: 81px;
        display: flex; background: #2b3b4d;
        user-select: none;
    }
    /* 드래그 오버레이 영역을 통해 창 전체 이동 유도 */
    #drag-overlay {
        position: absolute; top: 0; left: 0;
        width: 100%; height: 100%;
        z-index: 9999;
        cursor: move;
    }
...
"@
```

---

## 5. 설치 및 사용 방법

### 사전 필수 설치 요소
* **DLL 경로:** `C:\webview2\Microsoft.Web.WebView2.WinForms.dll`

### 실행 방법
1. **`조석표 위젯.ps1`** 파일을 마우스 우클릭한 후 `PowerShell에서 실행`을 누릅니다.
2. 실행된 슬림 띠 위젯을 마우스로 잡고 **화면 하단 작업표시줄 바로 위**에 드래그하여 알맞게 배치합니다.
3. 실시간으로 수집되는 평택항의 고조/저조 수위와 시간 정보를 확인하며 관제 보조용으로 상시 활용합니다.

---

## 6. 기대 효과 및 도입 성과
1. **관제 지연 요소 완전 제거:** 수동 웹 브라우저 접속으로 낭비되던 평균 **1분 이상의 대기 시간을 0초(상시 표출)로 혁신**했습니다.
2. **관제 집중도 고도화:** 흘수 제약 선박의 위험 구간 통과 시 또는 정밀 접안 관제 시, 시선 분산 없이 한눈에 레이다 화면과 조석 수치를 대조할 수 있어 통제력이 강화되었습니다.
3. **사용자 경험 극대화:** 윈도우 상태 저장 기술 탑재로 VTS 교대 근무자가 매번 위젯 위치를 수동 정렬해야 하는 사소한 작업 공수마저 완벽하게 차단했습니다.

---

## 7. 보안 및 운영 환경 안내 (Security & Operating Environment)

### 1) 완전 폐쇄망 운용 환경 (Closed Network System)
* 본 시스템은 외부 인터넷망과 완벽하게 단절된 **VTS 완전 폐쇄망(Closed-loop Intranet)** 환경에서도 로컬 상태 보존(JSON 좌표 캐싱) 방식을 사용하여 안정적으로 독립 작동합니다. 
* 외부 클라우드망과의 불필요한 데이터 세션 연결이 일절 없어, 외부 유출 및 공격 위협이 원천 차단됩니다.

### 2) 개발 업체/벤더 보안 무관성 (Vendor Security Autonomy)
* 전용 프로그램 패키지나 써드파티 솔루션을 설치하지 않고, 순수 Windows 내장 API와 파워쉘 스크립트만으로 로컬 GUI 윈도우 제어를 수행하므로 **외부 개발 업체 및 장비 유지보수 업체와의 라이선스 갈등이나 시스템 보안 규정 충돌 요소가 전혀 존재하지 않습니다.**

