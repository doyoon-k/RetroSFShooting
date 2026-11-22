# Godot → Unity 이식 규칙

원본: 같은 리포지토리의 태그 `godot-final` (Godot 4.7). 이 문서는 이식 코드가 지키는 약속이다.
동작 기준은 언제나 원본 GDScript이며, 플레이어가 느낄 수 있는 차이가 없어야 한다.

## 버전과 패키지

- Unity 6000.1.17f1, URP 2D Renderer, Input System, uGUI + TextMeshPro.
- RattleBloom과 같은 에디터 버전. 아티스트가 쓰던 Animator Controller / AnimationClip 흐름을 그대로 쓴다.

## 좌표계

| 항목 | Godot | Unity |
|---|---|---|
| 단위 | 픽셀 | 1 unit = 100 px (스프라이트 PPU 100, `G.PixelsPerUnit`) |
| Y축 | 아래가 + | 위가 + |
| 화면 | (0,0)~(1920,1080) | x 0~19.2, y 0~-10.8 |
| 카메라 | Camera2D 중심 (960+진행, 540) | Orthographic size 5.4, 위치 (9.6+진행, -5.4) |
| 각도 | 시계 방향 + (화면 기준) | 반시계 방향 + |

- 위치·방향 Vector2는 `(x, -y)`로 바꾼다. 크기(extent, padding)는 부호를 그대로 둔다.
- 원본의 픽셀 값(위치, 거리, 속도, 가속도, 선 굵기)은 100으로 나눠 unit으로 쓴다 (`G.UnitsPerPixel`).
  UI 캔버스는 그대로 1920×1080 디자인 픽셀이며, 월드↔캔버스 변환은 `G.PixelsPerUnit`을 곱한다.
- 데이터의 각도(`angle_degrees`, `aim_offset_degrees`, `rotation_per_volley`, ShotLevel `angles`)는
  부호를 뒤집어 저장한다. 그 뒤 코드에서는 Unity 각도만 쓴다.
  `Vector2.from_angle(a)` → `G.FromAngle(a)`, `v.angle()` → `G.Angle(v)`, `v.rotated(a)` → `G.Rotated(v, a)`.
- Godot `Rect2(x, y, w, h)` (y = 위쪽 모서리, 픽셀)는 `G.FromGodotRect` → `Rect(x, -(y+h), w, h) / 100`.
  원본의 `rect.position.y`(위)는 `rect.yMax`, `rect.end.y`(아래)는 `rect.yMin`.
  "위에서부터의 비율 f"는 `rect.yMax - rect.height * f`.
- `orthogonal()`은 `G.Orthogonal(v)` = `(-v.y, v.x)`. 화면에서 같은 방향을 가리킨다.
- 노드 `rotation`(라디안) → `localEulerAngles.z = -deg`.

## 시간과 일시정지

- Godot `_physics_process` → `FixedUpdate` (Fixed Timestep 1/60).
- `SceneTree.paused` → `Time.timeScale = 0` (`GamePause`). `FixedUpdate`와 scaled 시간이 멈춘다.
- Godot `PROCESS_MODE_ALWAYS` 노드의 `_process` → `Update` + `Time.unscaledDeltaTime`.
- Pausable 효과음은 `AudioListener.pause`로 멈춘다. Always 효과음과 음악은 `ignoreListenerPause`.
- Animator: 전투(Simulation) 연출은 Normal, 사망 연출 같은 Presentation은 UnscaledTime.

## 충돌

| Godot bit | Unity layer |
|---|---|
| 1 Player | 6 Player |
| 2 Enemy | 7 Enemy |
| 4 PlayerBullet | 8 PlayerBullet |
| 8 EnemyBullet | 9 EnemyBullet |
| 16 Item | 10 Item |

- Area2D → Kinematic Rigidbody2D + trigger Collider2D. 감지 처리는 Godot에서 monitoring 하던 쪽만 한다
  (탄 → 대상, 플레이어 → 적 접촉, 아이템 → 플레이어).
- 레이어 충돌 행렬: Player–Enemy, Player–EnemyBullet, Player–Item, Enemy–PlayerBullet만 켠다.

## 노드 → 컴포넌트

- 스크립트가 붙은 Area2D 루트 → 같은 이름의 MonoBehaviour (`EnemyShip`, `Projectile` …).
- 필드 이름은 GDScript export 이름의 camelCase. `*_scene` → `*Prefab`.
- `Sprite2D` → 자식 GameObject + SpriteRenderer. 아티스트가 손대는 시각 요소는 이 자식(VisualRoot 역할)에만 둔다.
- `AnimationPlayer` / `AnimatedSprite2D` → Animator + AnimatorController + AnimationClip.
- `_draw()` 예고선 → `TelegraphDrawer` (런타임 선 그리기).
- 원본의 `queue_free`는 `Destroy`, `call_deferred`는 프레임 끝 처리(`LateUpdate`) 또는 다음 FixedUpdate로 옮긴다.

## 화면

- 색 공간은 **Gamma**입니다. Godot 2D는 sRGB에서 반투명을 섞기 때문에, Linear로 두면 일시정지·사망
  어둡게 하기와 폭탄 섬광이 눈에 띄게 달라집니다. (RattleBloom은 Linear이므로 후처리 효과를 크게 쓸
  계획이 생기면 그때 다시 판단합니다.)
- Godot StyleBoxFlat(버튼·패널 배경과 테두리, 상태별 글자색)은 `UiStyleBox` + 9-slice `Border` 자식으로 옮겼습니다.
- `battle_frame.gdshader`는 `Assets/Art/_Generated/Battle_Bg_Keyed.png`로 미리 구워 두었습니다.
  같은 규칙을 `Assets/Editor/BattleFrameBaker.cs`(메뉴 RetroSF > Bake Battle Frame)가 다시 굽습니다.
- 전투 UI의 Godot z_index는 중첩 Canvas의 sorting order(1000 + z×10)로 옮겼습니다.
- 전투 프레임의 왼쪽 파일럿 칸 밑에 어두운 바탕을 깔았습니다(Godot에는 없음). 카드 사이 틈과 현재 파일럿 칸
  뒤로 게임 화면이 비치지 않게 합니다. 점수 칸에 있던 Godot `PauseButton`은 점수 레퍼런스에 맞춰 뺐습니다.

## 검증

- `GodotParityTests`: Godot 공식을 그대로 계산해 좌표·각도 변환 결과와 비교
- `StageSmokeTests`: 실제 씬으로 발진·스크롤·일시정지·폭탄·타이틀 진입 확인
- `ScoreTests`, `ScoreFlowTests`: 점수 규칙(Unity에서 추가, Godot에는 없음)·최고 점수 저장·전투 프레임 굽기·
  점수 글꼴과 위치(레퍼런스 그림 기준) 확인
- `HudLayoutTests`: 로스터가 Godot 위치에 있고 프레임의 투명한 파일럿 칸이 모두 바탕으로 덮였는지 확인
- `ScreenCaptureTests`: 주요 장면을 `Captures/*.png`로 저장. Godot 쪽은
  Godot 버전 폴더의 `build/screenshots` (`godot --path . --script tests/run_tests.gd -- --screenshots`)

## Unity에서 변경한 근접 사격

거리 배율은 기존 80px/1.6~360px/1 선형 보간에서 80px/x4, 160px/x3, 320px/x2,
그 밖 x1 정수 단계로 변경했습니다. 발사점 스냅샷과 두 무기 공유 적용은 유지합니다.
`ProximityFeedbackStyle` 공유 에셋이 네 색상과 Stadium TMP 폰트를 소유하고,
적별 `DamageMultiplierFeedback`은 같은 부모의 형제 오브젝트로 만들어 처치 후에도 유지됩니다.
표시의 이동·확대·사라짐은 scaled time과 `GamePause`를 따릅니다. 폭탄과 적탄은 배율 경로를 사용하지 않습니다.

## 아직 옮기지 않은 것

- 툴팁(`tooltip_text`): uGUI에 기본 기능이 없어 생략
- 손가락 마우스 커서(`mouse_default_cursor_shape`)
- UI `modulate` 1 초과(1.35) 밝게 하기: 기본 UI 셰이더는 1을 넘지 못함
- Godot 원본의 Python/GDScript 밸런스 측정 도구(봇 생존·화력 곡선)

## 폴더

- `Assets/Art`, `Assets/Audio`, `Assets/Fonts`: 원본 에셋 (경로 유지)
- `Assets/Scripts/<Core|Data|State|Gameplay|UI|Audio|Flow>`: 런타임 (asmdef `RetroSF.Runtime`)
- `Assets/Data`: ScriptableObject (원본 `data/*.tres`)
- `Assets/Prefabs`: 프리팹 (원본 `scenes/*.tscn`)

처음 이식할 때 쓴 일회성 변환 도구(Godot 파일 → 프리팹·데이터)는 지웠습니다. 원본에서 바뀐 내용은
위 규칙대로 손으로 옮깁니다. 데이터 값은 각도 부호(위 "좌표계")만 주의하면 그대로 옮기면 됩니다.
