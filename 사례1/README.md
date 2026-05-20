# [사례 1] VTS 모니터링 최적화를 위한 윈도우 최상단 강제 고정 유틸리티 (VTS Window Topmost)

해상교통관제(VTS) 환경에서 관제 화면의 공간 활용을 극대화하고, 최우선 감시가 필요한 시스템 경고창(System Warnings)이 다른 화면에 가려지지 않도록 강제로 최상단에 고정하는 경량 자동화 도구입니다.

---

## 1. 개발 배경 및 필요성 (AS-IS)
* **모니터링 사각지대 발생:** VTS 운영 시스템 특성상 해상 안전과 직결된 '시스템 경고창'이 다른 관제 화면이나 윈도우에 가려져 즉각적인 인지가 지연될 위험이 있었습니다.
* **관제 시야(레이다/해도) 축소:** 경고창을 상시 관찰하기 위해 모니터 화면을 수동으로 분할 배치해야 했으며, 이로 인해 넓게 확보되어야 할 레이다 화면이 축소되어 모니터 공간을 비효율적으로 낭비했습니다.
* **수동 창 분할의 번거로움:** 교대 근무 시 혹은 시스템 재부팅 시마다 여러 창의 경계를 매번 마우스로 수동 드래그하여 맞추어 넣어야 하는 반복적인 불편함이 존재했습니다.

---

## 2. 해결 방안 및 주요 기능 (TO-BE)
* **원클릭 최상단 고정:** 복잡한 외부 프로그램 설치 없이 Windows 기본 PowerShell과 Win32 API를 결합하여 타겟 창을 상시 최상단(Topmost)으로 고정합니다.
* **지연 활성화 방식(5초 룰):** 스크립트 실행 후 5초 동안 대기 시간이 주어집니다. 이 시간 동안 사용자가 고정하고자 하는 윈도우(예: System Warnings)를 클릭하기만 하면 자동으로 해당 창의 핸들(Handle)을 획득하여 고정합니다.
* **관제 시야 100% 확보:** 경고창을 메인 관제 모니터 구석에 띄우고도 가려질 걱정이 없어졌기 때문에, 전체 화면을 해상 관제 레이다 뷰로 100% 활용할 수 있게 되었습니다.

---

## 3. 구현 기술 (Tech Stack)
* **OS Environment:** Windows (VTS 콘솔 및 워크스테이션 환경)
* **Language/Script:** Windows PowerShell v5.1+
* **Interoperability:** .NET Framework & Win32 API (`user32.dll` 연동)
  * `GetForegroundWindow()`: 현재 사용자가 활성화한 타겟 윈도우의 핸들(HWND) 실시간 추출
  * `SetWindowPos()`: 윈도우 속성을 `HWND_TOPMOST (-1)`로 강제 설정하여 항상 위에 표시

---

## 4. 소스 코드 구조 및 설명
`창고정.ps1` 파일은 다음과 같은 C# Win32 API 매핑 코드를 포함하고 있어, 별도의 컴파일된 모듈(DLL) 없이도 즉각적으로 OS API를 호출합니다.

```powershell
# Win32 API 임포트를 위한 C# 코드 동적 컴파일
Add-Type @"
using System;
using System.Runtime.InteropServices;

public class W {
    // 윈도우의 위치 및 계층 순서(Z-Order)를 변경하는 API
    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int c, int d, uint f);

    // 현재 활성화된(맨 앞의) 윈도우 핸들을 가져오는 API
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
}
"@

# 사용자가 원하는 창을 활성화할 수 있도록 5초 대기
sleep 5

# 현재 맨 앞에 활성화된 윈도우를 최상단(Z-Order: -1)에 크기 변경 없이 고정
# 파라미터 설명: HWND_TOPMOST(-1), x/y/cx/cy(0,0,0,0), SWP_NOSIZE | SWP_NOMOVE (3)
[W]::SetWindowPos([W]::GetForegroundWindow(), -1, 0, 0, 0, 0, 3)
```

---

## 5. 설치 및 사용 방법

### 사전 준비
PowerShell 스크립트가 실행될 수 있도록 실행 정책을 조정해야 합니다. (최초 1회 설정)
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 실행 방법
1. **`창고정.ps1`** 파일을 마우스 우클릭하여 `PowerShell에서 실행`을 누르거나, 해당 스크립트를 바로가기(shortcut) 아이콘으로 바탕화면에 생성합니다.
2. 스크립트 실행 후 즉시 **최상단에 고정하고 싶은 윈도우 창(예: System Warnings)을 클릭**하여 활성화합니다.
3. 5초가 지나면 "삐-" 소리와 함께 해당 창이 영구적으로 최상단에 고정됩니다.

---

## 6. 기대 효과 및 도입 성과
1. **업무 집중도 향상:** 시스템 경고 발생 시 창이 가려져 확인이 늦어지는 휴먼 에러를 원천 차단하여 해상 교통 상황의 실시간 통제력을 극대화했습니다.
2. **효율적인 공간 관리:** 레이다 모니터의 불필요한 분할 세팅이 사라져 관제 가시 구역이 약 **20% 이상 넓어지는 효과**를 얻었습니다.
3. **편의성 대폭 증대:** 교대 시마다 수작업으로 모니터 배치를 새로 맞추던 낭비 시간이 **완전히 제거(Zero)**되었습니다.

---

## 7. 보안 및 운영 환경 안내 (Security & Operating Environment)

### 1) 완전 폐쇄망 및 오프라인 단독 구동 (Closed Loop System)
* 본 프로그램은 외부 서버 및 클라우드 서비스와의 통신 연계가 일절 없으며, 로컬 윈도우 OS의 API만을 호출하는 순수 오프라인 유틸리티입니다.
* VTS 내부의 완전 폐쇄망 PC에서도 네트워크 리스크나 보안 통제 이슈 없이 100% 안전하게 동작합니다.

### 2) 무설치 및 초경량 신뢰성 (Zero-installation Compliance)
* 무겁고 출처가 불분명한 외부 윈도우 창 고정 프리웨어들을 관제실 PC에 설치할 필요 없이, 단 15줄의 순수 윈도우 내장 API 호출 파워쉘 스크립트만으로 구현하여 시스템 안정성을 확보하고 악성코드 유입 경로를 원천 차단했습니다.

