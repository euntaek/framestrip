<h4 align="right"><strong><a href="README.md">English</a></strong> | 한국어</h4>

<p align="center">
  <img src="FrameStrip/Assets.xcassets/AppIcon.appiconset/AppIcon-128.png" width="120" />
  <h1 align="center">FrameStrip</h1>
  <div align="center">
    <a href="https://framestrip.com"><img alt="Website" src="https://img.shields.io/badge/framestrip.com-blue?style=flat-square"></a>
    <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-black?style=flat-square">
    <img alt="Swift" src="https://img.shields.io/badge/Swift-black?style=flat-square&logo=swift">
    <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-black?style=flat-square"></a>
  </div>
  <p align="center">UI 모션을 말로 설명하는 대신, AI에게 직접 보여주세요.</p>
  <p align="center"><strong>영역 선택</strong> → <strong>녹화</strong> → <strong>AI에 붙여넣기</strong></p>
</p>

<p align="center">
  <img src="https://assets.framestrip.com/demo.gif" alt="FrameStrip 데모" width="600" />
</p>

## 왜 만들었나

단순한 애니메이션은 말로 설명하면 됩니다 — "200ms ease-out으로 왼쪽에서 슬라이드"라고 하면 AI가 잘 만들어줍니다. 하지만 실제 UI 모션은 말로 설명하기 어려운 경우가 많습니다. 페이지 로딩 시 여러 요소가 각각 다른 타이밍과 애니메이션으로 나타나는 것, 여러 단계에 걸친 인터랙션, 어딘가에서 본 건데 뭐라고 설명해야 할지 모르는 모션 같은 것들.

설명하려고 애쓰는 대신, 그냥 보여주세요. FrameStrip은 애니메이션을 프레임 시퀀스로 캡처해서 AI에 바로 붙여넣을 수 있게 합니다.

**FrameStrip 없이:**
1. QuickTime/OBS로 화면 녹화
2. ffmpeg 설치
3. ffmpeg 명령어로 프레임 추출
4. AI에 이미지 수동 첨부

**FrameStrip 사용:**
1. 영역 선택
2. 녹화
3. 끝 — AI에 프레임을 붙여넣기

## 주요 기능

**캡처**
- **영역 캡처** — 전체 화면이 아닌 원하는 컴포넌트만 캡처
- **다중 모니터** — 연결된 모든 디스플레이에서 영역 선택 및 이동
- **간격 조절** — 0.1초~10초 단위로 설정 가능
- **변화 감지** — 동일한 프레임 자동 스킵
- **자동 중지** — 프레임 수 또는 시간 제한으로 자동 녹화 중지

**인터랙션 추적**
- **인터랙션 캡처** — 마우스 클릭/드래그 순간 자동 프레임 저장 + 이벤트 메타데이터(좌표, 버튼, modifier)를 `session.json`에 기록
- **커서 표시** — 캡처 프레임에 마우스 커서 포함 옵션

**출력**
- **AI 프롬프트 생성** — 커스터마이즈 가능한 프롬프트 원클릭 복사 (캡처 메타데이터 포함)
- **이미지 포맷** — PNG 또는 JPEG (품질 조절 가능)

**워크플로우**
- **글로벌 단축키** — 어디서든 녹화 시작 또는 컨트롤 패널 표시 (기본: Option+Shift+5, 변경 가능)
- **실시간 프리뷰** — 녹화 중 메뉴바에서 캡처된 프레임 확인
- **한국어 / English** — 시스템 언어 감지 포함 완전 다국어 지원
- **가벼움** — 메뉴바 상주, ffmpeg 등 외부 도구 불필요

## 설치

### 다운로드

[GitHub Releases](https://github.com/euntaek/framestrip/releases)에서 최신 `.dmg`를 다운로드하세요.

`.dmg`를 열고 FrameStrip을 Applications로 드래그하세요. 첫 실행 시 macOS가 화면 녹화 권한을 요청합니다.

### 소스에서 빌드

Xcode 15+와 macOS 14+ (Sonoma)가 필요합니다.

```bash
git clone https://github.com/euntaek/framestrip.git
cd framestrip
cp Config/Signing.local.example.xcconfig Config/Signing.local.xcconfig
# Config/Signing.local.xcconfig에서 Apple Developer Team ID를 설정하세요
xcodebuild -project FrameStrip.xcodeproj -scheme FrameStrip -configuration Release build
```

빌드된 앱은 `DerivedData/Build/Products/Release/`에 있습니다.

## 사용법

### 기본 워크플로우

1. 메뉴바의 FrameStrip 아이콘 클릭
2. **"영역 선택 & 녹화 시작"** 선택
3. 애니메이션이 있는 영역을 드래그로 선택
4. 필요 시 영역 조절 (리사이즈 핸들, 드래그로 이동)
5. 컨트롤 패널에서 캡처 간격과 옵션 설정
6. **Record** 클릭 (또는 Enter)
7. 애니메이션이 끝나면 **Stop** 클릭
8. 완료 패널에서 **프롬프트 복사** 클릭
9. Claude Code, Codex 등 AI에 붙여넣기

### 예제 프롬프트

아래 프롬프트는 FrameStrip이 자동 생성하여 클립보드에 복사해줍니다. 캡처한 프레임과 함께 AI에 붙여넣기만 하면 됩니다.

```
<ui-motion-reference>
  <source-material>
  Analyze the frame sequence in @"~/framestrip/framestrip_20260407_143022".
  Treat the saved images as the primary source of visual truth for layout, appearance, visible state, and motion.
  Use @"~/framestrip/framestrip_20260407_143022/session.json" as the authoritative source for timing, capture settings, frame segments, and recorded interaction events.
  Read the `_legend` field in session.json for field descriptions.
  </source-material>

  <analysis-rules>
  Analyze the sequence as time-based motion, not just as a set of static keyframes.
  Pay attention to both macro motion and micro-motion across consecutive frames.

  Explicitly inspect:
  - layout, geometry, spacing, and layering
  - timing, pacing, delays, and easing
  - interaction-triggered state changes
  - persistent ambient motion while the overall composition appears stable
  - per-element changes in opacity, brightness, color, blur, scale, position, distortion, or phase

  If `settings.interactionCapture` is `true`, use recorded interaction events only to infer user intent and trigger UI state changes.
  If `settings.interactionCapture` is `false`, do not assume pointer or keyboard events beyond what is visually evident in the frames.

  When a behavior is uncertain because of capture interval, missing frames, compression, or ambiguity, state that uncertainty explicitly.
  Do not present inference as direct observation.
  </analysis-rules>

  <output-boundaries>
  Reproduce or describe the product UI behavior, not the capture artifact itself.
  Do not recreate a synthetic mouse cursor, click indicator, drag overlay, capture flash, or recording artifact unless it is clearly part of the actual product UI.

  Preserve meaningful ongoing motion even when the screen appears visually stable.
  Do not treat shimmer, flicker, pulsing, twinkling, breathing, or similar subtle motion as decorative noise if it is visible in the frames.
  </output-boundaries>
</ui-motion-reference>

이 애니메이션을 HTML 단일 파일로 구현해줘.
```

마지막에 원하는 지시를 추가하세요. 예시:

- `이 애니메이션을 HTML 단일 파일로 구현해줘.`
- `이 페이지 전환을 React에서 Framer Motion으로 구현해줘.`
- `이 로딩 애니메이션을 SwiftUI spring 타이밍으로 재현해줘.`
- `이 버튼 hover 트랜지션을 CSS transitions로 구현해줘.`
- `구현 방법을 제안하기 전에 이 모션을 상세하게 분석해줘.`
- `이런 애니메이션을 뭐라고 해? 통용되는 이름과 자주 쓰이는 용도를 알려줘.`

### 설정

설정은 사이드바 레이아웃으로 구성되어 있습니다 (캡처 / 일반 / 프롬프트 / 정보):

- **캡처** — 간격, 이미지 포맷, 변화 감지, 자동 중지 제한
- **일반** — 언어 (한국어/영어), 저장 폴더, 단축키
- **프롬프트** — 변수 칩으로 AI 프롬프트 템플릿 커스터마이즈
- **정보** — 버전, 라이선스, 링크

### 단축키

기본: `Option + Shift + 5` — 영역 선택을 시작하거나 녹화 중 컨트롤 패널을 표시합니다. 설정에서 변경 가능.

## 알려진 제한사항

- **고속 캡처 시 프레임 타이밍이 보장되지 않습니다.** 빠른 간격(0.5초 미만)에서 넓은 영역(예: 4K 전체 화면)을 캡처하면 저장 파이프라인이 속도를 따라가지 못해 일부 프레임이 드롭될 수 있습니다. Mac의 CPU와 디스크 속도에 따라 다릅니다. PNG는 JPEG보다 인코딩이 느리므로, 고속 캡처 시 JPEG 포맷을 사용하거나 캡처 영역을 줄이세요. 완료 패널의 프레임 수는 실제 저장된 프레임 기준입니다.

## 요구사항

- macOS 14+ (Sonoma)
- 화면 녹화 권한

## 라이선스

[MIT](LICENSE) — Euntaek Kim
