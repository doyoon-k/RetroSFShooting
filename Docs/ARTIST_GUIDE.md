# 아티스트 작업 가이드 (Unity)

RattleBloom과 같은 방식으로 작업합니다. 게임 로직이 붙은 오브젝트와 그림이 붙은 오브젝트를
나눠 두었기 때문에, 그림·애니메이션은 로직을 건드리지 않고 바꿀 수 있습니다.

## 프리팹 구조

```text
EnemyShip (루트)            ← EnemyShip / EnemyMovement / Rigidbody2D / Animator
  - Visual                  ← SpriteRenderer (몸체 그림). 피격 플래시와 피 튀는 효과 크기의 기준
  - CollisionShape2D        ← 판정. 그림과 별개로 크기 조절
  - Shooter                 ← 발사 위치. 예고선도 여기서 그려짐
```

- 플레이어: `Assets/Prefabs/player/player_ship.prefab` (P1~P6은 이 프리팹의 Variant)
- 적: `Assets/Prefabs/enemies/*.prefab`
- 탄: `Assets/Prefabs/projectiles/*.prefab`
- 아이템: `Assets/Prefabs/items/*.prefab`
- 이펙트: `Assets/Prefabs/gameplay/explosion.prefab`, `enemy_hit.prefab`

`Visual` 아래에 자식을 더 붙이거나 스프라이트를 바꿔도 됩니다. 루트의 Scale은 판정 크기까지
함께 바꾸므로, 그림 크기만 바꾸려면 `Visual`의 Scale을 조절하세요.

## 애니메이션

- 모든 애니메이션은 `Assets/Animations/<프리팹 이름>/`에 Animator Controller와 .anim으로 있습니다.
- 적의 사망 연출: 컨트롤러의 `death` 상태. EnemyShip의 `Death Animation`에 상태 이름,
  `Death Animation Seconds`에 길이를 넣으면 그 시간 동안 연출한 뒤 사라집니다.
- 대기(Idle) 애니메이션을 추가하려면 컨트롤러의 `Idle` 상태에 클립을 넣으면 됩니다.
- 폭발·피격 이펙트는 기본 상태가 한 번 재생되고 끝나면 자동으로 삭제됩니다(`OneShotEffect`).
  클립의 Loop Time은 꺼 두세요.
- 밝게 번쩍이는 색(1보다 큰 값)은 SpriteRenderer 색 대신 머티리얼 속성 `_Tint`(HDR)를
  키프레임하세요. 피격 플래시는 `_FlashAmount`(0~1)입니다. 둘 다 Animation 창에서
  `Sprite Renderer > Material._Tint`로 추가할 수 있습니다.

## 스프라이트 가져오기

- 1 unit = 1 px입니다. 새 PNG는 Texture Type `Sprite`, **Pixels Per Unit 1**로 가져오세요.
- 머티리얼은 `Assets/Materials/RetroSFSprite.mat`을 쓰면 피격 플래시와 HDR 색이 동작합니다.
- 그리는 순서: 함선 0번대, 탄 20번대, 아이템 30번대, 이펙트 40번대 (Order in Layer).

## 일시정지와 연출

- 일시정지·사망 연출 중에는 `Time.timeScale = 0`입니다.
- 일시정지 중에도 움직여야 하는 연출은 Animator의 Update Mode를 `Unscaled Time`으로 두세요
  (플레이어 사망 폭발이 그렇게 되어 있습니다).

## UI

- 화면 프리팹: `Assets/Prefabs/title/title.prefab`, `story/story_screen.prefab`,
  `character_select/character_select.prefab`, `ui/result.prefab`, 전투 UI는 `gameplay/stage/stage_01.prefab`의 `Interface`.
- 기준 해상도 1920×1080, 16:9 레터박스입니다.
- 글꼴은 `Assets/Fonts/TMP`의 TextMeshPro 폰트입니다. Stadium → SB 어그로 → Noto Sans KR 순으로
  없는 글자를 대신합니다.
- 전투 프레임 `Battle_Bg_Keyed.png`는 원본 `Battle_Bg.png`에서 흰 창을 투명하게 만든 그림입니다.
  프레임을 다시 그리면 창 부분을 투명하게 저장해 이 파일을 바꾸면 됩니다.

## 확인용 씬

- `Assets/Scenes/Main.unity`: 전체 게임
- `Assets/Scenes/StageTest.unity`: 스테이지만
- `Assets/Scenes/EnemyLab.unity`: 적 하나와 이동·공격 조합 시험
