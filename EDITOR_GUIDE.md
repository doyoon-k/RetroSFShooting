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
| 기본 공격 LV1~3 / 차지샷 | `data/weapons/standard.tres` |
| 적 성능 | `scenes/enemies/*.tscn` |
| 공격 패턴 | `data/patterns/*.tres` |
| 스테이지 배치와 이동 속도 | `scenes/gameplay/stage/stage_01.tscn` |
| 아이템 성능 | `scenes/items/*.tscn` |
| 일러스트·본문·타이핑 속도 | `data/stories/*.tres` |
| 메뉴·HUD 스타일 | `scenes/ui/game_theme.tres` |
| 키보드·게임패드 | Project Settings → Input Map |

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
예외적으로 WeaponData의 각 레벨 설정을 사용합니다.

**공유 리소스에 주의:** 같은 `.tres`를 참조하는 모든 적에게 수정이 적용됩니다. 특정 적만
바꾸려면 그 리소스를 복제해 연결하세요. 중첩된 Step 안의 Pattern까지 독립시키려면 Pattern도
복제해야 합니다. 실행 중 타이머와 조준 상태는 EnemyShooter별로 독립되어 있습니다.

## 보스 패턴 순서 변경

`scenes/enemies/boss.tscn`을 엽니다.

- `Shooter.Steps`: 1단계 공격 순서
- 루트 `Second Phase`: 2단계 공격 순서
- 루트 `Phase Threshold`: 2단계 진입 HP 비율
- 루트 `Maximum HP`: 보스 체력
- `Movement.Hold Position`: 보스가 자리 잡을 좌표

각 배열의 순서와 Step의 반복/대기를 편집하면 됩니다. 2단계 진입은 한 번만 일어나고,
바뀐 공격 목록은 첫 단계부터 시작합니다.

## 스테이지의 적과 보스 배치

`stage_01.tscn`은 오른쪽으로 이어지는 월드입니다. 플레이어와 카메라는 전투 중
`Stage.Scroll Speed`(기본 180px/초)로 전진합니다. 적의 등장 기준은 경과 시간이 아니라
**월드 X좌표**입니다. 카메라가 적 위치에서 `Activation Margin`(기본 80px)만큼 떨어진
지점에 오면 적이 활성화됩니다. 일시정지·사망·교대 중에는 전진도 멈추고, 보스 진입 후에는
카메라가 고정됩니다. `StageGuide`의 청록색 테두리와 구획선은 에디터에서만 보이는 배치 기준입니다.
같은 노드의 `Show Enemy Previews`와 `Show Trajectories`로 적 외형과 예상 이동선을 켜고 끌 수
있습니다. `Preview Seconds`는 직선·물결·진입/정지/퇴장 이동선의 표시 길이만 조절합니다.

한 기를 정확한 위치에 놓으려면 적 씬을 `Simulation/PlacedEnemies` 아래에 인스턴스로
추가하고 2D 화면에서 옮기세요. 이 적은 처음에 보이지 않고 동작하지 않다가 화면 오른쪽에
가까워지면 활성화됩니다. 아이템을 떨어뜨리려면 해당 적 루트의 `Drop Scene`과
`Drop Chance`를 설정합니다. `HunterTop`과 `HunterBottom`이 직접 배치 예시입니다.

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
같은 적의 다른 이동 변형이 필요하면 적 씬의 inherited scene을 만들고 Movement만 수정하세요.

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

## 파일럿·스토리·연출 교체

PilotData에서 초상화를 드래그해 교체할 수 있습니다. `Hangar Portrait`는 선택 화면 격납고에,
`Normal`과 다른 표정은 선택·스테이지의 파일럿 카드에 사용합니다. 격납고 초상화가 비어 있으면
`Normal`을 표시합니다. 표정 에셋이 비어 있으면 `Normal`로 대체합니다.

각 PilotData의 Ship Scene은 공통 player_ship의 변형 씬을 가리킵니다. `Ship Scale`은 외형
크기만 바꾸므로 피격 범위를 바꾸려면 CollisionShape2D를 별도로 수정하세요.

격납고는 CharacterSelect 씬의 Hangar 아래 여섯 노드에 배치되어 있습니다. 각 노드의
`Pilot`에 해당 PilotData를 연결하면 이름과 격납고 초상화가 에디터에도 표시됩니다. 노드의
위치를 바꿔도 파일럿 데이터 연결은 유지됩니다. 각 AnimationPlayer를 편집하고 PilotData의
Hangar Animation 이름으로 재생할 애니메이션을 선택할 수 있습니다.

StoryData의 Pages 배열에서 순서를 바꾸거나 StoryPage를 추가합니다. 페이지마다 Illustration,
Caption, Text를 설정합니다. Intro와 모든 Ending은 같은 StoryScreen을 사용합니다.

엔딩의 제목·스토리는 EndingData에서, **분기 규칙 자체**는
`scripts/ending/ending_resolver.gd`에서 수정합니다. 저장용 ID를 바꾸면 기존 해금 기록과
연결되지 않으므로 공개 후에는 ID를 유지하세요.

## 빠른 확인

- Stage 씬 F6: 첫 파일럿으로 바로 출격. 영구 저장은 하지 않음
- Title / CharacterSelect / Story / Result 씬 F6: 샘플 데이터로 화면 미리보기
- F5: 전체 흐름, 엔딩 해금·저장까지 확인
- `python tools/check.py`: 상태·전투·전체 웨이브·저장 회귀 검사
