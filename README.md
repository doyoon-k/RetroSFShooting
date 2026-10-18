# RetroSFShooting

Godot 4.7 기반의 2D 횡스크롤 슈팅 프로토타입입니다. 여섯 파일럿이 생명을 공유하고,
생존자 조합에 따라 여섯 엔딩으로 분기합니다. 제공된 PNG를 사용하며, 대사와 소개는
“대사 1”, “대사 2” 형식으로 비워 두었습니다. 한 스테이지의 전체 게임 흐름이 연결되어 있습니다.

## 실행

1. Godot에서 `project.godot`을 Import하고 **F5**를 누릅니다.
2. 시작 안내에서 버튼을 눌러 메뉴를 열고 `NEW GAME` → 스토리 → 파일럿 선택 → `SORTIE`로 출격합니다.
3. 스테이지만 시험하려면 `scenes/gameplay/stage/stage_01.tscn`을 열고 **F6**를 누릅니다.
4. 적의 이동·공격 조합은 `scenes/gameplay/enemy_lab/enemy_lab.tscn`을 열고 **F6**로 시험합니다.

Godot 4.7.2 / GDScript / Forward+를 기준으로 검증합니다. 설계 해상도는 1920×1080,
기본 실행 창은 1280×720입니다. 화면 비율은 Keep으로 고정하여 16:10 등에서도
전투 영역과 난이도가 바뀌지 않도록 합니다.

| 행동 | 키보드 | 게임패드 |
|---|---|---|
| 이동 | WASD / 방향키 | 왼쪽 스틱 |
| 무기 변경 | J | Y |
| 선택한 무기 발사 | K 누르기 | X 누르기 |
| 폭탄 | L | B |
| 일시정지 / 재개 | ESC | Start |
| 메뉴 이동 / 선택 | 방향키·WASD / Enter | D-pad / A |
| 스토리 완성 / 다음 페이지 | Space | A |

타이틀은 원본 스프라이트의 `PRESS ANY BUTTON` 안내에서 시작합니다. 키보드·마우스·게임패드 버튼의
첫 입력으로 `NEW GAME / ENDINGS / EXIT` 메뉴를 열고, 다음 입력으로 메뉴를 선택합니다.
시작 입력을 길게 누르거나 클릭해도 바로 새 게임이 실행되지 않습니다.

선택 화면에서는 하단 실루엣을 클릭하거나 방향키·WASD/D-pad로 이동한 뒤 Enter/A로
정보창을 엽니다. 정보창의 출격 버튼 또는 Enter/A로 출격하며 Esc/B와 X 버튼으로 닫습니다.
정보창이 열린 상태에서도 좌우 이동으로 다른 파일럿의 정보를 볼 수 있습니다. 사망 후에는 좌측 초상화를
클릭하거나 포커스를 이동해 Enter/A로 즉시 출격할 수 있습니다. 5초가 지나면 현재
강조된 생존 파일럿이 출격합니다. 게임 종료는 Title의 EXIT를 사용합니다.

## 구현된 흐름

- Title → Intro → Character Select → Stage → Ending → Result → Title
- 오프닝 9컷과 AI·2~4명·5~6명 생존 엔딩 각 4컷을 원본 PNG 순서로 표시하는 전체 화면 컷신·하단 자막
- HP 2, 피격 무적, 출격 무적, 직선형·3갈래 방사형 무기, 공유 LV1~3 강화, 폭탄 2개 시작·최대 4개 보유
- 폭탄은 입력 시 소모하고 0.2초 뒤 발동하며, 입력 시점부터 1.5초 재사용 대기를 적용합니다. 발동 시 탄 소거·피해·1초 무적을 부여합니다.
- 6명의 파일럿, 파괴·콕핏 연출, 생존자 표정, 5초 선택, 강화·폭탄 아이템 회수
- Power Up / Bomb / Shield, 약한 유도 이동, 경계 반사, 수명
- Power Up은 두 무기를 동시에 강화합니다. 실드가 없는 상태에서 피격되면 두 무기의 레벨이 함께 1단계 내려갑니다.
- 파일럿 사망 시 피격 전 보유량에서 각각 1개를 뺀 Power Up과 폭탄이 맵에 흩어집니다. Power Up 보유량은 강화 레벨 - 1이며, 각 보유량이 0~1개면 해당 아이템은 남기지 않습니다.
- 직선형은 LV1/2/3에서 나란히 2/3/4발, 방사형은 같은 각도 범위에 3/5/7발을 쏩니다. 레벨별 발사 간격과 탄당 피해는 일정합니다.
- 두 무기 모두 탄환이 80px 이내에서 맞으면 피해 1.6배, 360px 이상에서는 기본 피해를 줍니다. 그 사이에서는 발사 위치부터 맞은 지점까지의 거리에 따라 배율이 선형으로 줄어듭니다. 거리·배율 단계는 `Weapon` 노드의 배열에서 추가하거나 제거할 수 있습니다.
- 한 스테이지에 자코 5종, 노멀 5종, 미들 3종 총 300기와 위치 기반 2단계 보스. 미들 교전 중에는 전진이 멈춥니다.
- 조준·재조준 연사·중앙 통로·회전 부채꼴·원형·유도탄·쌍익 교차 사격·이동 통로 탄벽·부화 분열탄·삼단 도약탄 공격 프리셋
- 경로·직선·물결·진입/정지/퇴장·세로 왕복·스크롤을 따라가는 이동 포대
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

파일럿 초상화, 플레이어와 양측 탄환, 적 외형과 피격·사망 이펙트는
`assets/Pilots_sprites/`의 제공된 PNG를 사용합니다. 보스는 기존 `Enemy/L1.png`를
재사용합니다. AI가 작성한 SVG와 별 배경·장식 테마·격납고 임시 애니메이션은 제거했습니다.
메뉴는 Godot 기본 컨트롤을 사용하며, `scenes/ui/game_theme.tres`에서 글꼴을 관리합니다.
한글 메뉴·버튼은 SB 어그로 Medium, 큰 한글 강조 문구는 Bold, 영문 메뉴·HUD·숫자는
Stadium을 사용합니다. 대사·설명·엔딩 기록은 Noto Sans KR을 유지합니다.
`ArcadeLabel`/`ArcadeButton`, `EmphasisLabel`, `BodyLabel` 테마 변형으로 용도를 지정하며,
Stadium에 없는 문자는 SB 어그로 Medium과 Noto Sans KR로 대체합니다.
타이틀은 원본 우주 배경·로고·초록색 기체와 `TitleBG1~3`의 파일럿 군상을 사용합니다.
영상 레퍼런스의 정상·밝은 노이즈·해골 전환을 반복하며 기체는 작게 위아래로 움직입니다.
시작 안내 뒤의 세 메뉴와 엔딩 컬렉션은 마우스·키보드·게임패드로 사용할 수 있습니다.
파일럿 선택 화면은 원본 격납고 배경·전체 화면 프레임·제목·6명 실루엣·선택 삼각형과
초상화 정보창으로 구성합니다. `SixPilot.png`는 AtlasTexture로 나눠 파일럿별로 선택하며,
정보창에는 기존 초상화와 PilotData의 이름·소개를 표시합니다.
전투 화면은 왼쪽 2×3 파일럿 슬롯과 확대 초상화, 오른쪽 전투 창, 하단 폭탄·무기 콘솔로
구성됩니다. 출격 슬롯과 콘솔에는 `assets/Pilots_sprites/UI/`의 원본 PNG를 사용합니다.
폭탄·무기 변경·일시정지는 콘솔 클릭으로도 사용할 수 있습니다. 전투 배경과 원본 그림이
없는 전멸·1명 생존 엔딩은 비어 있습니다. 아이템은 P/B/S, 실드 상태는 S로 표시합니다.
Pause 랜덤 말풍선, 최고 점수, 여러 스테이지와 중간 저장은 현재 범위에 포함하지 않습니다.

## 검증

Python 표준 라이브러리만 사용하는 실행 도우미입니다.

```powershell
python tools/check.py
python tools/check.py --godot "C:/path/to/Godot.exe"
python tools/check.py --screenshots
python tools/siege_cycles.py
python tools/ricochet_pressure.py
```

첫 명령은 Godot import와 headless 통합 검사를 실행합니다. 마지막 명령은 실제 렌더링을
사용하며 화면 캡처를 `build/screenshots/`에 저장합니다. 로그는 `build/validation/`에
저장됩니다. 테스트 실패뿐 아니라 Godot의 스크립트 오류·엔진 오류·경고도 실패로 처리합니다.

`siege_cycles.py`는 M1의 유인탄→교차탄→시간차 분열 순환, 2초 반격 시간과 실제 P2 이동
회피를 검사합니다. 사격·폭탄·무적을 사용하지 않는 단독 교전 검사입니다.
`check.py`의 삼단 도약탄 검사는 위/아래 반사 경로, 7·9·11발, 예고 시 조준 확정, 소거·피격 취소,
일시정지, 잔탄 소멸 뒤 1초 반격과 M2 연결을 확인합니다. M1/최종 보스의 잘못된 연결은 제거했습니다.
`--screenshots`는 M2의 세 반사점 화면도 저장합니다. `ricochet_pressure.py`는 초기/강화판의 정지
접촉 압박과 P2의 실제 이동 경로를 비교하며, 인간의 체감 난이도를 대신하지 않습니다.

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

### 스테이지 밸런스

[전체 스테이지 설계·조사 자료·속도표](docs/STAGE_DESIGN.md). 이동 156초, 미들 3회, 보스 2단계로 구성됩니다. 정상 속도 계측은 `tests/stage_balance_probe.gd`에서 실행하며, 무적 봇의 측정은 사람의 재미·생존 난이도 검증과 구분합니다.

레벨 밸런스 회귀 검사는 `python tools/balance.py`로 실행합니다. 무적 화력 계측 2종과 실제 피해를 받는 반응 봇 4종을 구분하며, `--screenshots`로 주요 교전 화면을 저장합니다. 인간의 재미·가독성 검증을 대체하지 않습니다.

보스 패턴의 정지 안전지대 표본 검사까지 실행하려면 `python tools/balance.py --boss-patterns`를 사용합니다.

근접 화력의 이전/현재 곡선을 실제 충돌로 비교하려면 `python tools/weapon_pressure.py
python tools/durability.py`를 실행합니다. 첫 미들 전의 일반 강화 공급은 7초 한 번이며, 17초 추가 공급은 제거했습니다.
