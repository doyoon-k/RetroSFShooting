# RetroSFShooting

Godot Engine으로 제작하는 횡스크롤 2D 슈팅 게임 프로젝트입니다.

## 개발 환경

- Engine: Godot 4.x
- Language: GDScript
- Renderer: Forward+
- Design resolution: 1920 × 1080
- Stretch: Canvas Items / Expand
- Target: Windows and Steam Deck (Windows build via Proton)

## 시작하기

1. Godot 4.x Project Manager에서 `project.godot`을 Import합니다.
2. 프로젝트를 연 뒤 `F6`이 아닌 `F5`로 메인 씬을 실행합니다.
3. 실행 중 `Esc`를 누르면 종료됩니다.

에디터에서는 1280 × 720 창으로 실행되지만 게임의 논리적 설계 기준은
1920 × 1080입니다. 실제 배포 버전에서는 디스플레이 설정 메뉴를 통해
창 모드와 전체 화면 모드를 선택할 수 있도록 구현할 예정입니다.

## 내보내기

`export_presets.cfg`에 Windows 빌드 프리셋을 준비했습니다.

- `Windows Desktop`: `build/windows/RetroSFShooting.exe`

Godot 에디터에서 Export Templates를 설치한 뒤 내보낼 수 있습니다. Steam Deck에서는
동일한 Windows 빌드를 Steam Play(Proton)로 실행합니다.
