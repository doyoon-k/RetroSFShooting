# RetroSFShooting — LAST ARK

Godot 4.7 기반의 2D 횡스크롤 슈팅 프로토타입입니다. 여섯 파일럿이 생명을 공유하고,
생존자 조합에 따라 여섯 엔딩으로 분기합니다. 그래픽·이름·대사·스토리는 교체 가능한
샘플 콘텐츠이며, 현재 한 스테이지의 전체 게임 흐름이 연결되어 있습니다.

## 실행

1. Godot에서 `project.godot`을 Import하고 **F5**를 누릅니다.
2. `NEW GAME` → 스토리 → 파일럿 선택 → `SORTIE`로 출격합니다.
3. 스테이지만 시험하려면 `scenes/gameplay/stage/stage_01.tscn`을 열고 **F6**를 누릅니다.

Godot 4.7.2 / GDScript / Forward+를 기준으로 검증합니다. 설계 해상도는 1920×1080,
기본 실행 창은 1280×720입니다. 화면 비율은 Keep으로 고정하여 16:10 등에서도
전투 영역과 난이도가 바뀌지 않도록 합니다.

| 행동 | 키보드 | 게임패드 |
|---|---|---|
| 이동 | WASD / 방향키 | 왼쪽 스틱 |
| 선택한 무기 발사 | J 누르기 | X 누르기 |
| 폭탄 | K | B |
| 무기 변경 | H | Y |
| 일시정지 / 재개 | ESC | Start |
| 메뉴 이동 / 선택 | 방향키·WASD / Enter | D-pad / A |
| 스토리 완성 / 다음 페이지 | Space | A |

선택 화면에서는 파일럿을 고른 뒤 출격 버튼을 누릅니다. 사망 후에는 우측 초상화를
클릭하거나 포커스를 이동해 Enter/A로 즉시 출격할 수 있습니다. 5초가 지나면 현재
강조된 생존 파일럿이 출격합니다. 게임 종료는 Title의 EXIT를 사용합니다.

## 구현된 흐름

- Title → Intro → Character Select → Stage → Ending → Result → Title
- HP 2, 피격 무적, 출격 무적, 직선형·3갈래 방사형 무기, 무기별 LV1~3 강화, 폭탄
- 6명의 파일럿, 파괴·콕핏 연출, 생존자 표정, 5초 선택, 강화 아이템 회수
- Power Up / Bomb / Shield, 약한 유도 이동, 경계 반사, 수명
- Power Up은 현재 선택한 무기를 강화합니다. 무기를 바꾸어도 각각의 강화 레벨은 유지됩니다.
- 두 무기 모두 탄환이 160px 이내에서 맞으면 피해 2배, 640px 이상에서는 기본 피해를 줍니다. 그 사이에서는 발사 위치부터 맞은 지점까지의 거리에 따라 배율이 선형으로 줄어듭니다. 거리·배율 단계는 `Weapon` 노드의 배열에서 추가하거나 제거할 수 있습니다.
- 자동 전진하는 긴 스테이지에 배치된 일반 적 45기와 위치 기반 2단계 보스
- 조준·부채꼴·연사·원형·회전·유도탄 공격 프리셋
- 경로·직선·물결·진입/정지/퇴장 이동
- 사망·교대·일시정지 중 전투와 아이템 수명 정지
- 모든 생존 조합의 엔딩 분기, 컬렉션, 영구 저장

저장 위치는 `user://endings.cfg`입니다. Windows 기본 위치는
`%APPDATA%/Godot/app_userdata/RetroSFShooting/endings.cfg`이며, 테스트는 별도 임시
파일을 사용하므로 플레이 기록을 변경하지 않습니다.

## 콘텐츠 편집

실제 수치와 에셋 연결은 `.tres`와 `.tscn`에 있습니다. 별도 생성기 실행 없이 Godot에서
수정·저장하면 적용됩니다.

- [에디터 작업 가이드](EDITOR_GUIDE.md): 적 직접 배치, 편대 마커, 보스 위치, 경로·에셋 편집
- [구조와 진행 규칙](docs/ARCHITECTURE.md): 상태 소유권, 시그널, 일시정지, 사망/클리어 우선순위
- `data/game_catalog.tres`: 파일럿·인트로·엔딩·공통 규칙의 시작점
- `data/rules/default.tres`: HP, 폭탄, 무적, 교대·연출 시간, 전투 영역
- `data/patterns/`: 공격 패턴과 보스/일반 적의 발사 단계

현재 일러스트·초상화·격납고 Idle·폭발은 기능 확인을 위한 샘플입니다. 원화·최종
애니메이션·사운드 제작, 본격적인 난이도 조정은 이 구조 위에서 진행할 수 있습니다.
Pause 랜덤 말풍선, 최고 점수, 여러 스테이지와 중간 저장은 현재 범위에 포함하지 않습니다.

## 검증

Python 표준 라이브러리만 사용하는 실행 도우미입니다.

```powershell
python tools/check.py
python tools/check.py --godot "C:/path/to/Godot.exe"
python tools/check.py --screenshots
```

첫 명령은 Godot import와 headless 통합 검사를 실행합니다. 마지막 명령은 실제 렌더링을
사용하며 화면 캡처를 `build/screenshots/`에 저장합니다. 로그는 `build/validation/`에
저장됩니다. 테스트 실패뿐 아니라 Godot의 스크립트 오류·엔진 오류·경고도 실패로 처리합니다.

Python 없이 검사하려면 import 후 아래 명령을 실행합니다.

```powershell
godot --headless --path . --editor --import
godot --headless --path . --script tests/run_tests.gd --fixed-fps 60
```

## 내보내기

기존 `export_presets.cfg`의 Windows Desktop 프리셋을 사용할 수 있습니다.
해당 Godot 버전의 Export Templates를 설치한 뒤 `build/windows/RetroSFShooting.exe`로
내보냅니다. Steam Deck은 Windows 빌드를 Proton으로 실행하는 대상이며, 실제 장치에서의
성능·컨트롤러 호환성 검증은 별도로 필요합니다.

폰트는 SIL OFL로 배포되는 Noto Sans KR입니다. 라이선스는 `assets/fonts/OFL.txt`에 있습니다.
샘플 SVG와 기체 도형은 이 프로젝트를 위해 작성했습니다.
