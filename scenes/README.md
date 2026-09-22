# Scenes

기능 단위로 씬과 해당 GDScript를 함께 관리합니다.

- `main/`: 애플리케이션 진입점
- `title/`: 타이틀, 엔딩 컬렉션
- `story/`: 인트로와 엔딩의 공통 스토리 화면
- `character_select/`: 격납고, 파일럿 선택
- `gameplay/`: 게임 진행과 스테이지 구성
- `player/`: 플레이어 기체
- `enemies/`: 적과 보스
- `projectiles/`: 탄환과 공격 패턴
- `items/`: 파워업, 폭탄, 실드
- `ui/`: 초상화, 타이핑, 테마, 결과 화면

모든 화면과 기체는 편집 가능한 `.tscn`입니다. 실제 제작용 설정은 `data/`의 `.tres`에
있으며, `docs/EDITOR_GUIDE.md`에서 작업 위치와 확장 방법을 설명합니다.
