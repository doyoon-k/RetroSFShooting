# RetroSFShooting (Unity)

Godot 4.7 버전(이 리포지토리의 태그 `godot-final`)을 Unity 6000.1.17f1로 옮긴 버전입니다.
아티스트가 RattleBloom에서 쓰던 Animator·프리팹 작업 방식으로 연출을 다듬을 수 있도록,
게임 동작은 원본과 같게 유지하면서 그림·애니메이션을 프리팹 단위로 나눴습니다.

## 실행

1. Unity Hub에서 이 폴더를 엽니다 (Unity 6000.1.17f1).
2. `Assets/Scenes/Main.unity`를 열고 Play. 스테이지만 시험하려면 `StageTest.unity`,
   적 하나를 시험하려면 `EnemyLab.unity`.

조작은 원본과 같습니다: 이동 WASD/방향키/왼쪽 스틱, 발사 J/X, 폭탄 K/B, 무기 변경 L/Y,
일시정지 ESC/Start, 메뉴 Enter/A, 스토리 넘기기 Space/A.

## 문서

- [이식 규칙](Docs/PORTING.md): 좌표계(y 반전), 각도, 일시정지, 충돌 레이어 대응표
- [아티스트 가이드](Docs/ARTIST_GUIDE.md): 프리팹 구조, 애니메이션, 스프라이트 규칙

## 원본과의 관계

프리팹·데이터·씬은 처음 이식할 때 Godot 파일에서 한 번 변환해 만들었고, 변환 도구는 지웠습니다.
이제 이 Unity 프로젝트가 원본입니다. Godot 쪽에서 바뀐 내용은 [이식 규칙](Docs/PORTING.md)대로 손으로 옮깁니다.

Godot 버전은 같은 리포지토리의 Godot 브랜치와 태그 `godot-final`에 남아 있습니다. 이 폴더에서 Godot
브랜치로 전환하지 말고 다른 폴더로 꺼내 보세요. Windows에서는 Godot의 `assets/`와 Unity의 `Assets/`가
같은 폴더로 취급되어 섞입니다.

```powershell
git worktree add ../RetroSFShooting_Godot godot-final
```

## 테스트

Window > General > Test Runner.
- EditMode `GodotParityTests`: 원본 GDScript 공식을 그대로 계산해 Unity 쪽 결과(좌표 반전 후)와 비교
- PlayMode `StageSmokeTests`: 발진·스크롤·일시정지·폭탄·타이틀 진입
- PlayMode `ScreenCaptureTests`: 주요 장면을 `Captures/*.png`로 저장 (Godot 스크린샷과 나란히 비교용)
