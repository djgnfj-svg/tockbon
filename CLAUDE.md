# 탁본 (TAKBON) — Godot 4.7.1 · 2D 탑다운 익스트랙션 로그라이트

낮에는 숲에서 사냥하며 글자를 탁본하고, 밤에는 마법진을 손으로 그리는 게임.
1인 개발(사용자) + Claude 리드 세션 + 서브에이전트 팀으로 개발한다.

## 새 세션이 먼저 읽을 것

> 📖 **정본 = 이 파일 + `docs/STATUS.md` 최상단(직전 세션 상세) + `docs/WAND_CIRCLE.md` + `docs/PROGRESSION.md`(진행 관문표, 세58~) + memory.**
> 지금 게임 = `src/base`(베이스캠프) + 고리 조립 책 + 숲 원정 + 온보딩 레일.
> 🔴 **기록 규칙: 직전 세션만 상세, 그 전은 아래 「한 줄 지도」로 내려보낸다** — 이 절이 길어지면 정리 신호.

🔴🔴 **직전 세션 = 62 「고리 조립 책 UI 세련화 + debug_free_cast」** (정본 STATUS「62」):
사용자 *"마법진 그리는 UI 좀 세련되게 가능?"* → 3축 전부 확정(책 겉모습·그리기 연출·잔손질) → architect 설계 후 **art∥ui∥dev 3갈래 병렬**. **책 겉모습** = 신규 도트 4장(book_spread·board_paper·btn_leather 2장) + 🔴 **세21 고아 에셋 부활**(`panel_paper(_s)` 한지 9-slice — 소비자 InkStyle만 죽고 PNG는 살아 있었다) → 탭·셀·리포트 카드로 재배선. 씬 = `BookArt` 신설·`Paper`→TextureRect(노드 경로 100% 유지) · `forge_book_theme.tres`는 🔴 **색만 담고 가죽 StyleBox는 코드 exists 가드 런타임 주입**(PNG를 .tres에 물면 부재 시 리소스 통째 침묵사 — 세50 계열 원천 차단) · 전 텍스처 폴백=옛 렌더. **연출** = ring_board 렌더 절만(파티클·셰이더 0): 먹선 글로우·드러남 금빛 광점(`is_revealed` 공개 조회만)·조각색 펄스·완성 발광+호 스윕·붓끝 발광·주입 성공 금빛 — 수치 전부 const(손맛=사용자 F5, **아직 안 조임**). **잔손질** = HintLabel 잘림(3줄 감김)·팔레트 x14가 책 왼끝(16)보다 왼쪽이던 것·ScoreLabel `is_stable` 색 강조. **debug_free_cast**(사용자 요청 "테스트할 때 MP 귀찮음") = 에디터 실행이면 발사 마나 무소모, `player_caster.fire()` 한 곳만(spend_mana 무접촉), HUD "∞ (테스트)" 표기, 익스포트 항상 꺼짐.
✅ 검증: 전 스위트 22종 그린+SCRIPT ERROR 0(×3회) · 실게임 MCP 실클릭 6경로(신규 Paper TextureRect 관통 포함, coverage·acc 100%)+렌더 스샷 전부 · debug_free_cast 양방향(켬 50→50·끔 50→34) · 리뷰 치명 0. 🔴 **리뷰가 잡은 것: `"editor"` 피처는 헤드리스 `-s`에서도 켜진다** — base [7-b] "거부에 마나 안 태움"이 spend 스킵으로 자명 통과됐었다 → 테스트 셋업 `debug_free_cast = false` 가드 + 뮤테이션 재점화 실증(spend를 거부 앞으로 = 빨강).
⚠ **이번에 밟은 함정**: ① **실게임 push_input은 윈도우 좌표**(1920×1080 = 캔버스 ×2, 세58-B 재확인) — 캔버스 좌표로 밀면 절반 위치에 **에러 없이** 배달된다. 변환 = `root.get_final_transform() * (control.get_global_transform() * local)` (affine_inverse 아님 — 실측). ② GDScript는 **const에 `PackedFloat32Array(...)` 생성자를 상수식으로 안 받는다**(파스 에러).
잔여: 연출 const 손맛 F5(가이드 광점은 스틸컷에 안 잡힘 — 실게임에서만 보임) · 마나 페이스가 에디터 실플레이에서 안 보이는 트레이드오프(사용자가 끄고 싶으면 debug_free_cast 기본값 뒤집기).

🔴 **지지난 = 57** 「세피리아식 스테이지 형식 확정 + 퀘스트 은퇴 방향」(설계·결정 세션 — STATUS 항목 없음, 정본 = memory `takbon-stage-format-decision`) — 동기 = *"언제 룬을 얻을지 설계를 못 해 불안"* → 「뼈대는 확정, 살은 랜덤」. 곁가지: 밑그림 커스텀 완성본을 git stash에 보류(memory `takbon-guide-editor-stashed`) · 중첩진 architect 설계 = `scratch_nested_design.md` 대기(결정점 8개 미합의).
⏸ **보류 = forest_t2(숲2·티어 하강)** — 사용자 확정(세48): *"숲2는 아직 필요없음."* 딸린 **「하강 시 회복 스킵」도 같이 보류**(`src/field/forest.gd:131` 주석). 관문이 enemy_id 기준이라 스테이지 형식과 충돌 없음(세58).

🔴 **남은 빚** (세50~58 누적):
- 🔴 **`rune_fill`(룬 농도)의 소비자가 0곳** — "진 안에 룬을 얼마나 크게 그렸나"가 **아무 데도 안 쓰인다**. `ring_spell_system`의 주석이 *"조립 단계에서 반영돼 들어온다"*고 **거짓말을 하고 있었다**(세50에 정정). **「그리는 재미」 축이다** — 살릴지 접을지 결정 필요.
- **BOLT·EARTH·GRASS 전용 피격음이 없다**(세56) — "새 소리 = wav 한 장"(세33 방식) + audio.gd match 세 줄이면 끝. ⚠ 세61 리셋으로 그 룬들 자체가 은퇴 — **해당 룬을 복원하는 세션의 과제**로 이월.
- **취약 이중 증폭** — 반응 산물에 배수가 두 번 곱한다(세49부터라 회귀는 아님). 의도인지 사고인지 미정. ⚠ 복합 룬(중첩진 M1)이 오면 커진다 — 그때 같이 결정(`scratch_nested_design.md` ⑧-7).
- **반응 VFX 스테이지3~4 보류** — convert(진흙·산불·무성함) 플레어·DoT 불티는 틴트로 이미 어느 정도 보여 미룸(세52 설계 §5).
- **미결 결정**: D5 진 카탈로그 재구축(세61 개편 — 복원 순서·칸 차등 배치·획득 경로를 진마다 사용자가 확정) · D3 문양 게이트 · D6 흙·번개 네임드(룬 복원 순서에 종속) · 🔴 잡몹 공급원 무대 0곳. 정리는 `docs/PROGRESSION.md` 「미결」절.

**지난 세션 한 줄 지도** (상세는 STATUS/memory — 필요할 때만 캐라):
- **61** 콘텐츠 카탈로그 리셋 — 진·룬·문양 각 1종(jin_single·rune_fire·radiate)만 남기고 .tres 27장 삭제, **기계는 전량 유지**(복원 레시피=PROGRESSION.md — 진 복원 땐 glyph_slots 진마다 직접 확정) · 시드 2종(🔴문양은 해금 게이트 자체가 없다 — D3 때 스키마·판정·시드 한 세트) · 테스트=in-memory 주입으로 커버리지 유지(⚠progression·decode 스캔 그물 3곳 자명 통과 — 복원 세션이 뮤테이션 재점화) · 잔여=snake counter_rune 사장·wand_fork/ring 폴백으로 MULTI/NOVA는 진 없이도 열림·q05가 사슬 끝 (`43937c8`, memory `takbon-content-reset`)
- **60** 문양본 축을 진에 흡수(진·룬·문양 3축) — 문양본=획득 배선 0인 죽은 축이라 은퇴 · `JinDef.glyph_slots`(기본 [0..7])→`choose_jin`→`set_open_slots`→assembly.open 단일 방향(스키마 무변경=옛 도안 회귀 0, 칸 위치=발산 탄 방향으로 게임플레이 실재) · 🔴칸 각도 정본=`RingBoard.slot_angle(k)`(베끼면 조용히 어긋남) · 탭 4→3·8점 다이어그램 진 셀 이식 · 🔴실게임 MCP는 실세이브 백업→복원(세59 격리는 `-s`만) (`1aedf3f`, memory `takbon-jin-slots`)
- **59** 마법 발사 연출 개편 + 매직볼 은퇴 + 세이브 격리 — 속성형 볼(바깥 진 고정·안쪽만 _draw 자전, node.rotation 0 불변)·트레일 `carrier_trail`(🔴player_projectiles 무가입)·착탄=신규 `spell_impact`(enemy_hit 재사용은 기둥 틱 도배라 각하)·발산 탄 6/6(시트 224px+폭 가드=투명탄 침묵사 방지)·🔴매직볼 은퇴(빈 슬롯=거부+안내+마나 무소모)·`-s` 세이브 뿌리 save_test 격리 (`8aef329`, memory `takbon-spell-vfx`)
- **58·58-B** 진행 관문 + 허기 은퇴 + 세피리아식 챕터(보스방) 루프 — `DropEntry.until_unlock`(미해금=확정 드롭·해금=중단, "새 관문=적 .tres 한 줄") · 물=slime_elite·바람=gale·풀=snake_boss·earth/bolt 의도적 무경로(D6 대기) · 챕터 패널(순서 잠금 ch1~3)→`boss_room` 단칸방→클리어 codex+상자+포탈→창고("새 챕터=.tres 한 장") · 옛 숲·map_panel 삭제 · 🔴함정=①스폰 위치 대입도 add_child 앞 ②그물 이식 시 접촉 피해 채널 누락 ③클리어 판정에 룬 해금 쓰면 시드가 덮음 ④push_input 윈도우=캔버스 2배 (`e6af1eb`·`f28b66a`, memory `takbon-progression-gates`·`takbon-chapter-loop`)
- **56** gale 보스 실체화 + 반응 룬 청산 — 잠자던 params 12개 → `"ai": "boss_gale"`(hover 거리유지·돌풍 밀치기·재조준 볼리·페이즈2) · 첫 적탄 `enemy_projectile`(layer0/mask3) · 첫 밀림 `player.apply_push`(구르기 시작 시 `_push=0`) · REACTIONS `"rune"` 키로 FIRE 하드코딩 청산 · 🔴두 몸 복제 계약은 그물도 두 개(dummy 쪽 검출력 0이었다) · 이월=손맛 F5·gale FIRE 약점 의도 확인·BOLT 피격음 wav (`1cb72b3`, memory `takbon-gale-boss`)
- **53** 「대충 그려도 인정」 채점 조이기 — 정밀도 비중 50→75%·`ACC_TOL_FRAC` 0.08→0.05(`trace_scorer.gd`) · CONSIDER는 조이면 역효과(무효=공짜)라 못 건드림 · 판 위치 자유화 보류 (`c3426ee`, memory `takbon-scoring-tightened`)
- **52** 원소 반응 임팩트 VFX — 반응 위치·반경이 on_burst 콜백서 죽던 걸 EventBus(`reaction_burst`·`reaction_chain`) 방송 → `src/actors/vfx.gd`(juice 형제 공용 — 연습장·숲 파리티)가 Line2D+tween으로 그림(파티클 안 씀) · 순수 오버레이=회귀 0 (memory `takbon-reaction-vfx`)
- **55** 상자 + 능동 루팅 — `EnemyDef.drops_chest`로 낱개/상자 분기(`_die`→`_roll_drops` 추출) · `chest.gd` 자기완결(자기 zone+loot_panel 온디맨드·비면 스스로 free) · loot_panel 등급별 진행 바(`loot_card`/`advance` 공개=헤드리스 훅) · 도형 금지 첫 준수(진짜 상자 도트) · 미해결=열기 전 값어치 겉보기·루팅 손맛 (`73d91ee`, memory `takbon-chest-loot`)
- **54** 대형 뱀 보스(세그먼트 몸통) — 머리=`forest_enemy` 재사용·몸통=신설 `snake_body.gd`(부모 위치만 샘플=디커플·top_level 월드좌표) · 추종=히스토리 버퍼+머리 위브(S자) · `boss_snake` AI(위브→러시→hp절반 페이즈) · **도형 금지 규칙** 하네스에 박음(생명체·프롭=takbon-art 도트 필수) · 🔴헤드리스가 못 잡은 렌더 버그 3(마디 z·`_pop` scale·정지 뭉침, memory `takbon-snake-boss`)(`ac2e733`)
- **51** 드롭 흡수 애니메이션 — 처치→균등각 흩뿌림→**자석 반경**(fly-at-kill 각하)→가속 흡수→도착 팝+획득 토스트 · 등급색 단일소스 `grade_colors.gd`(사본 2+토스트가 3번째 될 뻔) · 자석에 물리 안 씀(그룹조회+거리) (`0c1a5bb`)
- **50** 세49 빚3 청산 — `status_power` 세기배율 통일·`status_holder` 추출·룬 획득경로 + 곁가지 둘(바람룬이 3인자 Color로 죽어 있던 것·연쇄 반경 102>90) (`7791631`)
- **49** 룬 상태이상·원소 반응 — 룬 축이 실체를 얻었다. **원칙 「단독은 약한 바탕, 조합에서 폭발한다」** · 규칙 단일 소스 `src/core/status_rules.gd`(**반응 추가 = 줄 하나**) · 룬 3→6(바람=**확산자**·흙=**취약**, 원신 Swirl/Crystallize 선례) · **룬 전용 문양 각하** → 문양6×룬6=**36조합**(어휘가 아니라 곱셈이 는다)(`0472cc3`·`c887758`)
- **48** 진 3→8종: `pattern`×`motion` 축 분리 + 진마다 다른 닫힌 밑그림(`e7674bc`)
- **47** 문양 어휘 3→6(유도·팅김·추진) — 잠들어 있던 `projectile` 효과 기계를 켠 것(`620f66d`)
- **45~46** 메인 루프: 던전 깊이 그라디언트+포털 · 바닥 드롭 픽업 · 몬스터 AI 4종 · 스프라이트/타일맵(`2c1f1ba`)
- **44** 자유도 첫 균열: 매직볼 바닥 · 관통 문양(그린 게 전투를 "종류"로) · 진=발사 형태(`632900f`)
- **41~43** 온보딩 레일 · 장비 5부위 · 퀘스트 [!] 새 목표 마크
- **34~37** 룬 해금(E4) · 마나/허기 페이스 · 퀘스트 스파인 · 빈 거점 재료 건설 + 새로하기(F8)
- **26~33** 숲 원정 · 드롭 · 잉크 경제 배선 · 적 5종 · 공방 · 사운드
- **21~25** 대청소(옛 자유드로잉·본게임 삭제) · 고리 조립 모델 · 마력 주입/등급 · 손으로 그리기 확정

🔴 **살아있는 함정** (서사는 지워도 이건 유지 — 전부 실제로 밟은 것):
- 🔴🔴 **생명체·프롭은 도형 플레이스홀더로 때우지 마라 — 진짜 도트 아트를 만든다** (세54, 사용자 확정): 새 적·캐릭터·아이템·프롭을 넣을 때 `Polygon2D`·`ColorRect` 같은 기하 도형으로 겉모습을 임시로 채우지 마라. **반드시 `takbon-art`로 도트 스프라이트를 만들어 배선한다**(머리 등 적 = `params.sprite`+`_setup_frames` 스트립, 그 외 = Sprite2D). "아트는 병렬이니 플레이스홀더로 먼저 돌린다"(drop_pickup 마름모 선례)는 **각하됐다** — 사용자가 도형 스탠드인을 싫어한다(세54에 뱀 보스가 팔각형 마디로 나가 실제로 밟았다). ⚠ **예외 = 절차적 VFX·이펙트**(`death_puff`·`vfx.gd` Line2D·진/문양 가이드선)는 애초에 스프라이트가 아니라 그림이라 도형이 맞다. 판별 기준 = "이건 도트로 그려야 할 물건인가?" → 그렇다면 **art부터 태운다**(설계·구현이 도형으로 시작하지 않는다).
- 🔴🔴 **`.tres` 한 글자가 틀리면 그 데이터는 조용히 사라진다** (세50) — `Color`를 **3인자**로 쓰면 파서가 **리소스 전체를 거부**하고 `Db`가 말없이 건너뛴다. 바람 룬이 두 세션 내내 그렇게 죽어 있었고 **전 스위트가 그린이었다**(검출력 0). ⚠ 그래서 **"파일을 만들었다"를 완료로 치지 마라 — `Db`를 거쳐 실제로 로드되는지 확인해라**(`test_decode_auto`의 「룬 6종 로드」가 그 그물이다).
- 🔴 **배선이 맞아도 「반경 밖」이면 아무 일도 안 일어난다** (세50) — 연습장 허수아비 간격 102px vs 감전 연쇄 90px라 연쇄가 **한 번도 안 터졌다**. 반경을 쓰는 기능을 붙였으면 **좌표를 실측해라**. ⚠ 씬(`.tscn`)의 `;` 주석은 **에디터가 저장하면 날아간다** — load-bearing한 설명은 코드에 둬라.
- ⚠ **없는 문제를 막다가 진짜 함정을 심지 마라** (세50) — `_exit_tree`로 콜백을 끊어 "참조 순환"을 막으려 했는데 **그 순환이 애초에 없었고**(Callable은 Node를 강참조 안 함), 대신 **리페어런팅 시 콜백이 영구히 죽는** 침묵을 새로 만들었다. 리뷰가 잡았다.
- **화면 덮는 Control엔 `mouse_filter = 2`** (세25) — 없으면 바닥이 좌클릭을 다 먹어 발사가 **에러 없이 죽는다**. 🔴 헤드리스는 못 잡음 → **실게임 `push_input`으로만** 확인된다.
- **씬끼리 PackedScene preload 금지** → `@export_file` + `change_scene_to_file` (세26) — 순환 preload가 껍데기 노드를 만들어 귀환·사망 시 못 돌아옴. 헤드리스 절대 못 잡음.
- **등급/펑 경계는 `is_stable()`을 그대로 부른다** — 65를 상수로 베끼면 갈라진다 (세24, `src/core/ring_power.gd`).
- **발사는 caster의 `to_assembly()`로만** — 직접 Dictionary를 만들면 손그림 점수가 빠져 **조용히 기준 위력**으로 나간다 (세26).
- **`wipe_save()`는 새로하기가 아니다** — 오토로드(GameState·Clock)가 메모리에 남아 귀환 한 번에 옛 진행이 되살아난다. 진짜 새로하기 = `GameState.new_game()` (세37).
- **초록불을 근거로 쓰지 마라** — 헤드리스는 클릭 도달·렌더·시간 경과를 못 잡고 `-s`는 런타임 에러가 나도 "OK"를 찍는다. **뮤테이션으로 검출력 증명 + 실게임 확인** (세22·23·25, skill `takbon-verify`).

- **docs/REFACTOR_PLAN.md** — ✅ **세션 22에 완료** (이력·판단 근거로만 참고). 「문제가 아닌 것」 절은
  아직 유효하다 — 건드리지 마라
- **docs/STATUS.md** — 세션별 진행 로그 (세션 종료 시마다 갱신). 옛 로그는 STATUS_ARCHIVE.md
- docs/BACKLOG.md(E4·E5 정본) · ART_SPEC.md(에셋·아트 방향 960×540·48px)
- ⚠ **세션 39에 옛 자유드로잉 문서 6개(TRUTH·GDD·TECH_SPEC·CHANGELOG·NEXT_CYCLE·TEAM_PLAN) 삭제** —
  삭제된 시스템 설명이라 지웠다. 고리 모델 GDD 재작성이 필요해지면 git(`98e427f`)의 옛 GDD를 참고 삼아 새로 쓴다

## 아키텍처 요약

- **진입점**: `src/base/base.tscn` (베이스캠프 — 바닥·탁본 책상·연습장·**왼쪽 숲길**). 책상 E →
  고리 조립 책 · 숲길 E → 원정 (세션 22에 `src/playground` → `src/base`로 개명 — 옛 이름이
  "버려도 되는 실험"이라 거짓 신호였다)
- **오토로드**: EventBus(시그널 허브) / GameState(자원·HP·장착·가방·도감) / Clock(낮밤 시간) /
  Db(data/ 레지스트리) / SaveManager(user://save, 자동 저장)
  - ✅ 세션 22: 옛 SpellDesign 스키마·research 경로를 **매장했다** (전엔 지우면 파싱이 깨졌다).
    `Clock`의 실질 역할 = **자동저장 틱**(day_started → SaveManager) — 죽은 코드 아님
  - ⚠ EventBus의 `extraction_success`·`bag_lost`는 **수신자만 있고 발신자가 없다** — 필드(원정)
    미구현 탓이다. 필드를 붙이는 쪽이 emit해야 하며, 안 그러면 조용히 안 돈다 (event_bus.gd 주석 참조)
- **남은 모듈**: `src/base`(베이스캠프) · `src/field`(숲 원정 — 세션 26) · `src/actors`·`src/hud`
  (**공용** — base와 field가 같이 쓴다) · `src/drawing`(고리 조립 — 아래) · `src/spell`(발사) ·
  `src/core`(리드 전용)
  - 🔴 **`src/actors` = 공용 배우** (세션 26): `player.tscn`(WASD·그룹 `"player"`) ·
    **`player_caster.gd`**(조준·발사·슬롯) · `interact_zone.gd`(책상·숲 출구·귀환 지점이 **같은
    물건** — 문구는 씬의 `Prompt.text`, 찾기는 `zone_id`).
    🔴 **발사를 복사하지 마라 — caster를 써라**: 직접 Dictionary를 만들면 `to_assembly()`가 빠져
    **손그림 점수가 조용히 사라지고 기준 위력으로 나간다**. 그래서 뽑은 것이다
  - 🔴 **`src/hud/hud.gd` = 공용 HUD** (옛 `src/base/base_hud.gd`). 씬마다 다른 건 `hint_text`·
    `show_hp` **@export 둘뿐**이라 상속하지 않았다. ⚠ 안내문에 **있지도 않은 조작을 적지 마라**
    (숲엔 책상이 없다) — 그 자체가 버그다
  - 🔴 **`src/field`**: `forest.tscn`(원정) · `forest_enemy`(쫓아와 접촉 피해).
    **적 수치는 전부 `data/enemies/*.tres`(EnemyDef) — 새 적 = .tres 한 장**이다.
    **출격 = 만HP**는 `forest.gd _ready`가 한다 (베이스가 아니다 — 다른 진입 경로로 들어가면
    조용히 달라진다). ⚠ `EnemyDef.drops`는 **아직 아무도 안 뿌린다** (BACKLOG F6)
  - `src/drawing` = **ring_assembly**(조립 상태기계·순수 데이터) · **trace_scorer**(탁본 채점·순수 수학)
    · **ring_board**(기하·렌더·입력) · ring_book · ring_forge_panel(+`.tscn` 껍데기)
    🔴 **채점(완성도·정밀도·펜 보정)을 바꿀 땐 `trace_scorer.gd`만 연다** (세션 22 분할의 이유)
  - 🔴 **점수 → 펑/위력/등급 규칙 = `src/core/ring_power.gd`** (세션 23·24). 조립 리포트(UI)와
    발사가 **같은 함수를 부른다** — core에 둔 이유가 이것이다. 복사해 두면 한쪽만 고쳐도 아무도 못
    알아채고 갈라진다(리포트는 "위력 140" 적고 130으로 때리는 식). 수치는 balance.tres
    - `grade_of`(세션 24)도 여기다. **최하단 「사용 불가」는 `is_stable()`을 그대로 부른다** —
      65를 상수로 베끼면 기준선과 갈라진다(세션 23의 「무난인데 터진다」가 정확히 그거였다).
      `is_perfect()`로 UI가 퍼펙트를 강조한다 — **등급 이름을 `==`로 비교하지 마라**
  - 🔴 **보정은 펜이 판다**: `ItemKind.PEN` → `data/items/pen_*.tres`의 `params.correction` →
    `GameState.stroke_correction()` → `ring_board._set_trace` → `trace_scorer.set_correction`.
    **새 펜 = .tres 한 장.** 맨손 = 보정 0 = 그린 대로(정체성은 기본 상태가 지킨다)
  - `src/spell` = ring_spell_system(유일한 발사 경로) · ring_carrier · projectile · pillar · dummy_target
    · ⚠ **shockwave는 지금 참조 0**이다 (세션 22에 projectile의 옛 SpellDesign 충격파 경로가 사라짐)
- 모듈 간 통신은 **EventBus 시그널 + core 스키마만**. 타 모듈 직접 preload/get_node 금지
  - 🔴 **발사 계약 = `Enums.GlyphCode`**(GATHER=0/RADIATE=1). 조립 UI·발사·`data/glyphs/*.tres`가
    이 값을 공유한다 — **밀면 저장된 고리 도안이 조용히 깨진다**
  - ⚠ 예외로 정당한 것: `base.gd`가 책 씬을 무는 것(진입 씬 = 조합 루트)
- 밸런스 수치는 전부 **data/balance.tres** (BalanceData) — 코드에 수치 금지
- typed GDScript 강제. 렌더러 Compatibility, **뷰포트 960×540**(세션 18에 640×360에서 올림, aspect=expand)

## 개발 규칙 (병렬 에이전트 운영 시)

- **git 커밋은 리드(메인 세션)만.** 에이전트는 자기 모듈 폴더 + tests/ 자기 접두사 파일만 수정
- 에이전트 새 스크립트에 **class_name 선언 금지** → `const X := preload(...)` (전역 클래스 캐시는 리드의 `--import` 때만 갱신됨)
- 에이전트는 mcp__godot__* 도구 사용 금지 (에디터는 리드가 관리)
- 스키마·시그널 추가 요청은 에이전트가 보고 → 리드가 core에 반영 (지금까지 전부 이 방식으로 처리됨)

### 🔴 하네스: 탁본 전용 에이전트 (2026-07-19 세션 39 — godot-prompter 대체, 자립형)

> **왜 만들었나:** godot-prompter 플러그인 에이전트는 제네릭 Godot만 알아서, 위임할 때마다 프로젝트
> 규칙 벽(typed·class_name 금지·EventBus·balance.tres…)을 프롬프트에 통째로 주입해야 했다 — 그러느니
> 리드가 직접 하는 게 빨라 위임이 안 굴러갔다. **이제 규칙이 에이전트에 박혀 있어 규칙 주입 없이 바로
> 위임된다.** 로컬 Donchitos 49-에이전트 하네스가 과함이었듯, 이번 하네스도 **린하게** 유지한다
> (오케스트레이터·에이전트 팀 격식 없음).
>
> 🔴 **자립형이다 — godot-prompter 플러그인은 껐다**(`.claude/settings.json`에서 제거). 제네릭 스킬을
> `.claude/skills/`로 **복사**해서 플러그인 없이 돈다(스킬은 disk에 있어도 트리거될 때만 로드돼 안 쓰면 무해).
> ✅ **세션 39 정비: 처음 51개 전부 가져왔다가, 구조적으로 무관한 8개를 삭제해 43개로 줄였다**(+takbon 2개=45).
> 삭제 기준 = **2D·GDScript·데스크톱 확정으로 쓸 일이 없는 것**(3d-essentials·csharp-*·gdextension·
> xr-development·mobile-development·using-godot-prompter·godot-project-setup). **멀티(basics/sync)·
> dedicated-server·beehave·limboai·localization은 「휴면 방향」으로 남겼다** — 사용자가 멀티·다국어·BT
> 보스 AI를 아직 안 접었기 때문(삭제=방향 포기 신호라). 되돌리려면 이 커밋 직전 git 이력.
>
> 🔴 **세션 39: 제네릭 43개 SKILL.md를 한국어로 번역했다 = 상류(godot-prompter)와 「관리된 갈라짐」.**
> 번역 사본이라 상류(`jame581/GodotPrompter`, 현재 `1.11.0`)와 어긋나므로, `.claude/skill-vendor/`가
> 그 갈라짐을 **관리**한다(막지 않는다): ① `upstream-1.11.0/` = 번역 당시 영어 원본 박제본(diff 기준,
> 에이전트가 로드 안 함) · ② `VERSION` = 번역 기준 버전 · ③ `check-upstream.sh` = **한 달에 한 번**
> 돌려 상류 버전이 올랐는지·어느 스킬이 바뀌었는지 출력. 코드 블록·`name:`은 번역 안 함(코드는 상류
> 대조용 원문, name은 호출 키). 상세 = `.claude/skill-vendor/README.md`.
> 🔴 **references(심화문서 150개)는 삭제했다** (사용자: *"깔끔하게 관리"*) — 각 스킬 폴더가 SKILL.md
> 한 장씩만 남아 트리가 깨끗하다. 본문의 "→ references 보라" 죽은 링크도 정리. **영구 손실 아님**:
> 영어 전문이 `skill-vendor/upstream-1.11.0/`(diff 박제본)와 상류 github에 그대로 있어 언제든 복구.
> 즉 심화 레시피가 필요하면 그 두 곳에서 꺼내 온다 — skills/ 트리에만 안 둔다.

- **위임 대상 (`.claude/agents/`):** 핵심 = `takbon-dev`(구현) · `takbon-architect`(설계) ·
  `takbon-reviewer`(리뷰) · `takbon-ui`(패널·모달·HUD) · `takbon-art`(도트 스프라이트). 가끔 =
  `takbon-shader`(2D 셰이더 효과) · `takbon-animator`(스프라이트 애니 배선) · `takbon-profiler`(성능 진단) ·
  `takbon-tools`(에디터 플러그인·@tool). 다들 `.claude/skills/takbon-rules`(아키텍처·계약)와
  `takbon-verify`(검증 규율)를 읽고, 제네릭 Godot
  지식은 로컬 복사한 제네릭 스킬 43개(`gdscript-patterns`·`animation-system`·`physics-system`·`godot-ui` 등)를
  Skill 도구로 부른다. 규칙 충돌 시 탁본이 이긴다.
  - 🔴 **기능 지식은 에이전트가 아니라 스킬에 있다** — 애니/물리/셰이더 등을 만들 때 `takbon-dev`가
    해당 스킬(`animation-system`·`physics-system`·`shader-basics`…)을 읽고 짠다. 그래서 스킬을 다 가져온
    것이다. `takbon-dev.md`의 스킬 매핑에 어느 작업에 어느 스킬을 부를지 전부 적혀 있다.
- 🔴🔴 **기본이 위임이다** (2026-07-20 세션48에 사용자가 예외 목록을 걷어냈다). 그전엔
  *"회귀 위험이 크고 tight한 검증 루프가 필요한 작업·core 스키마 변경·mcp__godot·커밋은 리드가 직접"*
  이라 적혀 있었는데, **이 프로젝트의 재밌는 작업은 죄다 발사·저장·core에 닿아서 거의 매번 예외에
  걸렸다** — 위임 대상으로 남는 게 주변부뿐이라 하네스가 안 굴러갔다. 사용자 의도(세션48):
  *"기획을 처음에 빡세게 잡고 가고 싶고, 코드의 퀄리티를 신경쓰고 싶어."* **위임은 손을 던다기보다
  설계·리뷰 단계를 강제해 품질을 올리는 장치다.**
- **기본 파이프라인:** `takbon-architect`(설계 먼저 — 씬 트리·시그널·데이터 흐름) →
  `takbon-dev`/`takbon-ui`/`takbon-art`(구현) → `takbon-reviewer`(커밋 전 리뷰).
  큰 기능은 **설계를 먼저 받아 사용자와 합의하고** 구현에 넘긴다 — 코드부터 얹지 마라.
- 🔴🔴 **에이전트에게 「보고서를 파일로 써라」고 지시해라** (2026-07-20 세션49에 알아냄).
  **채팅으로 낸 최종 보고는 리드에게 안 온다** — 세48~49에 `jin-ui`·`jin-tests`·`jin-shapes`·
  `status-design` 네 번이 전부 idle 알림만 오고 **내용이 증발했다**(리드가 매번 `git diff`로
  역추적해야 했다). 반면 *"`scratch_<이름>.md`를 리포 루트에 써라"*고 지시한 `status-core`·
  `rune-data`는 **멀쩡히 도착했다**. ⚠ 특히 **`takbon-architect`·`takbon-reviewer`는 산출물이
  보고서뿐이라, 파일로 안 시키면 작업 전체가 사라진다.** 읽고 나면 리드가 scratch 파일을 지운다.
- 🔴 **리드가 절대 안 놓는 것 = 검증과 커밋** (위임하는 게 아니라 리드의 직무다):
  검증·`--import`·커밋(`takbon-verify` = 위 검증 명령). **에이전트의 "그린 나왔습니다"를 근거로
  쓰지 마라** — 리드가 직접 돌리고 뮤테이션으로 검출력을 확인한다.
- ⚠ **에이전트에 뮤테이션을 시킬 땐 원상복구까지가 지시다.** 세션48에 `_scaled`가 뮤테이션 중간
  상태로 잠깐 남았다(에이전트가 복구해 사고는 안 났다). `src/`를 되돌린 채 두면 **기능이 조용히
  죽은 채 커밋된다** — 이 프로젝트가 제일 무서워하는 실패 방식이다. 리드는 커밋 전 `git diff`로
  본다.

**하네스 변경 이력:**
| 날짜 | 변경 | 대상 | 사유 |
|------|------|------|------|
| 2026-07-19 | 초기 구성 | agents/takbon-{dev,architect,reviewer} · skills/takbon-{rules,verify} | godot-prompter가 제네릭이라 위임 시 규칙 주입 비용이 커 위임이 안 굴러감 |
| 2026-07-19 | UI·아트 에이전트 추가 | agents/takbon-ui(패널·mouse_filter 함정) · agents/takbon-art(aseprite 함정·아트 방향) | 탁본이 실제로 쓰는 영역(패널 천지·직접 스프라이트 제작) 커버 |
| 2026-07-19 | 자립형 전환 · 플러그인 끔 | 제네릭 스킬 26개 `.claude/skills/`로 복사 · settings.json에서 godot-prompter 제거 · 에이전트 참조를 로컬 이름으로 | 오버레이가 플러그인에 묶여 있어 플러그인을 끄면 참조가 끊김 → 자립형으로 |
| 2026-07-19 | 스킬 전체(51) 복사 + dev 매핑 완성 | 나머지 25개 스킬 복사(총 51) · takbon-dev 스킬 매핑에 animation/physics/camera/player 등 추가 | 사용자 걱정: "애니 등 만들 때 스킬 안 쓸까 봐" → 기능 지식=스킬이므로 전부 확보 + 에이전트가 부르게 매핑. 노이즈 정비는 추후 |
| 2026-07-19 | 나머지 에이전트 탁본화(총 9) | agents/takbon-{shader,animator,profiler,tools} 추가 | 사용자 "만들어만 둬줘". csharp만 제외(GDScript 전용 규칙과 충돌). 원본 복사 아닌 규칙 주입 재작성 |
| 2026-07-19 | 스킬 노이즈 정비 51→43 | 삭제 8: 3d-essentials·csharp-godot·csharp-signals·gdextension·xr-development·mobile-development·using-godot-prompter·godot-project-setup · takbon-dev 매핑·「휴면 방향」주석 갱신 | 2D·GDScript·데스크톱 확정으로 구조적 무관만 삭제. 멀티·dedicated-server·beehave·limboai·localization은 사용자가 방향을 안 접어 유지(삭제=방향 포기 신호) |
| 2026-07-19 | 제네릭 43개 SKILL.md 한국어 번역 + 벤더링 | skills/*/SKILL.md 본문 번역(references·코드블록·name은 원문) · 신설 `.claude/skill-vendor/`(영어 1.11.0 박제본+VERSION+check-upstream.sh) | 사용자 요청 한국어화. 상류와 갈라지므로 「관리된 갈라짐」 채택 = 월간 대조로 상류 변경분만 반영 |
| 2026-07-20 | 위임 예외 목록 걷어냄 · 파이프라인 기본화 | CLAUDE.md 「개발 규칙」 | 사용자 세48: *"기획을 처음에 빡세게 잡고 가고 싶고, 코드의 퀄리티를 신경쓰고 싶어."* 옛 예외("회귀 위험·core 스키마·mcp__godot·커밋은 리드")가 너무 넓어 재밌는 작업이 죄다 예외에 걸려 위임이 안 굴러갔다 |
| 2026-07-20 | 🔴 보고서는 **파일로** 지시 | 위임 프롬프트 규약 | 세48~49에 채팅 보고 4건이 **증발**(idle 알림만 옴) · 파일로 시킨 2건은 도착. architect·reviewer는 산출물이 보고서뿐이라 치명적 |
| 2026-07-21 | 🔴 **도형 플레이스홀더 금지** 규칙 박음 | CLAUDE.md 살아있는 함정 + skills/takbon-rules §0 + agents/takbon-{architect,dev} | 사용자 확정(세54): 뱀 보스가 Polygon2D 도형으로 나감. 설계·구현이 "아트 병렬이니 도형으로 먼저"(drop_pickup 마름모 선례)를 관행처럼 써왔는데 **하네스 어디에도 금지 규칙이 없어** 재발. 이제 생명체·프롭 = takbon-art 도트 스프라이트 필수(VFX·가이드선은 예외) |
| 2026-07-19 | references 심화문서 150개 삭제 | skills/*/references/ 40폴더 + godot-testing 최상위 참조 2개 삭제 · 본문 죽은 링크 정리 | 사용자 "깔끔하게 관리". skills/ 트리를 SKILL.md 한 장씩만 남김. 영어 전문은 skill-vendor 박제본+상류 github에 있어 영구 손실 아님(복구 가능) |

## 검증 명령 (반드시 Bash에서 — PowerShell은 자식 프로세스 stdout을 안 보여줌)

**전 스위트를 다 돌려라.** 목록에서 빠진 테스트는 낡아 죽는다 — 실제로 세션 7이 문법을 바꾸면서
`test_paper_auto`(8건)와 `test_drawing_canvas_auto`(1건)가 목록에 없다는 이유로 **조용히 깨진 채
방치됐다** (세션 8에 발견·복구).

```bash
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_save_auto.gd            # 저장/로드 (고리 라운드트립) · 🔴**부팅만으로 자동 저장이 준비되나**(세션 26 F3 — 이 확인은 `load_game()` **호출 전**에 있어야 한다. 순서가 곧 검출력이다)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_assembly_auto.gd   # **조립 상태기계 계약**: 단계 전이·🔴**진이 칸을 여는 규칙**(세션60 — JinDef.glyph_slots→choose_jin, Db 진 로드 그물 포함 — 세61 리셋 후 기대치=**정확히 1종**)·assembly 발사 계약·시그널·다이어그램 기하(slot_angle)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_trace_auto.gd      # **손그림 탁본**: 완성도/정밀도·[다음] 수동 진행·칸 자유 편집·I3 · **정밀도 이빨(⑨⑩)·펜 보정(⑪⑫)**
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_spell_auto.gd      # **고리 발사**: 진→투사체·착탄 전개(발산 탄환·응집 기둥)·실제 적 take_hit
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_design_auto.gd     # **고리 도안 통합**: RingDesign 라운드트립·ring_design_committed→GameState 자동 장착 · **등급⇔펑 경계·퍼펙트⇔화면100** (세션 24)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_base_auto.gd            # **베이스캠프 발사 배선** (세션 24): 과녁 사거리 · 🔴**물리 레이어 계약**(내 몸/책상이 world면 진이 총구에서 죽는다 — 에러 없이 조용히) · [8] 숲길
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_chapter_auto.gd        # **챕터 보스방 루프** (세션58-B — 옛 test_forest_auto의 그물을 이식·계승): 챕터 3장 Db 로드+order+클리어 키 파생 · 🔴**보스 스폰 두 경로**(범용 forest_enemy·전용 씬 — 두 경로 각각 뮤테이션 검출 확인, 세56 교훈) · 출격 만HP · 🔴**적 레이어 계약**(4=enemy) · 처치→chapter_clear codex+포탈 스폰(처치 전 부재) · 포탈 연타 1회 extraction+가방→창고 · 사망→bag_lost+창고 보존 · 🔴**잠금 판정 = chapter_panel 공개 `is_chapter_open`을 직접**(복사 금지) · 미등록 챕터→빈 방 금지·베이스 복귀(⚠ [8]의 USER ERROR 한 줄은 의도된 것 — SCRIPT ERROR와 다르다) · 끝에 wipe_save() 뒷정리 · 🔴**Ground 클릭 도달·패널 카드 클릭·포탈/상자 렌더는 헤드리스가 못 잡는다**(새 씬+새 패널 = 세25 함정 정확히 그 자리 — 실게임 MCP 필수)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_workshop_auto.gd      # **공방 장비 제작** (세션 32): 레시피 station 분리(정제대⇔공방) · 펜 제작(spend→add) · 장착 라운드트립(equip→correction 0.35→소비, unequip→반환) · 🔴**패널 클릭은 헤드리스가 못 잡는다**(실게임 push_input로 별도 검증)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_audio_auto.gd         # **사운드 배선** (세션 33): 17 SFX 로드·길이>0 · Audio가 EventBus 9종에 연결 · 발신→올바른 스트림(부작용 순간은 연결만) · 🔴**소리가 실제로 나는지는 헤드리스가 못 잡는다**(오디오 드라이버 없음 — 버스 라우팅·playing은 에디터 실게임 exec로 별도 검증)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_decode_auto.gd        # **탁본 해독** (세션 34 E4 · 세61 수술): 조각 소비+룬 해금(codex_unlocked)·안 닳림 — **조각이 은퇴해 in-memory RuneDef+ItemDef 주입으로 기계를 잰다**(뮤테이션 검출 확인) · 룬 로드 = 정확히 1종(주입 잔류 감지 겸용) · ⚠ unlock_id 오타·순수확률 조각 스캔 그물은 지금 자명 통과 — 조각 복원 시 자동 가동(뮤테이션 재점화 확인) · 🔴**룬 탭 렌더·클릭은 헤드리스가 못 잡는다**(실게임 확인)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_quests_auto.gd        # **진행 목표(퀘스트)** (세션 36): KILL/EXTRACT/UNLOCK 배선(enemy_died·extraction·codex_unlocked → advance_quests) · 🔴**requires 사슬 게이트**(잠긴 퀘스트는 이벤트로도 안 진행) · 보상 지급 · 🔴**소급 완료**(이미 해금된 룬 노리는 UNLOCK은 열리는 순간 완료 — 안 하면 사슬이 막힌다) · 저장 라운드트립 · 🔴**Q 패널 렌더·클릭 차단은 헤드리스가 못 잡는다**(전체화면 Control — 닫힘=발사 도달·열림=차단을 실게임 push_input으로 별도 확인, 액션 주입으론 못 잡는다)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_dialogue_box_auto.gd  # **온보딩 대사 상자** (세션41): open(lines)→줄 넘김→finished · 빈 배열 즉시 finished · ESC 건너뛰기 · ui_modal_open 토글 · 🔴**클릭 진행·하단 밴드 렌더는 헤드리스가 못 잡는다**(실게임 push_input·스샷으로 별도 확인)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_hud_toast_auto.gd     # **HUD 획득 토스트** (세션51): 같은 id 합치기(수량+수명 리셋) · 🔴**합친 줄은 맨 뒤로 이동**(안 하면 FIFO가 **방금 주운 줄**을 밀어낸다 — 시각이 아니라 버그) · 최대 3줄 FIFO · 수명 만료 · 🔴**보이는지·슬롯/막대와 겹치는지는 헤드리스가 못 잡는다**(MCP 스샷으로 별도 확인)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_drop_pickup_auto.gd   # **바닥 드롭 픽업 + 자석 흡수** (세션46·51): setup→그룹 · 줍기 지연(지연 중 무시) · body_entered→add_to_bag+queue_free · 🔴**layer0/mask2 계약**(캐리어가 픽업에 안 부딪히게) · 🔴**자석**(반경 안이면 거리 단조감소·밖이면 정지·지연 뒤에만·**켜지면 취소불가**·도착 1회 뱅킹·item_collected 1회) · 🔴**null 가드 없으면 SCRIPT ERROR 36줄 내면서 OK 찍힌다**(grep 필수) · 🔴**반경 72px가 체감되는지·속도가 "빨려온다"로 읽히는지는 헤드리스가 못 잡는다**(실게임 좌표 실측 — 세50 감전연쇄 재발 자리)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_enemy_ai_auto.gd      # **몬스터 AI** (세션46): 방어(armor_reduction→enemy_hit dealt 경감) · 재생(regen_per_sec, 상한 _def.hp) · 분산 경감 · 🔴**돌진/부유 움직임 "느낌"은 헤드리스가 못 잰다**(실게임 runtime_state로 속도파형·거리유지 별도 확인)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_status_auto.gd        # **룬 상태이상·원소 반응** (세션49): 화상 DoT·젖음 감속·🔴**반응**(젖음+흙=진흙·젖음+번개=감전연쇄·화상+물=꺼짐·화상+풀=산불)·🔴**바람=확산**(자기 상태 안 남기고 옆 적에게 옮김)·중첩=갱신(누적 아님)·취약 증폭 · 🔴**DoT는 enemy_hit을 안 쏜다**(쏘면 피해숫자·히트스톱 도배) · 🔴**색으로 보이는지는 헤드리스가 못 잡는다**(실게임 _visual.modulate로 별도 확인)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_snake_boss_auto.gd    # **뱀 보스** (세션54 A): Db 로드(hp600·boss_snake) · take_hit→약점배율 · hp절반→페이즈2 전이(공개 `phase()`) · 세그먼트 몸통(마디 12==SEGMENT_COUNT·머리 이동→마디 추종) · 위브 추격 전진 · 🔴**세그먼트 물결·러시 채찍·머리 회전 "느낌"은 헤드리스가 못 잡는다**(실게임 확인) · 🔴**뮤테이션(페이즈·위브·추종) 검출력 확인됨**(세54)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_chest_auto.gd         # **상자 + 능동 루팅** (세션55 = 세54 세션B): `EnemyDef.drops_chest` Db 로드(snake_boss=true·vine=false) · 🔴**`_die` 분기**(drops_chest 적→상자1·픽업0 / 잡몹→픽업·상자0) · loot_panel(`loot_card`→`advance` 완료 = add_to_bag+item_collected+**contents 참조 remove_at**+비면 자동 닫힘) · 🔴**상자 통합**([E] interacted→패널→다 루팅→상자 스스로 free) · 🔴**카드 클릭 도달·진행 바 렌더·상자 스프라이트는 헤드리스가 못 잡는다**(실게임 MCP push_input·스샷 — 세55에 전 루프 확인) · 🔴**뮤테이션 3/3 검출력**(분기·remove_at·상자소멸)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_progression_auto.gd   # **진행 관문** (세션58, 정본 docs/PROGRESSION.md · 세61 수술): 적 Db 로드(세50 파싱 침묵사 그물) · 🔴**미해금=확정 드롭·해금=중단 — 관문 데이터가 은퇴해 in-memory DropEntry를 slime_elite에 주입해 기계를 잰다**(뮤테이션 검출 확인·[4]의 관문 수==0이 주입 누수 감지기 겸용) · 🔴**불변식(순수 확률 fragment 0곳·관문 수==표 줄 수)은 스캔형 유지 — 지금 관문 0줄이라 자명 통과, 관문 복원 시 자동 가동**(그 세션에서 뮤테이션 재점화 확인 + 관문 수 기대치 갱신) · 허기 잔재 0 · ⚠[2] 확정드롭은 chance 1.0이라 관문 판정 뮤테이션을 못 잡는다 — 검출자는 [3](해금=중단)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_gale_boss_auto.gd     # **gale 보스** (세션56): Db 로드+**params 17키 전수**(세50 그물) · 페이즈2 전이(`phase()`) · 돌풍(플레이어 hp 감소+`apply_push` 밀림 거리≈gust_push_dist) · 볼리(그룹 `"enemy_projectiles"` 수 ==volley_count — 초과도 잡음) · 적탄(히트→hp 감소+free·수명 만료 free — mask2 침묵 함정 그물) · 🔴**반응 룬**(연쇄=BOLT·증기=WATER — FIRE 하드코딩 청산 직접 그물. 연습장 몸 쪽은 test_status_auto [11]ⓑ가 잰다 — **두 몸은 따로 갈라진다**, 세56에 dummy만 되돌려도 전 스위트 그린이었다) · 🔴**링·탄 렌더·밀림 손맛·hover 거리감은 헤드리스가 못 잡는다**(세56 실게임 MCP로 링·탄 렌더 확인, 손맛=사용자 F5) · 🔴**뮤테이션 4/4 검출력**(페이즈·rune 두 몸 각각·볼리)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_spell_vfx_auto.gd     # **마법 연출 배선** (세션59): vfx가 `ring_cast_requested`·`spell_impact`에 연결(배선 침묵사 그물) · 트레일 형제 스폰 + 🔴**`player_projectiles` 그룹 무가입**(트레일이 가입하면 탄 수 세는 테스트 4곳이 거짓으로 는다) · 트리 밖 setup 무에러(null 가드 — ⚠ 이 항목의 진짜 검출자는 **SCRIPT ERROR grep**이다, 테스트는 가드가 없어도 OK를 찍는다) · 🔴**빈 진 착탄 = emit 정확히 1**(캐리어 emit 전용 그물 — 발산 탄이 있으면 캐리어 emit 부재가 가려진다, 뮤테이션으로 실증) · 발산 진 착탄 ≥2(탄 emit) · 🔴**볼 코어·자전·펄스·트레일·머즐/착탄 렌더는 헤드리스가 못 잡는다**(실게임 MCP 필수)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_book_jin_auto.gd # **책 진 셀 격자·아이콘** (세61에 목록 편입 — 세션7 함정「목록에서 빠진 테스트는 낡아 죽는다」의 그 자리에 있었다): Db 진 ≥1종 · 격자 계약 = 합성 8개(순수 함수 `jin_cell_rects` — 카탈로그 1종이면 cols=1이라 폭 비교가 무의미해져 합성으로 잰다) · 아이콘 구분 = pattern×motion 조합 합성 순회 · 🔴**실제 셀 겉보기·클릭은 헤드리스가 못 잡는다**(실게임 확인)
```

✅ **세션59: 스위트가 실제 세이브를 못 건드리게 격리했다.** `SaveManager`가 `-s` 부팅(헤드리스
테스트)을 감지하면 세이브 뿌리를 `user://save_test`로 가른다 — 세션26 F3 이후 스위트의 자동
저장·`wipe_save()`가 진짜 플레이 세이브를 덮고 지워서 **스위트 한 번에 타이틀 「이어하기」가
사라졌다**(사용자가 실제로 밟음: *"자꾸 없어지네"*). 이제 테스트의 `wipe_save()`는 테스트 세이브만
지우는 뒷정리다(관행 유지 — test_save_auto·test_chapter_auto). 격리 그물 = `test_save_auto [0]`
(-s 부팅이면 `save_root()`에 save_test — 격리 로직이 지워지면 이게 빨개진다, 뮤테이션 확인됨).
실측: 실세이브 마커 md5 유지한 채 세이브 만지는 테스트 3종 통과(세션59). ⚠ 실게임(F5·에디터
run·익스포트)은 -s가 없어 예전 경로 그대로 = 세이브 호환 무변경.

🔴 **`-s` 테스트는 런타임 에러가 나도 "OK"를 찍을 수 있다.** 세션 22에 실제로 겪었다 —
`test_ring_trace_auto`가 내부 필드(`_slots`)를 더듬다가 리팩터로 그게 옮겨가자 에러로 함수가
**중단**됐는데 `failures=0`이라 통과로 보였다. **grep을 `_OK`만 하지 말고 `SCRIPT ERROR`도 같이 봐라.**
그리고 **테스트는 공개 API로만 검증해라** — 내부 필드는 리팩터 때 옮겨 다니는 물건이라 계약이 아니다.
⚠ **세션 23에 재발했다** (`test_ring_spell_auto`가 내부 `_deploy_now`를 옛 인자 수로 호출) —
같은 함정이 두 세션 연속 나왔다. 그리고 `test_ring_trace_auto`의 `_check`는 **실패할 때만 출력**해서
**침묵이 곧 통과**다 — 함수가 죽어도 조용하다.

🔴🔴 **그래서 초록불을 근거로 쓰지 마라 — 뮤테이션으로 검출력을 증명해라.** 고친 코드를 일부러
되돌려 **정확히 몇 개가 실패하는지** 확인한다. 세션 22·23이 전부 이 방식으로 잡았다.
실제로 세션 23의 기존 테스트 하나(`정밀도 < 0.8`)는 **옛 관대한 판정도 통과**해 검출력이 0이었다.

🔴 **balance 수치를 런타임에 흔들어 규칙을 검증할 수 없다** (세션 24에 알아냈다). GDScript는
static 함수 안의 **`const BAL.프로퍼티`를 컴파일 타임에 굳힌다** — `RP.BAL.ring_stability_min`을
0.8로 바꿔도 `RP.threshold()`는 **0.65를 돌려준다**(같은 인스턴스인데도. 실측 확인).
게임엔 무해하지만(수치를 런타임에 안 바꾼다) **테스트는 조용히 거짓 통과한다.**
→ 대신 **두 함수의 경계가 어긋나지 않는지 전 구간을 훑어라** (`test_ring_design_auto`의
「「사용 불가」⇔펑」이 그 방식이고, 뮤테이션으로 검출력을 확인했다).

🔴 **채점 수치는 헤드리스로 못 검증한다.** 테스트가 가이드 좌표를 그대로 찍으면 이탈이 0이라
**판정 반경을 뭘로 바꾸든 정밀도 100**이다 — 그린 게 아니라 아무것도 안 잰 것이다.
손맛은 **사용자가 마우스로 직접 그려 봐야** 정해진다(리드의 흔들림 시뮬레이션도 시뮬레이션이다).

🔴 **세션 21 대청소로 목록이 이만큼 줄었다.** 옛 자유 드로잉·옛 본 게임과 함께 그 테스트들도 지웠다.
**되돌리려면 git 이력**(삭제 직전 커밋 = `dcc3326`).

눈으로 보는 시험대(F6):
- `tests/test_ring_forge_panel.tscn` — 책 펼침(진→룬→문양을 손으로 따라 긋기 — 칸은 고른 진이 연다, 세션60) + 덮고 발사.
  조작: **오른쪽 셀 클릭=진·룬·문양 고르기**(세션 25에 Q·W 키 폐지) · 왼쪽 판에 손으로 긋기
  (**여러 획 OK** · **우클릭=다시 그리기** · 휠=크기) · ESC=덮기 · WASD·마우스=조준 · R=리셋 · E=책
  ⚠ 시험대는 Space도 발사로 받는다 — **시험대 사정이고 본 게임은 좌클릭만**이다(사용자 확정)
- `tests/test_ring_forge.tscn` — 칸 클릭 조립 **프로토타입**. ⚠ 본 게임과 **분리된 실험 씬**이고
  팔레트도 다르다(응집◎/확산✳/발산→). 기준 아님 — 헷갈리면 위쪽을 봐라.

**그냥 실행(F5) = 베이스캠프** (`src/base/base.tscn` = `run/main_scene`): WASD로 책상에 가서 **E** →
고리 조립 책 → **오른쪽에서 고르면 왼쪽에 밑그림이 뜨고**(세션 25 — 진·룬·문양 칸 전부 같은 규약)
그 위를 손으로 긋는다 → **[분석 ▶]** → 리포트에서 **[마력 주입]**(65점 이하면 펑). 맺으면 점수를
실은 채 `GameState.ring_designs`로 들어가 첫 빈 슬롯에 자동 장착된다.
⚠ **[분석 ▶]은 맺지 않는다** — 맺는 건 [마력 주입]이다. 세션 25까지 이 버튼 이름이 "맺기 (분석)"이라
누른 사람이 맺힌 줄 알고 책을 덮었다. 미달이라 안 맺히면 HUD가 이유를 띄운다(`commit_rejected`) —
**조용히 거부하지 마라**: 슬롯이 빈 채로 남으면 "맺었는데 안 나간다"가 된다.
✅ **세션 24: 베이스캠프에서 쏜다** — 책상 옆이 **연습장**(허수아비 5). 마우스=조준 ·
**좌클릭=발사**(🔴 Space 아님 — 사용자 확정) · **1~4=슬롯** · HUD가 슬롯 4칸(위력·점수)을 보여 준다.
쏘는 건 `GameState.ring_equipped[슬롯].to_assembly()` — **`to_assembly()`를 써야** 손그림 점수가
실려 그때 그 위력이 난다(직접 Dictionary를 만들면 score가 빠져 조용히 기준 위력이 된다).
✅ **세션 26: 왼쪽 숲길에서 E = 원정** — 숲(슬라임 7)에서 같은 조작으로 싸우고, **들어온
자리(남쪽)로 돌아가 E**를 누르면 귀환한다. 죽으면 0.9초 뒤 그냥 베이스로 (벌 없음).

🔴🔴 **헤드리스는 「클릭이 닿는다」도 모른다** (세션 25에 뼈아프게 배웠다). 사용자가 *"마법진이 다
그려져도 발사가 안됨"*이라 했는데 **전 스위트가 그린이었다**. 원인은 `Ground`(화면을 다 덮는
ColorRect)의 `mouse_filter`가 기본값 **STOP**이라 바닥이 좌클릭을 전부 먹은 것 —
`_unhandled_input`에 안 와서 `_fire()`가 아예 안 불렸다. **에러도 경고도 없다.**
리드의 검증이 전부 `_fire()` **직접 호출**·`attack_basic` **액션 주입**이라 **Control 계층을
건너뛰어** 두 세션을 못 잡았고, `push_input`으로 테스트를 새로 써도 **헤드리스에선 그냥 통과했다**
(렌더가 없어 Control 히트 테스트가 실제와 다르다). **에디터로 띄운 실제 게임에서만 0회→1회로
재현됐다.** → **마우스가 닿는 경로를 바꿨으면 `godot_exec`로 실제 게임에 
`viewport.push_input(InputEventMouseButton)`을 밀어 확인해라.** 액션 주입은 이 버그를 못 잡는다.

🔴 **이건 베이스만의 얘기가 아니다 — 새 씬을 만들 때마다 되살아난다.** 세션 26에 숲 Ground의
`mouse_filter = 2`를 빼 보니 **실제 게임에서 발사 0회**였고, 그때도 **헤드리스 전 스위트는
그린이었다**(신규 `test_forest_auto` 포함). **화면을 덮는 Control을 새로 깔았으면 `mouse_filter = 2`를
적었는지 확인하고 실제 게임에서 클릭을 밀어 봐라.**

🔴 **헤드리스는 "존재"만 확인하고 "보인다"는 못 본다** (memory `takbon-mcp-visual-verify`).
렌더·레이아웃을 건드렸으면 **에디터로 띄워 스샷으로 확인해라** — 세션 22의 `ring_board` 분할과
책 씬화(I5)는 테스트가 전부 그린이어도 스샷으로 최종 확인했다(둘 다 픽셀 동일).

**알려진 함정**: `-s` SceneTree 테스트 스크립트는 오토로드 전역 등록 전에 컴파일된다 — 오토로드 식별자(EventBus 등)를 컴파일 타임 참조하면 에러. `root.get_node("/root/EventBus")` 런타임 조회 + 모듈 스크립트는 첫 프레임 후 `load()` 지연 로드로 우회 (기존 테스트 파일들 참고).

**Godot 에디터 노이즈**: 에디터 자체의 split_container.cpp 인덱스 에러는 Godot 4.6 에디터 버그 — 게임 문제 아님, 무시.

## 에디터·MCP

- godot-mcp 애드온 설정됨 (.mcp.json). 에디터 실행: `Start-Process .\Godot_v4.7.1-stable_win64.exe -ArgumentList "--editor","--path","."`
- project.godot을 파일로 수정한 후에는 `godot_project check_stale` → 필요시 에디터 restart
