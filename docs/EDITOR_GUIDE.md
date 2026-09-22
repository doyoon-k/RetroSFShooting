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
| 스테이지와 웨이브 | `scenes/gameplay/stage/stage_01.tscn` |
| 아이템 성능 | `scenes/items/*.tscn` |
| 일러스트·본문·타이핑 속도 | `data/stories/*.tres` |
| 메뉴·HUD 스타일 | `scenes/ui/game_theme.tres` |
| 키보드·게임패드 | Project Settings → Input Map |

## 새 적 공격 만들기

1. `data/patterns/fan.tres`를 복제하고 이름을 바꿉니다.
2. Inspector에서 `AttackPattern`의 값을 수정합니다.
3. `fan_step.tres`도 복제하고 `Pattern`에 새 패턴을 연결합니다.
4. 적 씬의 `Shooter` 노드 → `Steps`에 새 `PatternStep`을 넣습니다.
5. Stage의 Wave에서 그 적 씬을 사용합니다.

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

## 이동과 웨이브 편집

`stage_01.tscn`의 `Simulation/WaveSequence` 아래 Wave들을 수정하거나 복제합니다.

- Start Time: 실제 전투 경과 시간 기준 시작 시각
- Enemy Scene: 생성할 적
- Count / Interval: 수량과 생성 간격
- Wave 위치 / Spawn Offset: 생성 위치와 적마다 추가할 위치 차이
- Drop Mode: None / Guaranteed / Chance
- Drop Scene / Drop Chance: 드롭 아이템과 확률

Wave에 `Path2D` 자식이 있으면 그것을 편대 경로로 사용합니다. 2D 에디터의 곡선 편집으로
점과 접선을 옮기세요. 곡선은 Wave의 로컬 좌표계이므로 Wave를 옮기면 전체 경로도 옮겨집니다.
적의 Movement가 곡선을 따라 거리를 증가시키며, 경로 끝에서 적을 제거합니다. 경로 이동은
다른 이동 모드를 대체하므로 두 기능이 동시에 기체 위치를 수정하지 않습니다.

곡선도 공유 가능한 Resource입니다. 특정 Wave의 경로만 바꾸려면 Path2D의 Curve를
Make Unique로 독립시킨 뒤 편집하세요.

Path2D가 없는 Wave에서는 적 씬의 `Movement` 설정을 사용합니다.

| Mode | 주요 설정 |
|---|---|
| Linear | Direction, Speed |
| Sine | Direction, Speed, Amplitude, Frequency |
| Enter Hold Exit | Hold Position, Hold Seconds, Exit Direction, Speed |
| Path | Wave에서 경로를 전달할 때 자동 지정 |

Hold Position은 스테이지 좌표입니다. `Stay Forever`를 켜면 정지 지점에서 퇴장하지 않습니다.
같은 적의 다른 이동 변형이 필요하면 적 씬의 inherited scene을 만들고 Movement만 수정하세요.

`WaveSequence.Boss Time`은 보스 등장 시각입니다. 그 이후에는 일반 웨이브를 새로 시작하지
않으므로 일반 Wave의 마지막 생성 시각은 Boss Time 이전으로 두세요.

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

PilotData에서 초상화를 드래그해 교체할 수 있습니다. 표정 에셋이 비어 있으면 기본 초상화로
대체합니다. 샘플은 마지막 생존자의 Alone 표정을 별도로 포함합니다.

각 PilotData의 Ship Scene은 공통 player_ship의 변형 씬을 가리킵니다. `Ship Scale`은 외형
크기만 바꾸므로 피격 범위를 바꾸려면 CollisionShape2D를 별도로 수정하세요.

격납고는 CharacterSelect 씬의 Hangar 아래 여섯 노드에 배치되어 있습니다. 각
AnimationPlayer를 편집하고 PilotData의 Hangar Animation 이름으로 재생할 애니메이션을
선택할 수 있습니다. 현재는 교체 가능한 간단한 Idle 샘플입니다.

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
