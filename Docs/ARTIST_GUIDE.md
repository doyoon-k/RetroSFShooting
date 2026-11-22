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
  클립의 Loop Time은 꺼 두세요. 켜진 채로 두면 `EffectTests`가 실패해 알려 줍니다.
- 적이 격추되면 `Assets/Prefabs/Fx/EnemyDieFx_0001.prefab`이 그 적의 몸체(그림의 불투명한 부분) 가운데에서
  한 번 재생됩니다. 적 크기와 상관없이 프리팹 크기 그대로 나오므로, 크기는 프리팹 루트의 Scale로 조절하세요.
  다른 연출로 바꾸려면 `stage_01.prefab`의 `StageController > Enemy Death Prefab`에 넣으면 됩니다.
- 큰 적은 EnemyShip의 `Break-up > Death Bursts`로 몸 여러 곳에서 연달아 터집니다. `Count`는 개수,
  `Seconds`는 첫 폭발부터 마지막 폭발까지의 시간이고 그 사이를 같은 간격으로 나눕니다. 위치는 몸의 가장자리나
  촉수 같은 얇은 곳을 피해 몸 안쪽에서 고르고, 마지막 폭발은 몸에서 가장 두꺼운 곳입니다. `Finale`만큼의 폭발이
  마지막 폭발과 동시에 터집니다. 그다음 `death` 애니메이션이 재생되고(없으면 0.5초 동안 흐려짐) 끝나면 사라집니다.
- 연쇄가 이어지는 동안 몸은 폭발마다 `Death Blink Tint` 색(기본 3·2·1, 보스 `death` 애니메이션의 가장 밝은 색)으로
  간격의 절반 동안 깜빡입니다. 흰 번쩍임은 섞지 않으며(`Death Blink White Every` 0), 격추하는 마지막 일격의
  흰 피격 번쩍임도 이때 끕니다. 깜빡임은 폭발 하나에 한 번이라 간격을 1/3초 이상으로 두면 1초에 세 번을 넘지 않습니다.
- 기본값은 실제 게임을 재서 맞췄습니다(R-Type·라이덴 II 약 2초, 도돈파치 약 5.5초, 이카루가 약 13.5초).
  보스는 12개·3.85초 + 피날레 3개, `death` 애니메이션 뒤 `StageController > Boss Clear Delay Seconds`(1초)를
  기다려 격추 약 5.3초 뒤에 SECTOR CLEAR가 나옵니다. 중간보스는 6개·1.75초 + 피날레 2개로 약 2.25초 뒤에
  사라지고, 그때까지 스크롤이 멈춰 있습니다. 그 밖의 적은 1개입니다.
- 연쇄 간격은 1/3초보다 짧게 하지 마세요. 더 빠르면 폭발이 뭉개져 보이고, 1초에 세 번 넘게 번쩍이면 광과민성
  발작을 일으킬 수 있습니다(WCAG 2.3.1). 더 짧게 넣으면 `EffectTests`가 실패해 알려 줍니다.
- 2페이즈가 있는 적(보스, 그리고 `Second Phase` 패턴을 넣은 적)은 HP가 `Phase Threshold` 아래로 내려가면
  사격을 멈추고 `Phase Break Bursts`만큼 중파 이펙트(`Assets/Prefabs/Fx/Enermy_Broken1.prefab`,
  `StageController > Enemy Damage Prefab`)가 몸 여러 곳에서 터지고 그때마다 몸이 하얗게 깜빡인 뒤
  (`Phase Break Blink White`), `Phase Break Hold Seconds`가 지나면
  2페이즈 패턴을 시작합니다. 보스 기본값은 7개·2.1초(0.35초 간격), 멈춤 2.55초로 마지막 이펙트가 끝난 뒤에
  2페이즈가 시작됩니다(라이덴 II 외장 파괴 약 1.75초, 도돈파치 부품 파괴 약 1.5초보다 조금 길게).
- 이펙트 그림이 캔버스 가운데에서 벗어나 그려져 있으면 프리팹의 `One Shot Effect > Anchor To Art`를 켜세요.
  모든 프레임 그림의 가운데가 터지는 지점에 오도록 맞춰 띄웁니다. 프레임을 바꾼 뒤에는 메뉴
  **RetroSF > Measure Effect Anchors**를 실행하세요. 실행하지 않으면 `EffectTests`가 실패해 알려 줍니다.
- 플레이어의 `Shield Effect Prefab`은 실드를 획득하면 기체를 따라 반복 재생되고, 실드가
  소모되면 즉시 사라집니다. `ShieldFx`에는 `OneShotEffect`를 붙이지 않고 Loop Time을 켭니다.
  `Power Down Effect`는 생존한 피격으로 무기 레벨이 실제로 내려갈 때 `PowerdownFX`를
  한 번 재생합니다. 두 효과는 일시정지 중에 멈추며, 동시에 재생될 수 있습니다.
- 밝게 번쩍이는 색(1보다 큰 값)은 SpriteRenderer 색 대신 머티리얼 속성 `_Tint`(HDR)를
  키프레임하세요. 피격 플래시는 `_FlashAmount`(0~1)입니다. 둘 다 Animation 창에서
  `Sprite Renderer > Material._Tint`로 추가할 수 있습니다.

## 스프라이트 가져오기

- 1 unit = 100 px입니다. 새 PNG는 Texture Type `Sprite`, **Pixels Per Unit 100**(Unity 기본값) 그대로 가져오면 됩니다.
- 인스펙터의 위치·거리·속도 값도 unit 단위입니다. 1920×1080 화면은 19.2×10.8 unit입니다.
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
- 전투 프레임 `Assets/Art/_Generated/Battle_Bg_Keyed.png`는 원본 `Assets/Art/Pilots_sprites/UI/Battle_Bg.png`에서
  흰 창과 그 가장자리의 회색, 그림에 그려진 J 배지를 투명하게 구운 그림입니다. `Battle_Bg.png`를 고친 뒤에는
  메뉴 **RetroSF > Bake Battle Frame**을 실행하세요. 굽지 않고 두면 `ScoreTests`가 실패해 알려 줍니다.
- 프레임이 투명한 왼쪽 파일럿 칸 밑에는 어두운 바탕(`RosterBacking`, 현재 파일럿 칸의 `Backing`, 색 26·23·26)이
  깔려 있어 뒤를 지나가는 적과 총알이 비치지 않습니다. 각 초상화 카드는 그 위에 `Pilot_Bg.png`를 채웁니다.
  프레임의 투명 영역을 넓히면 바탕이 그 영역을 덮는지 `HudLayoutTests`가 확인합니다.

## 점수

- 적을 격추하면 그 적의 `EnemyShip > Score Value` × 마지막 일격의 근접 배율(x1~x4)을 얻습니다. 폭탄 격추는 x1입니다.
  기본값은 자코 100, n 계열 300~500, 중간보스 5,000, 보스 20,000입니다.
- 보스를 격파해 SECTOR CLEAR가 되면 살아 있는 파일럿 수 × `Assets/Data/rules/default.asset`의
  `Clear Bonus Per Survivor`(10,000)를 더합니다. 점수는 한 번의 플레이에서 모든 파일럿이 함께 쌓습니다.
- 점수는 프레임 오른쪽 아래 점수 칸에 레퍼런스 그림대로 앞자리 0 없이 오른쪽 정렬로 표시됩니다.
  `Assets/Prefabs/ui/combat_hud.prefab`의 `ScoreBox/Score`이며, 다른 HUD 글자와 같은 Stadium 42입니다.
  `ScoreBox`는 프레임에 그려진 점수 칸(회색 테두리 안쪽 x 1478~1825, y 953~1045)과 같고, 숫자는 그 안에서
  위아래 여백이 같도록 세로 가운데(Midline 정렬, 숫자 모양 기준)에 놓이며 오른쪽 끝은 레퍼런스와 같은 x 1810입니다.
  프레임의 점수 칸을 옮기면 `HudLayoutTests`가 `ScoreBox`를 맞추라고 알려 줍니다.
  7자리가 되면 칸 안에 들어가도록 자동으로 작아집니다(`ScoreFlowTests`가 확인). 이 자리에 있던
  일시정지 버튼은 없어졌고, 일시정지는 ESC·게임패드 Start로 합니다.
- 최고 점수는 엔딩 기록과 같은 저장 파일에 남고, 최고 점수를 넘기면 결과 화면에 `NEW RECORD`가 나옵니다.

## 근접 사격 배율과 숫자 표시

`Assets/Prefabs/player/player_ship.prefab`의 `Weapon`을 선택합니다. `Proximity Tiers`는
0.8 unit(80px) 이하 x4, 1.6(160px) 이하 x3, 3.2(320px) 이하 x2이며, 마지막 거리보다 멀면 x1입니다.
거리는 각 탄의 발사점부터 실제 명중점까지이고, 정수 단계 사이를 보간하지 않습니다.

`Proximity Feedback`에 연결된 `Assets/Data/weapons/proximity_feedback.asset`을 펼치면
`Multiplier Colors` 아래의 `X1 Color`~`X4 Color`를 색상 선택기로 바꿀 수 있습니다.
모든 파일럿과 두 무기의 피격 표시·거리 가이드가 같은 설정을 사용합니다.
`Numeric Font`는 HUD 숫자와 같은 `Assets/Fonts/TMP/Stadium SDF.asset`입니다.
`Hit Label`에서 크기, 유지 시간(0.35초), 배율 변경 시 확대, 위치를 조절하고,
`Distance Guides`에서 사격 중 원호의 표시 여부와 투명도를 조절합니다.
원호는 현재 총구 기준의 가이드이며, 적 위 숫자는 실제 명중 배율입니다.
숫자는 적별 하나만 갱신하고 처치 후에도 잠깐 남습니다. 전투 일시정지 중에는 표시 시간도 멈춥니다.

## 확인용 씬

- `Assets/Scenes/Main.unity`: 전체 게임
- `Assets/Scenes/StageTest.unity`: 스테이지만
- `Assets/Scenes/EnemyLab.unity`: 적 하나와 이동·공격 조합 시험
