# 에디터 작업 가이드

게임 설정은 Resource, 배치와 시각 구성은 Scene에서 수정합니다. 실행 중 Remote 탭에서
바꾼 값은 제작 파일에 저장되지 않으므로 콘텐츠 작업은 Local/Inspector에서 진행하세요.

## 시작 위치

| 작업 | 파일 / 노드 |
|---|---|
| 공통 규칙 | `data/rules/default.tres` |
| 전체 파일럿·엔딩 목록 | `data/game_catalog.tres` |
| 파일럿 이름·소개·표정·대사 | `data/pilots/*.tres` |
| 기체 이동속도·색·시각 크기 | `scenes/player/*_ship.tscn`의 루트 |
| 기체 피격 범위 | 기본 `player_ship.tscn`의 CollisionShape2D |
| 직선형 공격 LV1~3 | `data/weapons/standard.tres` |
| 3갈래 방사형 공격 LV1~3 | `data/weapons/spread.tres` |
| 직선형 탄환 이미지 | `scenes/projectiles/player_bullet.tscn`의 `Visual` |
| 방사형 탄환 이미지 | `scenes/projectiles/radial_bullet.tscn`의 `Visual` |
| 적 탄환 이미지 | `scenes/projectiles/*_bullet.tscn`, `brood_core.tscn`의 `Visual` |
| 적의 피 튀는 효과 | `scenes/gameplay/enemy_hit.tscn` 루트의 `Size Ratio`, `Size Growth`, `Max Scale`, `Front Inset` |
| 근접 사격 배율·거리 | `scenes/player/player_ship.tscn`의 `Weapon` 노드 |
| 적 성능 | `scenes/enemies/*.tscn` |
| 공격 패턴 | `data/patterns/*.tres` |
| 스테이지 배치와 이동 속도 | `scenes/gameplay/stage/stage_01.tscn` |
| 아이템 성능 | `scenes/items/*.tscn` |
| 아이템 그림·크기 | `scenes/items/*.tscn`의 `Visual` |
| 파워업 획득 메시지 | `scenes/ui/power_up_message.tscn` 루트 |
| 일러스트·본문·타이핑 속도 | `data/stories/*.tres` |
| 메뉴·HUD 글꼴 | `scenes/ui/game_theme.tres` |
| 타이틀 배경·로고·시작 안내·메뉴 배치 | `scenes/title/title.tscn`의 Layout |
| 타이틀 녹색 캐릭터·해골 깜빡임 | `scenes/title/title_crew.tscn`의 AnimationPlayer |
| 파일럿 선택 배경·실루엣·정보창 배치 | `scenes/character_select/character_select.tscn`의 Layout |
| 전투 프레임·파일럿 슬롯 배치 | `stage_01.tscn`의 Interface / Root |
| 전투 하단 콘솔·확대 초상화 | `scenes/ui/combat_hud.tscn` |
| 키보드·게임패드 | Project Settings → Input Map |

전투 기체는 기본 `player_ship.tscn` 루트의 Scale이 1.5이며, 모든 적 씬의 루트 Scale은
3입니다. 이미지·충돌 영역·발사 위치가 함께 확대됩니다. 적 탄환의 루트 Scale은 2.4,
플레이어 탄환은 1.8입니다(2배 확대 후 현재 크기에서 10% 축소).
적 크기는 확대 전 대비 1.5배, 적 탄환은 2배, 플레이어 탄환은 1.8배이며,
충돌 판정도 같은 비율로 확대됩니다. `lance_bullet.tscn`과 `siege_bullet.tscn`은
`enemy_bullet.tscn`의 Scale을 상속합니다. 에디터에서는 각 씬의 루트 노드 →
Inspector → Transform → Scale에서 크기를 조절합니다. 플레이어의 이동 영역은
`data/rules/default.tres`의 Playfield이며 전투 프레임 안쪽 `(440, 24)`부터
`(1904, 976)`까지입니다. `PlayerShip`의 Boundary Padding은 투명 여백을 제외한
기체 반크기이며 Scale에 맞춰 적용됩니다. 이동 경계는 하나의 직사각형입니다.
좌하단 프레임이나 하단 콘솔과 겹쳐도 기체 위치를 밀어내거나 추가로 제한하지 않습니다.

아이템은 `assets/Pilots_sprites/Item/`의 P·B·실드 이미지를 사용합니다. 투명 여백을
AtlasTexture로 제외하고 실제 그림의 최대 길이를 약 68~69px로 맞췄습니다.
크기는 각 아이템 씬의 `Visual > Transform > Scale`에서 바꿉니다.
실제로 무기 레벨이 오른 경우에만 `PowerUp.png` 획득 메시지가 나타납니다.
최대 레벨의 파워업, 폭탄, 실드에는 별도 획득 메시지가 없습니다.
`power_up_message.tscn` 루트의 Duration(기본 0.8초), Rise Distance, Ship Offset,
Display Width로 연출을 조절합니다. 같은 메시지를 갱신하므로 연속 획득 시 겹치지 않으며,
화면 가장자리에서는 전투 영역 안으로 배치합니다. 일시정지 중에는 연출도 멈춥니다.
기체 위 실드 상태도 같은 실드 이미지로 표시합니다.

모든 적 탄환은 `assets/Pilots_sprites/Projectile/`의 PNG를 Sprite2D로 표시합니다.
`Projectile_A.png`는 일반탄·굵은 탄·탄벽·부화탄, B는 유도탄, C는 고속탄에 연결되어 있습니다.
에셋 교체는 `Visual > Texture`, 외형만의 크기는 `Visual > Transform > Scale`에서 조절합니다.
각 에셋의 비율을 유지하면서 기존 외형의 최대 길이에 맞췄으며, 루트 Scale과 충돌 판정은 유지합니다.
부화탄은 정지 후 깜빡이며 B 스프라이트로 후속 발사 방향을 예고합니다.
움직이는 탄벽도 스프라이트가 깜빡입니다.

적의 피 튀는 효과는 `Visual`의 실제 외형 크기에 따라 완만하게 확대됩니다.
스프라이트의 투명 여백은 제외하며, 루트와 Visual의 Scale을 모두 반영합니다.
큰 적은 크기 비율의 제곱근을 적용하고 기본 Scale 상한을 2.25로 제한합니다.
첫 프레임의 피가 적 외형의 왼쪽 앞부분에서 시작해 플레이어 쪽으로 퍼지도록 이미지 원점을 보정합니다.
시작 위치는 외형의 왼쪽 경계에서 폭의 12%만큼 안쪽이며, 회전은 +90°로 유지합니다.
`enemy_hit.tscn` 루트에서 다음 값을 조절할 수 있습니다.

| 속성 | 의미 |
|---|---|
| Size Ratio | 전체 효과 크기 배율(기본 1), 상한 적용 후 곱함 |
| Size Growth | 큰 적에서 크기가 증가하는 정도(기본 0.5, 1이면 정비례) |
| Max Scale | 자동 확대 Scale 상한(기본 2.25) |
| Front Inset | 왼쪽 앞 경계에서 시작점을 안쪽으로 옮기는 폭 비율(기본 0.12, 0.5이면 중앙) |

## 새 적 공격 만들기

1. `data/patterns/fan.tres`를 복제하고 이름을 바꿉니다.
2. Inspector에서 `AttackPattern`의 값을 수정합니다.
3. `fan_step.tres`도 복제하고 `Pattern`에 새 패턴을 연결합니다.
4. 적 씬의 `Shooter` 노드 → `Steps`에 새 `PatternStep`을 넣습니다.
5. Stage의 `PlacedEnemies`에 적 씬을 배치하거나 `WaveSequence` 마커의 Enemy Scene에 연결합니다.

새 Resource를 처음부터 만들려면 FileSystem의 New Resource에서 `AttackPattern`,
`PatternStep`을 선택할 수 있습니다. 노드의 경고 아이콘은 누락된 패턴·탄환 연결을 알려줍니다.

| AttackPattern 속성 | 의미 |
|---|---|
| Projectile Scene | 발사할 탄환 씬 |
| Aim: Fixed | Angle Degrees 방향으로 발사. 오른쪽 0°, 아래 90°, 왼쪽 180° |
| Aim: Lock On Start | 한 패턴의 연사가 시작될 때만 플레이어를 조준 |
| Aim: Track Each Volley | 연사 중 매 발사 묶음마다 플레이어를 다시 조준 |
| Aim Offset Degrees | 조준 방향에 더할 각도. 조준 공격의 기본값은 0° |
| Shape: Fan | 중심 방향을 기준으로 부채꼴 배치. 한 발이면 직선탄 |
| Shape: Ring | 360° 균등 배치. 시작/끝 탄환이 중복되지 않음 |
| Bullet Count | 한 발사 묶음의 탄 수 |
| Spread Degrees | 부채꼴 전체 폭 |
| Volley Count / Interval | 연속 발사 묶음 수 / 묶음 사이 시간 |
| Rotation Per Volley | 발사 묶음마다 추가되는 회전각 |
| Recovery | 이 패턴 한 번이 끝난 뒤 쉬는 시간 |

`PatternStep.Repetitions`는 해당 패턴을 몇 번 반복할지, `Wait After`는 그 단계가 끝난 뒤
추가로 쉬는 시간입니다. 마지막 단계가 끝나면 첫 단계로 돌아갑니다.

탄속·수명·피해·유도 회전속도·모양은 연결된 탄환 씬에서 바꿉니다. 플레이어 탄환 피해는
예외적으로 WeaponData의 각 레벨 설정을 사용합니다. `standard.tres`와 `spread.tres`의
`Levels` 배열은 각각 독립적이며, 각 레벨의 `Angles`, `Interval`, `Damage`를 편집할 수
있습니다. 직선형은 `Angles`의 0° 탄환 수에 따라 자동으로 세로 간격을 두고
2/3/4발을 쏩니다. 간격은 기본 `player_ship.tscn`의 `Weapon` 노드 → `Shot Pattern`
→ `Straight Shot Spacing`에서 조절합니다. 방사형은 같은 부채꼴 안의 `Angles`를 늘려
3/5/7발을 쏩니다. 두 무기는 하나의 강화 레벨을 공유하므로 Power Up이나 실드 없는 피격이 두 패턴에 함께 적용됩니다.
사망 시 회수 아이템은 `stage_01.tscn`의 `Recovery Pickup`과 `Recovery Bomb`에 연결된 씬으로 생성됩니다.
폭탄·레벨업 아이템은 카메라 전진을 따라가면서 전투 영역의 네 가장자리에서 반사됩니다.
아이템 씬의 `Initial Velocity`는 화면 기준 이동 방향·속도이며, `Boundary Padding`은
경계에서 아이템이 잘리지 않게 남기는 여백입니다. `Attraction`은 플레이어 쪽으로
방향을 서서히 틀어주는 정도입니다.

폭탄 시간은 `data/rules/default.tres`의 `Bomb` 그룹에서 조절합니다. `Bomb Activation Delay`는 입력부터 폭발까지의 시간(0.2초), `Bomb Cooldown`은 입력부터 다음 사용까지의 시간(1.5초), `Bomb Invincibility`는 폭발 후 무적 시간(1초)입니다.

`Weapon` 노드의 `Proximity Damage > Proximity Tiers` 배열에서 거리(px)와 배율을
한 쌍씩 추가·제거합니다. 배열 순서와 상관없이 거리순으로 적용되며, 단계 사이에서는
발사 위치에서 충돌 지점까지의 거리에 따라 배율이 선형으로 변합니다. 가장 가까운
단계 안쪽은 그 단계의 배율, 가장 먼 단계 바깥쪽은 기본 피해 1배입니다.
기본 설정은 80px 이내 1.6배, 360px 이상 1배입니다. 배열이 비어 있으면 항상 1배이며,
단계가 하나면 해당 거리 안쪽에만 그 배율을 적용합니다. 소수 피해도 적 체력에 누적됩니다.

**공유 리소스에 주의:** 같은 `.tres`를 참조하는 모든 적에게 수정이 적용됩니다. 특정 적만
바꾸려면 그 리소스를 복제해 연결하세요. 중첩된 Step 안의 Pattern까지 독립시키려면 Pattern도
복제해야 합니다. 실행 중 타이머와 조준 상태는 EnemyShooter별로 독립되어 있습니다.

## 편대별 이동·공격 실험

`scenes/gameplay/enemy_lab/enemy_lab.tscn`을 열고 **F6**을 누르면 시험 장면이 실행됩니다.
오른쪽에서 적 씬, 이동 프리셋, 공격 순서, 플레이어 강화 레벨을 고르고 `Spawn / Retry`를
누르세요. `Use sample Path2D`를 켜면 같은 적을 곡선 경로로 시험할 수 있습니다. WASD로
이동하고 J로 공격합니다. 적이 화면 밖으로 나가거나 격추되면 자동으로 다시 등장하며,
`Clear`를 누르면 자동 등장이 멈춥니다. 시험 장면의 Inspector에서 Enemy Scenes, Movement Presets,
Attack Presets 배열에 새 파일을 넣으면 선택지에 추가됩니다.

실제 스테이지에서는 `WaveSequence` 아래 편대 마커를 선택해 `Optional Overrides`의
`Movement Profile` 또는 `Attack Sequence`에 `.tres`를 연결하세요. 비워 두면 적 씬의
기본 설정을 씁니다. 예시는 `data/movement/`와 `data/sequences/`에 있습니다.
`No attack` 순서를 고르면 기존 발사도 멈춥니다. 발사 노드가 없는 적에게 공격 순서를
연결하면 발사 노드가 생성됩니다. `Path2D`가 있는 편대는 그 경로가 이동 프리셋보다 우선입니다.

프리셋은 공유 설정 데이터입니다. 특정 편대만 속도나 탄 수를 바꾸려면 `.tres`를 복제해서
연결하세요. 발사 타이머와 이동 진행도는 적 인스턴스마다 별개입니다.

## 보스 패턴 순서 변경

`scenes/enemies/boss.tscn`을 엽니다.

- `Shooter.Steps`: 1단계 공격 순서
- 루트 `Second Phase`: 2단계 공격 순서
- 루트 `Phase Threshold`: 2단계 진입 HP 비율
- 루트 `Maximum HP`: 보스 체력
- `Movement.Hold Position`: 보스가 자리 잡을 좌표

크기 확대 후 중형 일반 적(N1–N5)과 미들·최종 보스의 체력을 50% 올렸습니다.
N1–N5의 Maximum HP는 18 / 24 / 30 / 33 / 24,
M1–M3는 360 / 495 / 585, 최종 보스는 1020입니다.
M1은 벽 패턴 교전이 길다는 피드백에 따라 540에서 360으로 낮췄습니다.
자코 Z1–Z5의 체력은 유지합니다. 각 적 씬의 루트 `Maximum HP`에서 추가 조절할 수 있습니다.

각 배열의 순서와 Step의 반복/대기를 편집하면 됩니다. 2단계 진입은 한 번만 일어나고,
바뀐 공격 목록은 첫 단계부터 시작합니다.

## 스테이지의 적과 보스 배치

전투 창의 이동 가능 범위는 `data/rules/default.tres`의 Playfield이고, 프레임 안쪽 전체
표시 범위는 Stage의 Presentation Bounds입니다. 하단 콘솔과 프레임에 기체가 가려지지
않도록 이동 범위를 안쪽에 둡니다. 레퍼런스 배치를 위해 WaveSequence와 PlacedEnemies에
동일한 `(400, -68)` 위치 오프셋을 적용했습니다. 편대 마커의 기존 로컬 좌표와 등장 간격은
유지하며, 진입 후 정지 위치에도 런타임과 에디터 미리보기에서 같은 오프셋을 적용합니다.
`Battle_Bg.png`의 흰 창은 `battle_frame.gdshader`로 투명하게 표시하므로 원본 PNG를 수정할
필요가 없습니다. 전투 전용 초상화 씬은 선택·결과 화면의 초상화 표시와 별개입니다.

`stage_01.tscn`은 오른쪽으로 이어지는 월드입니다. 플레이어와 카메라는 전투 중
`Stage.Scroll Speed`(기본 180px/초)로 전진합니다. 적의 등장 기준은 경과 시간이 아니라
**월드 X좌표**입니다. 카메라가 적 위치에서 `Activation Margin`(기본 80px)만큼 떨어진
지점에 오면 적이 활성화됩니다. 일시정지·사망·교대 중에는 전진도 멈추고, 보스 진입 후에는
카메라가 고정됩니다. `StageGuide`의 청록색 테두리와 구획선은 에디터에서만 보이는 배치 기준입니다.
같은 노드의 `Show Enemy Previews`와 `Show Trajectories`로 적 외형과 예상 이동선을 켜고 끌 수
있습니다. `Preview Seconds`는 직선·물결·진입/정지/퇴장·세로 왕복 이동선의 표시 길이만 조절합니다.
미들 3종(M1–M3)이 등장하면 화면 전진이 멈추고, 처치하면 다시 진행합니다.

한 기를 정확한 위치에 놓으려면 적 씬을 `Simulation/PlacedEnemies` 아래에 인스턴스로
추가하고 2D 화면에서 옮기세요. 이 적은 처음에 보이지 않고 동작하지 않다가 화면 오른쪽에
가까워지면 활성화됩니다. 아이템을 떨어뜨리려면 해당 적 루트의 `Drop Scene`과
`Drop Chance`를 설정합니다. `N5Upper`와 `N5Lower`가 직접 배치 예시입니다.

편대를 배치하려면 `Simulation/WaveSequence` 아래의 마커를 복제하고 옮깁니다.

- `Enemy Scene`: 생성할 적 씬
- `Count`: 편대의 적 수. 한 기만 필요하면 1
- `Spawn Offset`: 다음 적과의 **월드 좌표 간격**. X가 클수록 진행 방향으로 멀리 놓임
- `Drop Mode`: None / Guaranteed / Chance
- `Drop Scene / Drop Chance`: 처치 시 아이템과 적 한 기당 드롭 확률

마커 위치가 첫 적의 출현 위치입니다. `Path2D` 자식이 있으면 그 경로 시작점이 첫 적의
위치가 되고, 이후 적은 `Spawn Offset`만큼 평행 이동한 같은 경로를 따릅니다. 2D 에디터에서
곡선의 점과 접선을 옮길 수 있습니다. 경로 이동은 적 씬의 이동 모드를 대체합니다.
마커에 연결된 적 씬의 `Visual`(Polygon2D 또는 Sprite2D)과 `Core`(Polygon2D)가 시작 위치에
미리 표시됩니다. `Path2D`가 없는 편대와 직접 배치한 적은 Movement 프리셋의 이동선이
에디터에 표시됩니다. 직접 배치한 적의 실제 외형은 씬 인스턴스가 보여줍니다.
특정 편대의 경로만 바꾸려면 Curve를 **Make Unique**로 분리하세요.

보스는 `WaveSequence/BossMarker`를 옮겨 등장 구역을 정합니다. 보스 씬 자체는
`WaveSequence.Boss Scene`에 연결합니다. 마커에 도달하면 화면 전진이 멈추고 보스전이
시작됩니다. 맵을 더 길게 만들면 `StageGuide.Length`도 늘려 배치선을 확장하세요.

`Path2D`가 없는 편대와 직접 배치된 적은 적 씬의 `Movement` 설정을 사용합니다.

| Mode | 주요 설정 |
|---|---|
| Linear | Direction, Speed |
| Sine | Direction, Speed, Amplitude, Frequency |
| Enter Hold Exit | Hold Position, Hold Seconds, Exit Direction, Speed |
| Path | Wave에서 경로를 전달할 때 자동 지정 |

Hold Position의 X는 등장 당시 화면을 기준으로 한 좌표이며, Y는 월드 좌표입니다.
`Stay Forever`를 켜면 정지 지점에서 퇴장하지 않습니다.
같은 적의 다른 이동 변형은 우선 편대 마커의 Movement Profile로 지정하세요. 외형·충돌
범위까지 달라질 때는 inherited scene을 만들 수 있습니다.

일반 적의 마지막 배치 위치는 BossMarker보다 앞에 두세요. 보스 진입 후에는 새 적을
활성화하지 않습니다.

## 새로운 동작 코드 추가

기존 조합으로 표현되지 않는 행동에만 스크립트를 추가합니다.

- 새 탄환: `Projectile`을 상속한 스크립트와 씬. 기본 수명·경계 정리를 유지하도록 필요 시
  `super._physics_process(delta)`를 호출합니다. 씬을 AttackPattern에 연결합니다.
- 새 이동: `EnemyMovement` 상속 스크립트로 적 씬의 Movement 스크립트를 교체합니다.
  `actor`만 이동시키고 다른 이동 제어기를 함께 실행하지 않습니다.
- 레이저 등 새로운 공격 형태: EnemyShooter와 같은 방식으로 projectiles, target_provider,
  bounds를 전달받는 전용 노드를 추가하고 필요한 경우 Stage의 생성 연결 부분을 확장합니다.

처음부터 범용 행동 트리, 공격 DSL, 전역 이벤트 버스는 필요하지 않습니다.

## 타이틀 화면

`scenes/title/title.tscn`의 `Layout`에서 1920×1080 기준으로 배치합니다. `Space`는
전체 화면 우주 배경, `Logo`는 PANIC HORIZON 로고, `Ship`은 기체입니다. 루트의
`Ship Float Pixels`와 `Ship Float Seconds`로 기체의 상하 움직임을 조절합니다.
`Portraits`는 `title_crew.tscn`의 인스턴스입니다. 녹색 캐릭터 군상의 일반·밝은 노이즈·해골
이미지를 바꾸는 연출은 이 씬의 `AnimationPlayer`에서 편집합니다.
`ScreenEffects`는 스캔라인과 강도를 낮춘 비네팅을 겹칩니다.

`StartPrompt`의 Texture에 `Press Any key.png`의 `PRESS ANY BUTTON` 스프라이트를 연결합니다.
메뉴·엔딩 목록 텍스트는 `TitleFont`의 Noto Sans KR 굵기 600 변형을 사용합니다. 실행 시 안내만 표시하고 첫 버튼
입력 후 `Menu`의 세 버튼을 표시합니다. 메뉴 배치를 편집할 때는 Visible을 켜서 작업할 수
있으며 실행 시에는 자동으로 숨깁니다. `Collection`은 엔딩 목록이며 시작 입력·새 게임
시작·엔딩 목록 열기·메뉴 복귀는 `title.gd`에서 관리합니다. 첫 입력의 반복과 해제는
메뉴 버튼에 전달하지 않아 같은 입력으로 새 게임이나 종료가 실행되지 않습니다.

### 녹색 캐릭터·해골 애니메이션 편집

1. FileSystem에서 `scenes/title/title_crew.tscn`을 엽니다. 타이틀의 `Portraits` 옆
   씬 열기 아이콘으로 들어가도 됩니다.
2. `AnimationPlayer`를 선택하고 하단 Animation 패널에서 `idle`을 고릅니다.
3. `TitleCrew:texture` 트랙의 키를 좌우로 드래그해 이미지 전환 시점을 조정합니다.
   타임라인을 클릭하거나 재생 버튼을 누르면 해당 시점의 이미지를 미리 볼 수 있습니다.
4. 이미지를 추가·교체하려면 원하는 시간에 커서를 놓고 루트 `TitleCrew`를 선택합니다.
   Inspector의 Texture에 PNG를 드래그한 뒤 Texture 옆 키 아이콘을 누릅니다.
   기존 시간의 키도 같은 방법으로 교체할 수 있습니다.
5. 필요 없는 키는 선택 후 Delete로 지웁니다. 마지막 이미지의 유지 시간은
   다음 키 또는 애니메이션 끝까지이며, 전체 길이와 반복은 Animation 패널에서 조절합니다.
6. 씬과 애니메이션을 저장한 뒤 `title.tscn`을 열고 **F6**으로 실제 화면을 확인합니다.

`TitleBG1.png`는 정상, `TitleBG2.png`는 밝은 노이즈, `TitleBG3.png`는 해골입니다.
기존 연출을 유지해 6초마다 반복하며 첫 정상 이미지는 0.6초, 이후 키 간격은 0.1초입니다.
타임라인의 Step도 0.1초이며, 더 짧은 깜빡임이 필요하면 Step을 줄여 키를 배치합니다.
텍스처 트랙은 Discrete로 설정해 키 사이에 이미지를 보간하지 않습니다.
`RESET`은 편집·저장 시 정상 이미지를 복원하는 기본 상태이므로 연출은 `idle`에서 작업하세요.

`title_crew_idle.tres`는 Unity의 `.anim`처럼 이미지와 타이밍을 담는 별도 Animation
리소스입니다. `title_crew.tscn`은 스프라이트와 재생기를 묶는 재사용 씬이며, 타이틀은
이를 인스턴스로 사용하므로 애니메이션 수정이 그대로 반영됩니다. 프레임 교체는
AnimationPlayer가 담당하며 별도 코드 수정은 필요하지 않습니다.
현재 세 PNG는 여섯 캐릭터가 합쳐진 이미지이므로, 캐릭터별 타이밍을 따로 편집하려면
개별 캐릭터 이미지로 분리해야 합니다.

## 파일럿·스토리·연출 교체

PilotData에서 초상화를 드래그해 교체할 수 있습니다. `Hangar Portrait`는 선택 화면 정보창에
사용하며, 비어 있으면 `Normal`을 표시합니다. 파일럿 카드의 일반 초상화는 전체 사망자 수에
따라 `Normal`(0명), `One Dead`(1명), `Two Dead`(2~3명), `Four Dead`(4~5명)로 바뀝니다.
출격 중인 파일럿의 HP가 절반 이하로 떨어지면 `Damaged`를, 사망하면 `Dead`를 표시합니다.
전용 초상화가 비어 있으면 일반 초상화로 대체합니다.

각 PilotData의 Ship Scene은 공통 player_ship의 변형 씬을 가리킵니다. `Ship Scale`은 외형
크기만 바꾸므로 피격 범위를 바꾸려면 CollisionShape2D를 별도로 수정하세요.

파일럿 선택 화면은 CharacterSelect 씬의 `Layout` 안에서 1920×1080 기준으로 편집합니다.
`Background`와 `Frame`은 전체 화면 PNG이며, 하단 `Hangar/Pilot0~5`는 `SixPilot.png`의
AtlasTexture 영역을 사용하는 TextureButton입니다. 바닥선 양 끝은 `PlatformLeft/Right`가
이어 표시합니다. 파일럿 순서는 GameCatalog의 Pilots 배열을 따릅니다.
`Details`의 Visible을 켜면 정보창 위치를 편집할 수 있으며 저장할 때는 다시 끕니다.
초상화는 비율을 유지한 채 왼쪽 영역을 채우고 넘치는 부분은 자릅니다. 이름·소개는
PilotData에서 가져오며 `Description`의 Characters Per Second로 타이핑 속도를 조절합니다.
클릭/Enter/A로 정보창을 열고, 출격 버튼/Enter/A로 확인하며 X/Esc/B로 닫습니다.

StoryData의 Pages 배열에서 순서를 바꾸거나 StoryPage를 추가합니다. 페이지마다 Illustration,
Caption, Text를 설정합니다. Intro와 모든 Ending은 같은 StoryScreen을 사용합니다.
그림은 비율을 유지해 화면 전체에 표시하며 Caption과 Text는 하단 자막입니다.
`intro.tres`의 9컷은 `introStory01~09`, `betrayal.tres`의 4컷은 `WithAi01~04`,
`unknown_horizon.tres`의 4컷은 `234ed01~04`에 연결되어 있습니다.
`cost_of_dawn.tres`(5명)와 `new_home.tres`(6명)는 `56ed01~04`를 공유하고 본문은 각각 편집합니다.
전멸·1명 생존 엔딩은 Illustration을 비워 두었습니다. 원본 그림이 준비되면 연결하세요.
본문과 파일럿 소개·사망·승리 대사는 “대사 1”, “대사 2” 형식으로 비워 두었고,
컷별 Caption은 빈 문자열입니다. 기존 PNG 순서와 엔딩 저장 ID는 유지합니다.
AI가 작성한 SVG, 별 배경, 장식 테마와 임시 기체 도형은 제거했습니다. 보스·샘플 적은
제공된 적 PNG를 재사용하며, 아이템은 P/B/S 문자로 표시합니다.

엔딩의 제목·스토리는 EndingData에서, **분기 규칙 자체**는
`scripts/ending/ending_resolver.gd`에서 수정합니다. 저장용 ID를 바꾸면 기존 해금 기록과
연결되지 않으므로 공개 후에는 ID를 유지하세요.

## 빠른 확인

- Stage 씬 F6: 첫 파일럿으로 바로 출격. 영구 저장은 하지 않음
- Title / CharacterSelect / Story / Result 씬 F6: 샘플 데이터로 화면 미리보기
- F5: 전체 흐름, 엔딩 해금·저장까지 확인
- `python tools/check.py`: 상태·전투·전체 웨이브·저장 회귀 검사

## 스테이지 템포 조정

최신 배치표와 연구 근거는 [STAGE_DESIGN.md](docs/STAGE_DESIGN.md)를 참고하세요. 기본 속도에서 출현 초는 `(Wave X - 1568) / 180`입니다. 미들 교전 동안 이 시간은 멈춥니다. `hold_high.tres` / `hold_low.tres`는 상하 정지 사격용 프리셋입니다. `Shooter`의 `Telegraph Seconds`는 공격 묶음 전 예고(기본 0.35초), 탄환의 `Homing Seconds`는 추적 지속 시간(기본 1.2초)입니다.


## 2026-10-05 레벨 개정 프리셋

Enemy Lab(F6)에 `Tracking three-shot stream`, `Four-way gate`, `Locked sweep` 공격과 `Strafe then retreat` 이동을 추가했습니다. 실제 스테이지의 N4는 상단/하단/중앙 포대 프리셋을 사용하며 진입·퇴장 중에는 사격하지 않습니다.

- `data/movement/strafe_*.tres`: 진입 속도, 상하 진폭/주기, 주둔 시간, 퇴장 방향.
- `follow_scroll`: 진입·주둔 위치가 카메라 전진을 따라갑니다. 기존 월드 고정 동작은 false로 유지합니다.
- `data/patterns/tracking_stream.tres`: 매 회차 재조준, 연사 간격과 회복.
- `data/patterns/gate_fan.tres`: 중앙을 비운 고정 4방향.
- `data/patterns/sweep_fan.tres`: 예고 때 조준 고정, 이후 회차별 회전, 긴 회복.

총구 예고는 고정 방향 청록 / 조준 고정 노랑 / 재조준 분홍이며 방향선도 표시합니다. 적탄 외형은 현재 A/B/C 스프라이트를 사용합니다. 전체 배치와 검증 결과는 [스테이지 설계](docs/STAGE_DESIGN.md)를 참고하세요.


## 보스와 외계 함대 공격

Enemy Lab의 `Scene default`로 M2/M1/M3/Boss를 선택하면 각각 삼단 도약탄과 쌍익 교차 사격/세 가지 벽 조합 순환/부화탄/기함 조합을 시험할 수 있습니다. 날개 달린 뮤탈리스크형 외형은 `Enemy/L2.png`를 쓰는 M2입니다. Attack 프리셋에는 `fleet_lattice`, `pursuit_fan`, `siege_curtain`, `command_curtain`, `brood_launch`, `brood_spiral`, `삼단 도약탄 / Three-cushion`이 있습니다.

- `AttackPattern > Muzzle Offsets`: 발사점을 분리합니다. 단위는 **월드 px**이므로 적 스프라이트의 스케일을 다시 곱하지 않습니다.
- `Shape = CURTAIN`: 화면 높이에 탄을 배치합니다. `Corridor Width`는 통로 폭(px)입니다. `Corridor Center/Shift`는 `Corridor Routes`가 비어 있을 때 통로 위치·회차별 변화 폭을 정합니다. 고정 수평 발사(`Aim=FIXED`, 각도180°)로 사용합니다. `Bullet Count`는 통로를 비우기 전 후보 탄 수입니다.
- `Curtain Routes > Corridor Routes`: 각 배열에 벽 회차별 통로 높이를 0~1로 입력합니다(0=위, 1=아래). 배열 길이는 `Volley Count`와 같아야 합니다. 기본 두 패턴은 네 조합 중 하나를 묶음 시작 전에 선택하며, 바로 직전 조합은 제외합니다. 선택 상태는 적 발사기별로 관리하고 첫 예고부터 마지막 발사까지 유지합니다. 갑각수는 각 배열에 3개, 보스 후반 패턴은 4개의 높이가 들어갑니다.
- `Curtain Motion`: `Curtain Sway Volley`는 0부터 세는 회차입니다(1=두 번째 벽, -1=모두 고정). `Amplitude`는 상하 진폭(px), `Period`는 한 주기의 초입니다. 기본 봉쇄 패턴 두 종류는 두 번째 벽만 ±72px/6초로 움직입니다. `siege_bullet.tscn`의 `CurtainBullet`이 탄열 전체에 같은 이동량을 적용하며, 움직이는 벽은 화면 끝에 추가 탄을 배치하고 스프라이트가 깜빡입니다. 발사 전 예고는 각 벽의 기존 발사 간격 안에서 표시됩니다.
- `brood_core.tscn`: 300px/s로 0.85초 이동, 0.65초 정지 예고 후 120°에 7발을 발사합니다. `Travel Seconds`, `Incubation Seconds`, `Child Count`, `Child Spread`를 수정할 수 있습니다. `Child Scene`은 보통 탄만 허용하며 부화탄의 재귀 생성을 막습니다.
- 부모 탄을 폭탄/탄 소거로 제거하면 부화가 취소됩니다. 부모 탄이 부화 전에 플레이어에 충돌한 경우도 자식 탄을 만들지 않습니다.
- 보스 단계는 `EnemyShip > Second Phase`에서 변경합니다. 기본은 HP 50%에서 부화탄→기함 봉쇄벽→재조준 연사로 전환합니다.

M1의 `Shooter`는 `SiegeShooter`입니다. 기본 순서는 **유인탄→벽 / 벽→교차탄 / 핵→벽→시간차 분열**이고, 각 순환의 잔탄까지 소멸한 뒤 `Counter Seconds`(기본2초) 동안 쉽니다. `Lure Interval`, `Opening Pause`, `Cross Interval`, `Cross Angle Degrees`, `Core Stagger`로 추가 공격의 간격·각도·시간차를 조절합니다. 벽 설정은 `Steps[0].Pattern`의 기존 `siege_curtain`을 사용합니다. `siege_core.tscn`은 기존 부화탄의 파생 씬이며 5발/44°입니다. 핵은 벽이 사라질 때까지 부화를 보류하고, 해제 후 기존 PNG로 부화 방향을 예고합니다. Attack 선택을 `Scene default`로 두면 세 순환을 시험하고, 명시적 프리셋을 고르면 해당 공격으로 대체합니다. `python tools/siege_cycles.py`로 실제 충돌과 순환·반격·부화 취소를 검사합니다.

삼단 도약탄은 M2의 첫 공격이며 `data/patterns/ricochet.tres`, `scenes/projectiles/ricochet_core.tscn`에서 편집합니다. 0.6초 충전 후 한 발이 위→왼쪽→아래로 반사하며, 다음 사용은 아래→왼쪽→위입니다. 각 반사점은 도착0.45초 전에 플레이어 위치로 잔탄 조준을 확정하고 예고합니다. 도착 후0.18초 정지한 뒤7·9·11발/70°를 발사하며, 예고 뒤에는 해당 조준을 바꾸지 않습니다. 모탄640px/s, 반사마다 속도96%, 잔탄360px/s·수명3.8초입니다. 테두리64px 안쪽에서 반사하며 얕은 조준 각도에서도 부채꼴 전체가 영역 안쪽을 향합니다. 세 번째 반사에서는 모탄 판정을 제거하고 마지막 예고 후 소멸합니다. `Child Count`, `Middle Child Count`, `Final Child Count`, `Child Spread`, `Aimed Fans`, `Bank Warning Seconds`, `Bank Pause Seconds`, `Speed Retention`으로 조절합니다. 원본 B PNG와 금색 테두리·남은 반사 점으로 모탄을 구분합니다. 잔탄 정리 뒤1초 반격 시간을 주고 기존 쌍익/재조준 공격을 이어 갑니다. M1과 최종 보스에서는 제거했습니다. `python tools/ricochet_pressure.py`로 초기/강화판의 접촉 압박과 P2 입력 회피를 비교할 수 있습니다.

`python tools/balance.py --boss-patterns`는 기존 6개 조건에 25개 보스 정지 위치 계측을 추가합니다. 한 지점에서 안 맞는지 보는 표본 검사이므로, 전체 패턴의 인간 회피 가능성을 증명하는 검사는 아닙니다.

## 효과음 편집

`scenes/audio/sound_effects.tscn`은 프로젝트의 `Sfx` Autoload입니다. 각 자식 `AudioStreamPlayer`의 `Stream`, `Volume dB`, `Max Polyphony`를 에디터에서 수정하면 음원·음량·동시 재생 수를 바꿀 수 있습니다. F5와 스테이지 F6 실행에서 같은 설정을 사용합니다.

현재 승인된 연결은 플레이어 격추(`Explosion 51`), 중간/최종 보스 격파(`Explosion 511`), 실제 Power Up 레벨 상승, 폭탄 보급, 무기 전환, UI 이동·확정·취소, 보스/강공격 경고입니다. 일반 적 격파와 보류한 효과음은 연결하지 않았습니다. 강화·폭탄이 이미 상한이면 증가 효과음을 재생하지 않습니다.

추가 승인된 효과음은 실제 폭탄 발동(`Explosion 17`), 실드 획득(`UI Replenish Octave`), 실드 파괴(`Distortion Arc Short 02`)입니다. 폭탄 예약·취소에는 폭발음을 내지 않으며, 실드가 이미 있거나 피격 무적에 막힌 경우에는 실드 효과음을 반복하지 않습니다.

폭탄은 실제 발동 시의 폭발음만 사용합니다. 별도 폭탄 준비음(후보 5번)은 사용하지 않습니다.

최초 출격과 파일럿 교대 후 재출격에는 `FIRE_Fireball_Whoosh_Slow`를 공통으로 사용합니다. 기체 진입 연출이 시작될 때 한 번 재생하며, 연출 중 전투가 정지되어 있어도 소리는 이어집니다.

공격 프리셋의 `Audible Warning`을 켜면 시각 예고가 시작될 때 공통 경고음을 재생합니다. 기본 적용 대상은 탄벽, 쌍익 교차 사격, 삼단 반사탄, 부화탄과 회전 탄막입니다. M1의 전용 순환도 같은 설정을 따릅니다. 경고음이 재생 중이면 중복 경고를 겹치지 않습니다.

`python tools/check.py`에는 승인 음원 매핑, 획득 상한, 키보드/HUD 무기 전환, 사망 중 재생, 경고 중복, UI 조작 검사가 포함됩니다.

## BGM 편집

`scenes/audio/game_music.tscn`은 프로젝트의 `Music` Autoload입니다. 루트 `Music`을 선택하면
Inspector의 `Approved Tracks`에서 곡을 교체하고, `Playback > Volume dB`에서 공통 음량을
조절할 수 있습니다. 기본 음량은 -18 dB이며, 화면·전투 상황이 바뀔 때 0.5초 동안 교차 전환합니다.

| 용도 | 승인 번호 | 음원 / Inspector 속성 |
| --- | --- | --- |
| 타이틀·인트로 | 1 | The Space Is Full Of $tars / Title Track |
| 파일럿 선택 | 2 | Capt Chip Pants / Select Track |
| 일반 스테이지·중간 보스 | 4 | Fight For Your Lives / Stage Track |
| 최종 보스 등장·전투 | 5 | Decisive Battle / Boss Track |
| 클리어·생존 엔딩 결과 | 6 | Victory At Last / Clear Track |
| 2~4명 일반 생존·5명·6명 생존 엔딩 | 7 | Yet Another Journey / Ending Track |
| 전멸·1명 생존·AI 배신 엔딩과 그 결과 | 8 | Lilith's Elegy / Somber Ending Track |

인트로는 타이틀곡을 이어 재생합니다. 파일럿 격추·교대·재출격 중에는 현재 스테이지 또는
보스 곡을 유지합니다. 수동 일시정지는 음악과 전환 시간을 함께 멈추고, 재개하면 같은 위치에서
이어집니다. 출격·보스 등장·클리어 등 자동으로 전투를 멈추는 연출 중에는 BGM을 계속 재생합니다.

선택 화면 곡은 원래의 반복 구조에 맞춰 샘플 루프를 사용합니다. 나머지 곡은 끝에서 1초 동안
시작 부분과 교차 전환하며 반복합니다. `Loop End Seconds`는 곡 끝의 거의 무음인 꼬리를
제외하는 지점(초)입니다. 곡을 바꿀 때 해당 항목을 삭제하면 전체 길이를 사용합니다.
완전한 루프 음원으로 교체한 경우 `Native Loop Cues`에 해당 키(`title`, `select`, `stage`,
`boss`, `clear`, `ending`, `somber_ending`)를 추가하면 교차 전환 없이 반복합니다.
이 재생 설정은 실행 중 복사본에 적용되며 원본 음원과 공통 Import 설정은 그대로입니다.

`python tools/check.py`는 승인된 7곡, 실제 화면 전환, 파일럿 교대, 수동 일시정지,
6개 엔딩·결과 분기, 반복 재생과 중복 요청도 검사합니다.
