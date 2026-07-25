# 탁본 (TAKBON) — Godot 4.7.1 · 2D 탑다운 익스트랙션 로그라이트

낮에는 숲에서 사냥하며 글자를 탁본하고, 밤에는 마법진을 손으로 그리는 게임.
1인 개발(사용자) + Claude 리드 세션 + 서브에이전트 팀으로 개발한다.

## 새 세션이 먼저 읽을 것

> 📖 **진실원 = `docs/GDD.md`** — "게임이 무엇인가"(비전·코어 재미·마법 모델·축·루프·아트)의 단일 정본.
> 🔴🔴 **GDD는 사용자의 명시적 허락 없이 수정 금지** (settings.json `ask` 규칙이 매 수정에 허락 프롬프트를 띄운다).
> 나머지 정본은 역할별: 이 파일(아키텍처·함정·검증) · `docs/STATUS.md` 최상단(직전 세션 상세) ·
> `docs/PROGRESSION.md`(진행 관문표, 세58~) · `docs/takbon-design/`(진행 중·대기 설계) · memory(세부 이력).
> 지금 게임 = `src/base`(베이스캠프) + 고리 조립 책 + 숲 원정 + 온보딩 레일.
> 🔴 **기록 규칙: 직전 세션만 상세, 그 전은 아래 「한 줄 지도」로 내려보낸다** — 이 절이 길어지면 정리 신호.

🔴🔴 **직전 = 82 「M3 ①: 문양 효과·표현 데이터화 + 응축」** (정본 STATUS「세션 82」 · 설계 `docs/takbon-design/glyph_data_design.md` · memory `takbon-glyph-data-driven`):
사용자 *"m3 진행하자"* → `takbon-design`으로 대화. M3 세 덩어리 중 **문양 어휘 확장**을 골랐는데, 사용자가 *"토대를 깔고 싶은거긴한데 **그래야 니가 하드코딩을 안해서** 문양도 하나씩 생각해서 추가하고 싶고"* → **어휘를 늘리기 전에 토대부터**로 방향 확정.
🔴 **리드의 첫 판단이 틀렸고 사용자 논거가 이겼다**: 리드는 "새 문양 추가 비용 5곳→3곳이라 이득이 작다"고 데이터화를 **말렸는데**, 사용자가 말한 건 비용이 아니라 **작업 규율**(토대가 없으면 리드·에이전트가 문양을 늘릴 때마다 분기를 흩뿌린다 = 이 프로젝트가 반복해 밟은 실패). 비용 계산으로 반박할 수 있는 게 아니었다.
🔴 **응축이 그 논거를 즉시 실증**: 사용자가 확정한 셋(확산·폭발·**응축**) 중 응축을 실측하니 폭발과 ①위력 합산 ②위치 평균이 **똑같고** ③반경 비례만 뒤집힌다 → 옛 구조면 `_explode`를 복사한 `_condense`가 생겼다. 지금은 **같은 `blast` 알고리즘 + 부호만 뒤집은 `.tres` 한 장**.
**한 일** (6단계, 각 단계 끝마다 전 스위트): ①`GlyphDef.behavior`+`params` + `.tres` 8장(**누락돼 있던 `gather` 보충** + 잠든 4종을 **데이터만**=획득경로 0) ②`Db._glyph_by_code`/`reindex_glyphs`/`modifier_codes` + `GlyphRules`(**Db 무참조 순수 static 표** — `GlyphDef`를 받는다) ③발사가 `behavior`로 분기·`_spread`/`_explode`가 `params`를 받음·`BOLT_EFFECTS` 은퇴·balance 7필드 이사 ④`Enums.MODIFIER_GLYPHS`·`is_modifier_glyph` **은퇴**(계열은 문양 데이터의 성질이지 enum의 성질이 아니었다)·`RingDesign.has_modifier_glyph` **주입형** ⑤`RingBoard.GLYPH_NAMES`·`GLYPH_COLORS` **은퇴** — 이름·색 정본이 `.tres`로(사용자 질문 *"UI나 진 미리보기…직접적으로 디테일을 잡을 수 있게 되어있니?"*의 답이 **"문양은 아니다"**여서 범위에 편입) ⑥**응축**(`CONDENSE=8`·나선 밑그림·`.tres` 2장·시드).
✅ 검증: 전 스위트 **27종** 그린+SCRIPT ERROR 0(신설 `test_glyph_data_auto` 12항목) · 🔴 **뮤테이션 9/9 검출+원상복구**. 회귀 근거 = 기존 4종 `params`를 `balance_data.gd` 기본값과 **같은 리터럴로** 채워 계산이 비트 동일.
🔴🔴 **뮤테이션이 초록불로는 못 볼 것 셋을 잡았다**: ①**그물 구멍** — 초안 그물이 `_spread`/`_explode`를 **직접** 불러 `_apply_layer`의 계열 분기를 한 번도 안 지났다(behavior를 통째로 `bolt`로 돌려도 **전부 그린**) → 「폭발 칸만 있는 층 → `blast` 1개」로 메움 ②**죽은 코드** — 설계에 넣은 `Db.glyph_behavior()`가 **소비자 0**이라 뒤집어도 아무도 안 빨개짐 → 삭제 ③**뮤테이션 설계 자체의 검출력** — code 중복은 **주입 순서를 사전순과 갈리게** 넣어야 잡히고, 반경 클램프는 **두 인자를 동시에** 벗겨야 부호 구멍이 뜬다.
🔴 **함정(밟음)**: 발사부에서 `RingAssembly.GLYPH_NONE`(drawing의 class_name)을 참조하자 **`-s`가 전역 클래스 캐시 갱신 전에 컴파일해 파일 전체가 파싱 실패** → **스위트 7종이 한 번에 빨감**. → 빈 칸은 **`g < 0` 음수 판정**(문양 code는 늘 0 이상).
🟢 **architect 리뷰가 치명 3 + 중요 10 + 사소 7을 라이브 코드로 잡아 전량 반영**: ①`MODIFIER_GLYPHS` 소비자를 1/4만 셌다(core `RingDesign`은 Db를 못 본다 — 그 파일이 자기 주석에 세 번 경고) ②code 2~5에 `.tres`가 없어 `test_ring_spell_auto`가 죽는다("26종 그린" 전제가 거짓) ③"코드 2곳"이 실제 5곳 — 배열 미갱신이 **응축을 골랐는데 폭발 밑그림**을 띄운다 ⑨**심장 그물이 심장 뮤테이션을 못 잡는다**(부호 뒤집어도 66.96<73.44라 그린 → **단조성**으로 교체).
**결과 = 새 문양 추가가 5곳→2곳**(`Enums` 값 + 밑그림 갈래) + `.tres`. 밑그림이 남는 건 **의도**(손이 문양을 기억하는 게 코어 재미).
⚠ **F5 미확인**: 응축 나선을 **손으로 그을 만한가**(폭발·유도와 손이 갈리나) · 응축이 **「집중 한 방」으로 보이나**(아니면 그냥 약한 폭발 → 연출 분기 신호) · 책에서 폭발과 구분되나.
🔴 **다음 = 문양을 하나씩 추가**(사용자 방식 — 대화로 하나 확정 → `.tres`+밑그림). 남은 M3 덩어리 = 문양 2층 점유(스키마 필요) · 진 규칙 데이터화(**규칙이 융합 하나뿐이라 아직 이르다**). 딸린 미결 = 번개·흙·풀 룬 복원 + 임시 시드 획득 경로.

🔴 **지지난 = 81 「진별 해석 M2 — 룬 2개 + 융합진」** (정본 STATUS「세션 81」 · 설계 `docs/takbon-design/jin_interpretation_design.md`「M2 확정 설계」 · memory `takbon-jin-fusion-m2`):
사용자 *"M2 시작"* → `takbon-design`으로 결정점 6개를 대화로 닫고 구현. **진의 씨앗이 룬 하나 → 룬 목록**이 됐다. 첫 진 = **융합진**(`jin_fuse`): 두 룬을 한 발에 실어 명중 시 두 속성 → 기존 원소 반응(`status_rules`)이 그대로 터진다. M1(`폭발(확산(불))`) 위에 「어떤 둘을 붙이느냐」가 얹혔다.
🔴 **대화가 코어 재미 축을 다시 못박음**(사용자): *"그리는게 맞다"*(탁본 유지, 조립식은 먼 여지) · *"2겹 긋기 지겹다"* → **M2 하드 제약 = 긋는 양이 곱으로 안 늘게, 층은 공용**(룬 2개여도 밴드 그대로) · **둘 다 0.7씩 피해(합 1.4)**.
🔴🔴 **architect 리뷰가 심장 주장 3개를 라이브 코드로 반박 → 전부 닫음**(설계할 때 놓친 것): ① 내가 *"잠든 rune_hits 채우면 적 계약 무변경"*이라 적었는데 **거짓** — `take_hit`이 0-피해에도 무조건 `enemy_hit`·팝을 쏜다(`projectile.gd` 주석부터 거짓, 잠든 기계라 안 밟혔다) → **적 계약(`forest_enemy`·`dummy_target` take_hit)에 「직격 0이면 발신·손맛 스킵, 상태만」 가드** 신설(회귀 위험 커 뮤테이션 필수). ② 반응이 **룬 자리 순서 의존**(물→번개=감전 / 번개→물=무반응, `REACTIONS` 비대칭) → `status_rules.order_for_reaction`(바탕 남기는 룬을 primary로 정렬)로 제거. ③ 내가 사용자 *"0.7씩"*을 *"보조 피해 0"*으로 **조용히 재해석**(하네스가 경계하는 그 패턴을 리드가 저지름) → 재확인으로 **둘 다 0.7씩** 원복.
**한 일**(리드 = core·발사·저장·적 계약 / takbon-dev 위임 = 조립 UI·밑그림): 스키마 `JinDef.rune_slots`(기본 1)·`RingDesign.runes`+`runes_of()` 승격(M1 `layers_of` 선례)·`RingAssembly` 자리별 룬 목록·`balance.multi_rune_share=0.7` · 발사 `ring_spell_system` 룬 목록 스레딩(`_on_ring_cast`→carrier `bind`→`_deploy_now`→`_fire_hit`)이 **두 룬 피해 primary에 합산**+`rune_hits`+반응 정렬, 캐리어·기둥·폭발 모두 이식 · UI(위임) 룬 소켓 2칸(밴드 소켓 미러링)·밑그림 룬 좌우(`rune_slot_positions`·자리1 픽셀 무회귀) · `jin_fuse.tres`+임시 시드.
✅ 검증: 전 스위트 **26종** 그린+SCRIPT ERROR 0(신설 `test_jin_fusion_auto` 34항목) · 🔴 **뮤테이션 7/7 검출+원상복구**(0-피해 가드 dummy·forest_enemy 각각 / rune_hits 안 채움 / 정렬 헬퍼 / share 1.0 / pillar·blast 이식 / runes_of 승격). 🔴 회귀 근거 = **룬 1개 = share 1.0 + rune_hits=[primary] 하나라 옛 계산 완전 동일**. `test_status_auto[1]`을 **forest_enemy 0-피해 가드 그물로 전환**.
🔴 **함정(밟음)**: `_deploy_now` 인자 `rune_type: int`→`runes: Array`로 바꾸자 **기존 테스트 18곳이 옛 정수 인자로 직접 호출**해 `Invalid cast`(세23 재발) → `1.0, 1.0, 0)`→`[0])` 일괄 수정 · **0-피해 take_hit을 상태 적용 관용구로 쓰던 테스트**(test_status_auto 등)가 새 가드와 충돌(has_status는 살고 enemy_hit 기대만 정정).
✅ **F5 확인됨(사용자 *"잘되네"*)** + **후속 UI 3건 커밋**(`55913d1`): ①밑그림 이음선(거미줄) 제거(`glyph_ring_pts`가 밴드 모티프를 한 서브패스에 몰아 draw_polyline이 이었다=M1부터 잠재 → `glyph_ring_subpaths`, flat 무변경) ②그릴 때 층 구분 동심원 숨김(`enter_combined_trace(show_band_lines)` — ASSEMBLE만) ③문양-고리 목록 휠 스크롤(책 넘침). 🔴 **게임 UI 반응은 물+불=증기뿐** — 번개·흙·풀 룬 데이터 없음(세61 리셋). 융합 *기계*는 번개로도 됨(테스트 증명, 반응이 rune 타입에 키됨). ⚠ **2겹 긋기 지겨움 소감은 미수집**(잘된다까지만).
🔴 **다음 = M3** (설계 문서 「M3 착수 킷」에 실측 지도) — 세 덩어리(문양 어휘 확장·문양 2층 점유·진 규칙 데이터화), 서로 독립이라 조각으로. **추천 = 어휘 확장 먼저**("새 변형형=3곳" 레시피 존재). 2층 점유는 스키마 필요, 데이터화는 규칙 2개+ 생긴 뒤. 딸린 미결 = 번개·흙·풀 룬 복원 + 임시 시드 획득 경로.

🔴 **지지난 = 57** 「세피리아식 스테이지 형식 확정 + 퀘스트 은퇴 방향」(설계·결정 세션 — STATUS 항목 없음, 정본 = memory `takbon-stage-format-decision`) — 동기 = *"언제 룬을 얻을지 설계를 못 해 불안"* → 「뼈대는 확정, 살은 랜덤」. 곁가지: 밑그림 커스텀 완성본을 git stash에 보류(memory `takbon-guide-editor-stashed`) · 중첩진 architect 설계 = `docs/takbon-design/nested_design.md` 대기(결정점 8개 미합의).
⏸ **보류 = forest_t2(숲2·티어 하강)** — 사용자 확정(세48): *"숲2는 아직 필요없음."* 딸린 **「하강 시 회복 스킵」도 같이 보류**(`src/field/forest.gd:131` 주석). 관문이 enemy_id 기준이라 스테이지 형식과 충돌 없음(세58).

🔴 **남은 빚** (세50~58 누적):
- 🔴 **`rune_fill`(룬 농도)의 소비자가 0곳** — "진 안에 룬을 얼마나 크게 그렸나"가 **아무 데도 안 쓰인다**. `ring_spell_system`의 주석이 *"조립 단계에서 반영돼 들어온다"*고 **거짓말을 하고 있었다**(세50에 정정). **「그리는 재미」 축이다** — 살릴지 접을지 결정 필요.
- **BOLT·EARTH·GRASS 전용 피격음이 없다**(세56) — "새 소리 = wav 한 장"(세33 방식) + audio.gd match 세 줄이면 끝. ⚠ 세61 리셋으로 그 룬들 자체가 은퇴 — **해당 룬을 복원하는 세션의 과제**로 이월.
- **취약 이중 증폭** — 반응 산물에 배수가 두 번 곱한다(세49부터라 회귀는 아님). 의도인지 사고인지 미정. ⚠ **세81 M2 융합진이 흙을 포함하면 한 발에 닿는다**(지금까지는 취약+반응을 두 발 필요) — 발생 빈도가 오른다. 살릴지/자를지 M3에서 룬 복원과 같이 결정.
- **반응 VFX 스테이지3~4 보류** — convert(진흙·산불·무성함) 플레어·DoT 불티는 틴트로 이미 어느 정도 보여 미룸(세52 설계 §5).
- **미결 결정**: D5 진 카탈로그 재구축(세61 개편 — 복원 순서·칸 차등 배치·획득 경로를 진마다 사용자가 확정) · D3 문양 게이트 · D6 흙·번개 네임드(룬 복원 순서에 종속) · 🔴 잡몹 공급원 무대 0곳. 정리는 `docs/PROGRESSION.md` 「미결」절.

**지난 세션 한 줄 지도** (상세는 STATUS/memory — 필요할 때만 캐라):
- **80** M1 F5 확인(*"이거 되긴하네"*) + 세74~78 미커밋 잔재 4커밋 청산 · 🔴실측 = 두 순서 총 세기 1.53 동일(순서는 세기 아닌 「모양」만 바꿈) (정본 STATUS「세션 80」)
- **79** 진별 해석 **M1 — 층(밴드) 순서 = 연산 순서** 구현(확산=복제산개·폭발=융합광역, 🔴폭발 반경∝안쪽 갈래 수가 **순서를 눈에 보이게 하는 자리**) · `flatten_bands`만 걷어 층 유지 → **스키마 변경 0·캐리어 무변경** · 씨앗(감쌀 게 없으면 룬 자체를 감싼다) · 곁가지 = Tab 「마법진」 탭(순서 신호 4중) · 🔴함정=정규화가 **진입점 두 곳** 다 필요·빈 밴드도 층 자리를 지켜라 (정본 STATUS「세션 79」, memory `takbon-jin-layers-m1`)
- **78** 진별 해석 **설계** 확정(룬을 문양이 겹겹이 감쌈=연산순서·여러 룬은 진마다 bespoke 규칙으로 합침·🔴진 등급=층 수, 상한 9) + 워터볼·윈드볼·시작 3볼 퀵슬롯 + design 문서 전량 교차감사(README 재인덱싱·낡음 스텁 5개) (memory `takbon-jin-interpretation-model`·`takbon-elemental-balls`)
- **77** 오블리크 파이어볼 — 방향별 발사체 아트 불필요(회전이 커버)·높이감=**바닥 그림자**(shadow.gd 재활용)·착탄 두 겹(바닥 데칼+솟는 플레어) (`e9a777f`, memory `takbon-oblique-fireball`)
- **76** 플레이어를 penzilla 후드 캐릭터로 교체(🔴출시 전 $2 결제·크레딧 의무) · 런타임은 **2방향(좌/우)**이지 4방향 아님 (memory `takbon-hood-player-penzilla`·`takbon-player-2-direction`)
- **75** 멀티 방향 은퇴(스킬 36→33) · **74** "켜봐"=게임 독립 실행(에디터 아님) · **73** 화면 깊이=밝게 유지+PointLight2D 빛 웅덩이만 (`8a08d25`, memory `takbon-lighting-depth`)
- **72** 마법 발사 재정의 — **마법진=수식(안 날아감)·해석된 원소 마법이 나간다**(진이 날아가던 모델 은퇴) (`285a9b8`, memory `takbon-interpreted-magic`)
- **71** 🔒`docs/GDD.md` 신설+수정 잠금 · 기획은 리드가 `takbon-design`으로 **대화하며** 확정(서브에이전트는 혼자 정해 부적합) · `docs/takbon-design/` 보관소 (memory `takbon-gdd-truth-source`·`takbon-design-dialogue`)
- **70** 조립→탁본 최소 슬라이스(문양-고리 조립→합성 밑그림→**통째** 트레이스→플래튼 발사) — 🔴 이 세션의 밴드가 세79 M1의 토대가 됐다 (memory `takbon-assemble-trace-slice`)
- **69** 스프라이트 입체화 relight 45장(🔴재익스포트하면 음영 침묵 원복) · **68** 조립→탁본 **모델 설계**(파밍한 문양-고리를 진 층에 조립) · **67** 죽은 코드·에셋 청산 · **66** 도파민 설계+마법사 학교 마을 (memory `takbon-sprite-relight`·`takbon-assemble-trace-model`·`takbon-dead-code-cleanup`·`takbon-dopamine-loop`·`takbon-school-village`)
- **65** 세피리아식 떠있는 지팡이 — 완드를 손에서 떼어 몸 옆 둥둥·조준 회전·🔴**총구 단일 소스 `muzzle_position()`**(지오메트리 복제 금지)·맨손이면 숨고 몸 중심 캐스팅 · 🔴실수=실게임 `new_game()`이 실세이브를 덮음(**저장 건드리기 전 무조건 백업**) (memory `takbon-floating-wand`)
- **64** HUD 정리(좌상단 HP·마나·슬롯 진 다이어그램·C 상태창·슬롯 4→3) — 조작 hint_text 통째 제거(온보딩이 조작 가르침)·HP/마나 숫자 막대 안+🔴HP 늘 그림(show_hp 폐지=씬별 HUD 차이 0)·슬롯=진 미니 다이어그램(`RingBoard.jin_slot_dots` 재사용, 각도 베끼지 마라)+선택만 상세·톤 책 UI 통일·C 상태창(tab_panel 「캐릭터」 탭+우하단 사람 실루엣 아이콘=mouse_filter IGNORE 클릭 안 받음)·"그려 장착" 2줄 겹침 수정(caster notice 제거)·슬롯 4→3 (`e288810`, memory `takbon-hud-cleanup`)
- **63** 손맛·아트 개편 — 히트 플래시 셰이더(`hit_flash.gdshader` mix-to-white, modulate 곱셈은 어두운 픽셀이 안 하얘짐) + 🔴modulate 소유권 3파전 청산(팝·텔레그래프가 셰이더 uniform으로 이사 → modulate=rgb 틴트·a 분산 2축만)·🔴함정 둘(셰이더 TEXTURE 직접 샘플 금지·ShaderMaterial per-instance=공유하면 전원 플래시)·피격 애니(`EventBus.player_hurt` 단일 발신+사망 가드·플레이어 시트 144×192 오른쪽 덧대기=기존 좌표 불변·보스 `params.hurt_sprite`)·그림자(`shadow.gd` forest_enemy 자동 부착·z≥0)·먼지(`dust.gd` juice 형제)·카메라(trauma²+킥 5px+발사 반동 2px) · 🔴실게임이 잡은 것 2(그림자 로브 가림·먼지 뭉개짐 — 테스트 전부 그린이었다) (`1c4d995`, memory `takbon-hit-feel-overhaul`)
- **62** 고리 조립 책 UI 세련화 + debug_free_cast — 양피지 책·한지 카드(세21 고아 에셋 부활)·가죽 버튼(테마는 색만+StyleBox 코드 주입 — PNG를 .tres에 물면 침묵사)·그리기 연출(전부 ring_board _draw const, 손맛 F5 대기)·debug_free_cast(에디터=마나 무소모·HUD ∞ 표기) · 🔴push_input=윈도우 좌표(캔버스 ×2)·`"editor"` 피처는 헤드리스에서도 true(자명 통과 함정)·const에 PackedFloat32Array 생성자 불가 (`807e172`, memory `takbon-forge-book-ui`)
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

- **docs/GDD.md** — 🔒 게임 정체성 진실원 (사용자 허락 없이 수정 금지 — 세71 신설)
- **docs/STATUS.md** — 세션별 진행 로그 (세션 종료 시마다 갱신)
- docs/BACKLOG.md(E4·E5 정본) · ART_SPEC.md(에셋·아트 방향 960×540·48px) · PROGRESSION.md(관문표) · ONBOARDING_FLOW.md(온보딩 레일)
- ⚠ **세71에 죽은 문서 삭제**: `STATUS_ARCHIVE.md`(옛 자유드로잉 세대 로그) · `REFACTOR_PLAN.md`(세22 완료 —
  「문제가 아닌 것」 유효 판단은 이 아키텍처 절과 memory에 흡수됨). 필요하면 git 이력.
- ⚠ **세39에 옛 자유드로잉 문서 6개(TRUTH·GDD·TECH_SPEC·CHANGELOG·NEXT_CYCLE·TEAM_PLAN) 삭제** —
  삭제된 시스템 설명이라 지웠다. (세71에 신설한 GDD.md는 고리/조립→탁본 모델의 새 진실원이다.)

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
    **`player_caster.gd`**(조준·발사·슬롯) · **`floating_wand.gd`**(세65 — 세피리아식 떠있는
    지팡이. `equipment[WAND]` 있을 때만 표시, 옆에 둥둥+조준 회전. 🔴 **발사 총구 = 지팡이 끝
    `muzzle_position()`** 단일 소스, caster가 부른다 — 없으면 몸 중심 폴백) · `interact_zone.gd`(책상·
    숲 출구·귀환 지점이 **같은 물건** — 문구는 씬의 `Prompt.text`, 찾기는 `zone_id`).
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
    · ⚠ **shockwave는 세67에 삭제됐다** (세22부터 참조 0인 죽은 파일 — pillar는 ring_spell_system._spawn_pillar가 직접 생성)
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
> xr-development·mobile-development·using-godot-prompter·godot-project-setup). 🔴 **세75에 멀티
> 방향을 접었다 — `multiplayer-basics`·`multiplayer-sync`·`dedicated-server` 3개 삭제**(사용자 확정:
> *"멀티 안하기로하자"*). **beehave·limboai·localization은 「휴면 방향」으로 유지** — 사용자가 다국어·BT
> 보스 AI는 아직 안 접었기 때문(삭제=방향 포기 신호라). 되돌리려면 git 이력.
>
> 🔴 **세션 39: 제네릭 SKILL.md는 한국어로 번역돼 있다** — 상류(`jame581/GodotPrompter`, 번역 기준 `1.11.0`)의
> 번역 사본이다. 코드 블록·`name:`은 원문 유지(name은 호출 키). ⚠ **세71에 `.claude/skill-vendor/`
> (상류 대조용 박제본+check-upstream.sh)를 제거했다** — 상류와 계속 맞추지 않기로 함(사용자 확정). 즉
> 이 스킬들은 이제 상류를 따라가지 않는 **탁본 로컬 포크**다. 영어 원본이 필요하면 상류 github에서 꺼낸다.
> 🔴 **references(심화문서 150개)도 삭제했다** (사용자: *"깔끔하게 관리"*) — 각 스킬 폴더가 SKILL.md
> 한 장씩만 남아 트리가 깨끗하다. 본문의 "→ references 보라" 죽은 링크도 정리. 심화 레시피가 필요하면
> 상류 github에서 꺼내 온다.

- 🔴 **기획은 에이전트가 아니라 리드가 한다** — 새 기능·시스템·콘텐츠는 리드가 `takbon-design` 스킬을
  켜서 **사용자와 대화하며** 확정한다(한 번에 질문 하나·2~3안+추천·섹션별 승인·하드게이트·scratch 착지).
  서브에이전트는 대화를 못 해 혼자 정하므로(사용자가 싫어함, 세71) 기획을 위임하지 마라. memory `takbon-design-dialogue`.
- **위임 대상 (`.claude/agents/`):** 핵심 = `takbon-dev`(구현) · `takbon-architect`(**확정 설계 리뷰·기술 설계** —
  게임 방향은 안 정함) · `takbon-reviewer`(리뷰) · `takbon-ui`(패널·모달·HUD) · `takbon-art`(도트 스프라이트) ·
  `takbon-relight`(스프라이트 입체화 — 세69 relight). 가끔 = `takbon-shader`(2D 셰이더 효과) ·
  `takbon-animator`(스프라이트 애니 배선). 다들 `.claude/skills/takbon-rules`(아키텍처·계약)와
  `takbon-verify`(검증 규율)를 읽고, 제네릭 Godot
  지식은 로컬 복사한 제네릭 스킬 36개(`gdscript-patterns`·`animation-system`·`physics-system`·`godot-ui` 등)를
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
| 2026-07-24 | 🔴 **기획 스킬 `takbon-design` 신설 + architect 역할 재정의** | skills/takbon-design(신설) · agents/takbon-architect | 사용자: architect가 **혼자 정해 생각과 다르게** 나옴 → 서브에이전트는 구조상 대화 불가라 대화형 기획엔 부적합. 게임 방향(무엇/왜/재밌게)은 **리드가 `takbon-design`으로 사용자와 대화하며 확정**(한 번에 질문 하나·2~3안+추천·섹션별 승인·하드게이트·scratch 문서 착지), architect는 **확정된 설계를 받아 훑는 리뷰어**로 재정의(방향 뒤집기 금지). superpowers `brainstorming` 스킬의 탁본판. 구현 계획서 단계는 안 넣음(설계→dev 직행, 사용자 확정) |
| 2026-07-24 | **슬림화: 에이전트 9→7 · 제네릭 스킬 43→36** | 삭제 agents/takbon-{profiler,tools} · 삭제 skills 7(responsive-ui·multithreading·ai-navigation·ability-system·assets-pipeline·export-pipeline·procedural-generation) · takbon-dev 매핑 갱신 | 사용자 "슬림화 해줘". description은 매 세션 상주 로드라 안 쓰는 걸 줄이면 실익. 삭제 기준 = 2D 싱글 데스크톱 로그라이트 형식상 안 쓰는 순수 기술 스킬(방향 신호 아님) + profiler(성능 이슈 0회)·tools(에디터 툴링 거의 안 씀). 필요 시 git 복구·dev가 스킬 직접 로드. ⚠ 방향 신호 6(멀티×2·dedicated-server·beehave·limboai·localization)은 이번엔 유지 |
| 2026-07-24 | **입체화 에이전트 `takbon-relight` 신설** | agents/takbon-relight(신설) · agents/takbon-art(입체 규율 포인터) | 사용자: 스프라이트를 "하앙 입체적으로". 세69 relight 기법(`tools/relight_sprites.lua`·실루엣 재조명·건물 기준)을 전담 에이전트로. 방식 A(기존 PNG 후처리) + B(신규를 처음부터 입체). 🔴🔴 재익스포트 시 음영 침묵 원복 함정 내장. art는 신규를 입체로 그리고 큰 입체화는 relight에 위임 |
| 2026-07-24 | **기획 문서 보관소 `docs/takbon-design/` 신설** | 루트 scratch 설계 7개 이동(scratch_ 접두어 제거)·보고 3개 삭제·README 인덱스·takbon-design 스킬 착지 경로 변경·memory/CLAUDE.md/STATUS/PROGRESSION 살아있는 참조 갱신 | 사용자: 기획 문서를 리포 루트 흩뿌림 말고 영구 폴더에. 앞으로 `takbon-design`이 `docs/takbon-design/<주제>_design.md`로 착지. 구현 보고·리뷰는 여전히 일회성 루트 scratch(반영 뒤 삭제). ⚠ 이미 삭제된 옛 scratch 로그 참조(STATUS의 school_village·jin_slots 등)는 과거 기록이라 안 건드림 |
| 2026-07-24 | **`.claude/skill-vendor/` 통째 제거** | skill-vendor 폴더(upstream-1.11.0 박제본 43+VERSION+check-upstream.sh) 삭제·CLAUDE.md 「관리된 갈라짐」 서술 정리 | 사용자 확정: 상류(godot-prompter)와 계속 맞추지 않기로 함. 번역 스킬은 이제 상류 추종 안 하는 **탁본 로컬 포크**. 영어 원본이 필요하면 상류 github에서 꺼냄(세39 번역 이후 상류 대조를 실제로 돌린 적 없어 무게만 됐다) |
| 2026-07-24 | 🔴 **단일 진실원 `docs/GDD.md` 신설 + 수정 잠금** | 신설 docs/GDD.md(안정된 진실만) · settings.json `ask` 잠금 · WAND_CIRCLE.md 은퇴 스텁 · CLAUDE.md 정본 포인터 단순화(5곳→GDD 헤드) · memory 주 정본 갱신 | 사용자: "진실원(GDD)을 두고 허락 받아야 수정하게, 문서가 많아서". 진실이 5곳(CLAUDE.md·STATUS·WAND_CIRCLE·PROGRESSION·memory)에 흩어져 있던 걸 GDD가 "게임이 무엇인가"의 단일 정본으로 흡수. 잠금 = settings.json `Edit/Write(docs/GDD.md)=ask`(매 수정에 허락 프롬프트). 세39에 지운 옛 TRUTH.md의 부활 격 |
| 2026-07-25 | 🔴 **멀티 방향 은퇴 · 스킬 36→33** | 삭제 skills 3: multiplayer-basics·multiplayer-sync·dedicated-server · 「휴면 방향」 서술 갱신 | 사용자 확정(세75): *"멀티 안하기로하자"*. 세39·세73에 「방향 신호」로 일부러 남겨뒀던 멀티 3종을 방향 자체를 접어 삭제(삭제=방향 포기 신호). beehave·limboai·localization은 아직 유지. 게임은 2D 싱글 데스크톱 로그라이트로 확정. 되돌리려면 git 이력 |

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
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_progression_auto.gd   # **진행 관문** (세션58, 정본 docs/PROGRESSION.md · 세61 수술): 적 Db 로드(세50 파싱 침묵사 그물) · 🔴**미해금=확정 드롭·해금=중단 — 관문 데이터가 은퇴해 in-memory DropEntry를 slime_elite에 주입해 기계를 잰다**(뮤테이션 검출 확인·[4]의 관문 수==0이 주입 누수 감지기 겸용) · 🔴**불변식(순수 확률 fragment 0곳·관문 수==표 줄 수)은 스캔형 유지 — 지금 관문 0줄이라 자명 통과, 관문 복원 시 자동 가동**(그 세션에서 뮤테이션 재점화 확인 + 관문 수 기대치 갱신) · 허기 잔재 0 · ⚠[2] 확정드롭은 chance 1.0이라 관문 판정 뮤테이션을 못 잡는다 — 검출자는 [3](해금=중단)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_gale_boss_auto.gd     # **gale 보스** (세션56): Db 로드+**params 17키 전수**(세50 그물) · 페이즈2 전이(`phase()`) · 돌풍(플레이어 hp 감소+`apply_push` 밀림 거리≈gust_push_dist) · 볼리(그룹 `"enemy_projectiles"` 수 ==volley_count — 초과도 잡음) · 적탄(히트→hp 감소+free·수명 만료 free — mask2 침묵 함정 그물) · 🔴**반응 룬**(연쇄=BOLT·증기=WATER — FIRE 하드코딩 청산 직접 그물. 연습장 몸 쪽은 test_status_auto [11]ⓑ가 잰다 — **두 몸은 따로 갈라진다**, 세56에 dummy만 되돌려도 전 스위트 그린이었다) · 🔴**링·탄 렌더·밀림 손맛·hover 거리감은 헤드리스가 못 잡는다**(세56 실게임 MCP로 링·탄 렌더 확인, 손맛=사용자 F5) · 🔴**뮤테이션 4/4 검출력**(페이즈·rune 두 몸 각각·볼리)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_spell_vfx_auto.gd     # **마법 연출 배선** (세션59): vfx가 `ring_cast_requested`·`spell_impact`에 연결(배선 침묵사 그물) · 트레일 형제 스폰 + 🔴**`player_projectiles` 그룹 무가입**(트레일이 가입하면 탄 수 세는 테스트 4곳이 거짓으로 는다) · 트리 밖 setup 무에러(null 가드 — ⚠ 이 항목의 진짜 검출자는 **SCRIPT ERROR grep**이다, 테스트는 가드가 없어도 OK를 찍는다) · 🔴**빈 진 착탄 = emit 정확히 1**(캐리어 emit 전용 그물 — 발산 탄이 있으면 캐리어 emit 부재가 가려진다, 뮤테이션으로 실증) · 발산 진 착탄 ≥2(탄 emit) · 🔴**볼 코어·자전·펄스·트레일·머즐/착탄 렌더는 헤드리스가 못 잡는다**(실게임 MCP 필수)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_ring_book_jin_auto.gd # **책 진 셀 격자·아이콘** (세61에 목록 편입 — 세션7 함정「목록에서 빠진 테스트는 낡아 죽는다」의 그 자리에 있었다): Db 진 ≥1종 · 격자 계약 = 합성 8개(순수 함수 `jin_cell_rects` — 카탈로그 1종이면 cols=1이라 폭 비교가 무의미해져 합성으로 잰다) · 아이콘 구분 = pattern×motion 조합 합성 순회 · 🔴**실제 셀 겉보기·클릭은 헤드리스가 못 잡는다**(실게임 확인)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_floating_wand_auto.gd    # **떠있는 지팡이 + 발사 총구 계약** (세션65 — 세피리아식): 미장착→FloatingWand 숨김+발사 origin 몸중심 폴백(맨손 캐스팅 보존) · 장착→표시+🔴**발사 origin == 지팡이 끝 muzzle_position** + 몸과 뚜렷이 떨어짐(총구가 몸이 아니라 지팡이 끝이라는 계약 자체 — 뮤테이션 `_muzzle`→몸중심 되돌리면 [2] 2건 빨감) · 총구 기하 단일 소스(원점·무회전에서 tip==MUZZLE_LEN) · 🔴**둥둥·회전·flip·머즐 연출·지팡이 겉보기는 헤드리스가 못 본다**(실게임 MCP — 세65에 4방향 조준·발사 tip 스폰·bob 실측)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_feel_auto.gd            # **손맛 개편** (세션63): player_hurt 발신 단일 소스+🔴사망 가드(hp 0 뒤 무발신) · 🔴히트 플래시 material **per-instance**(공유=전원 플래시) · 텔레그래프=셰이더 uniform+**modulate 불가침**(rgb=상태 틴트·a=분산 2축 계약) · hurt 애니 굽기(있으면 비루프/없으면 무변경) · 보스 2종 hurt_sprite 로드(세50 침묵사 그물) · 그림자(z≥0·그룹 무가입·첫 자식·뱀 마디 수 일치) · dust 구르기 엣지 버스트 · 카메라 킥 방향(발사=조준 반대·피격=가해자 반대) · 플레이어 hurt 애니 가드 · 🔴허수아비 파리티(세56 두 몸 그물) · 🔴**플래시가 실제로 하얗게 보이나·그림자/먼지 겉보기·수치 손맛은 헤드리스가 못 잡는다**(세63에 그림자 가림·먼지 뭉개짐을 실게임이 잡았다 — 전 그물 그린이었다)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_jin_layers_auto.gd       # 🔴 **진별 해석 M1 — 층(밴드) 순서 = 연산 순서** (세79, 정본 `docs/takbon-design/jin_interpretation_design.md`): M1 콘텐츠 3종 Db 로드(gr_spread3·gr_explode1·jin_plain_g2 band_count=2 — 파싱 침묵사 그물, 세50) · `layer_rings` 계약(밴드→층, 칸 0부터 count개, 🔴**빈 밴드도 층 자리를 지킨다**=건너뛰면 감쌈 깊이가 조용히 밀린다) · 🔴**회귀: 밴드 1개면 층0 == `flatten_bands`**(지금 살아있는 진은 전부 band_count=1이라 이 동치가 곧 「저장 도안 발사 무변경」의 증명) · `_as_layers` 정규화(옛 8칸 한 겹→층 1개 승격·멱등) · 🔴🔴**[4] 심장 = 순서가 결과를 바꾼다**: `폭발(확산(불))`=융합 폭발 **1개**(큰 반경) vs `확산(폭발(불))`=복제 폭발 **3개**(작은 반경·자리 벌어짐) — ⚠**balance 수치를 안 박고 개수·대소 관계로만 잰다**(손맛 튜닝 한 번에 거짓 빨강이 되지 않게) · 옛 도안 무회귀(층 1개+전개형만 = 탄 8발·기둥 1개·폭발 0, **빈 진은 여전히 전개 0**=씨앗 누출 감지) · 씨앗(감쌀 게 없으면 문양이 **룬 자체**를 감싼다) · 세기 = 그 층의 칸 수 · [7] 🔴**조립 UI→발사 계약**(`build_assembly`가 rings를 다겹으로 싣나 + score 동승 — 끊기면 M1이 게임에서 통째로 안 보인다) · 🔴**뮤테이션 5/5 검출력 확인**(폭발을 「각각 터뜨림」으로·층 루프를 rings[0]만·씨앗 제거·빈 밴드 건너뜀·build_assembly를 flatten으로 — 전부 원상복구 확인) · 🔴**폭발이 실제로 「크게 터졌다」로 보이나·확산 부채가 넓어 보이나·따라 긋는 손맛은 헤드리스가 못 잡는다**(F5)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_jin_fusion_auto.gd       # 🔴 **진별 해석 M2 — 룬 2개 + 융합진** (세81, 정본 `docs/takbon-design/jin_interpretation_design.md`「M2 확정 설계」): jin_fuse Db 로드+`rune_slots==2`(파싱 침묵사 그물, 세50) · `runes_of` 승격·멱등+저장 라운드트립(옛 도안 `{rune}`→`[rune]`) · `RingAssembly` 다중 룬 계약(set_rune_slots·set_rune(type,slot)·runes_ready 게이트) · [4] `_fire_hit` **합산 = 0.7×(두 룬 단독 합)**(base_damage 무관 불변식)+rune_hits 2개+정렬(primary=WET 바탕) · 🔴🔴[5] **심장 = 융합 발사 → 한 발이 두 상태 → 반응(SHOCK) + 자리 순서 무의존**(물·번개 뒤집어도 감전) · 🔴[6] **도배 방지 = 융합 한 발 enemy_hit 발신 == 1**(보조 0-피해 히트가 안 쏨 — dummy `hits[]`엔 담겨도 발신 수로 잼) · [7] 기둥·폭발도 반응(rune_hits 이식 그물) · [8] 🔴**회귀 = 룬 1개 share 1.0·rune_hits=[primary] 하나라 옛 계산 완전 동일** · 🔴**뮤테이션 7/7 검출**(0-피해 가드 dummy·forest_enemy 각각·rune_hits·정렬·share·pillar/blast·runes_of) · 🔴**룬 소켓 2칸 클릭·룬 2개 밑그림·반응 가시성은 헤드리스가 못 잡는다**(F5) · ⚠**게임 UI 반응은 물+불=증기뿐**(번개·흙·풀 룬 데이터 없음 — 세61 리셋)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_glyph_data_auto.gd     # 🔴 **문양 효과·표현 데이터화 + 응축** (세82 M3, 정본 `docs/takbon-design/glyph_data_design.md`): [1] `Enums.GlyphCode` **전 9값**이 Db 로드 + `behavior`가 `BEHAVIORS`의 키 + `params` 실제 파싱(세50 침묵사 자리 — **예외 목록 없음**이 곧 자명통과 방지) · [2] `modifier_codes()==[6,7,8]` 명시 기대 · [3] 🔴**회귀 = 수치가 balance→.tres로 이사했는데 관계식 동일**(값을 박지 않는다) · [4] 🔴🔴**심장 = 응축은 폭발의 반대, 단조성으로 잰다**(갈래↑→응축 좁아짐·폭발 넓어짐 — ⚠**대소 비교만으론 부호 뒤집기를 못 잡는다**: 54×1.24=66.96 < 폭발 73.44라 그린이 된다) · [5] `merge_mult_per_count`가 count≥2 경로에 걸린다(고리를 count=2로 낸 이유) · [6] **응축이 새 알고리즘 없이 돈다**(behavior==blast·알고리즘 4종 유지) · [7] 미등록 code=건너뜀 + 🔴**빈 칸(-1)은 경고 대상 아님**(발사마다 경고 폭탄) + 🔴**계열 분기가 실제로 `_apply_layer`를 지난다**(없으면 behavior를 통째로 bolt로 돌려도 전부 그린 — 실측) · [8] code 중복=**결정적 승자**(id 사전순 — ⚠주입 순서를 사전순과 갈리게 넣어야 검출) · [9] 주입 후 `reindex_glyphs()` 갱신(세61 주입 관행) · [10] **같은 층 내 배치 순서 무관** · [11] 반경 부호 구멍 · [12] UI 이름·색·선택이 .tres에서(옛 `clampi`가 응축→폭발로 누르던 자리) · 🔴**뮤테이션 9/9 검출+원상복구** · 🔴**응축 나선을 손으로 그을 만한가·「집중 한 방」으로 보이나는 헤드리스가 못 잡는다**(F5)
./Godot_v4.7.1-stable_win64.exe --headless --path . -s res://tests/test_assembly_slice_auto.gd  # **조립→탁본 최소 슬라이스** (세68 — 파밍한 문양-고리를 진 밴드에 조립→조립본이 통째 탁본 밑그림→손으로 한 번에 따라 긋기): 🔴**문양-고리 Db 2종 로드**(GlyphRingDef 파싱 침묵사 그물, 세50) · 🔴**compose_guide 합성**(진 윤곽+룬 12등분+밴드 2겹 문양-고리 — 기존 static 팩토리만 재사용=새 기하 0, 빈 밴드 대조) · 🔴**flatten_bands 발사 계약**(밴드 motif×count→8칸 라운드로빈·순서가 배치 바꿈·8칸 truncate·null 건너뜀 — 뮤테이션 `idx+=0` 7건 검출) · 통째 채점(합성 가이드 위 가짜 궤적→coverage>0·combined_total>0·안 그으면 0 대조) · 플래튼 발사(assembly.rings에 motif→불탄5/기둥1·실제 dummy take_hit) · 패널 build_assembly가 🔴**score/rings/rune/jin 싣음**(세26 to_assembly 계약) · 🔴**mouse_filter 클릭 도달·합성 가이드 렌더·통째 트레이스 손맛·밴드 간격은 헤드리스가 못 잡는다**(세25·세50 — 실게임 push_input·F5 필수)
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

🔴🔴 **리드가 에디터를 자동으로 켜지 마라** (2026-07-24 사용자 확정). 사용자가 자기 워크플로로
에디터를 직접 관리한다 — 리드가 `--editor`로 띄우거나 MCP로 붙으면 **사용자 콘솔에 연결 메시지가
계속 떠 개발을 방해**한다(실제로 겪음). 규칙:
- **기본 검증 = 헤드리스 테스트(Bash `-s`) + 뮤테이션.** 에디터·MCP 없이 여기까지 한다.
- **실게임 시각 확인이 필요하면** 리드가 켜지 말고 **사용자에게 F5(또는 에디터 열기)를 부탁**한다
  ("이 부분은 클릭 도달·렌더라 헤드리스가 못 잡아요 — F5로 확인해 주실래요?"). 스샷이 필요하면 사용자가 준다.
- **에디터/MCP는 사용자가 "켜줘"라고 명시할 때만** 리드가 띄운다. 그때만 `Start-Process
  .\Godot_v4.7.1-stable_win64.exe -ArgumentList "--editor","--path","."` + MCP 사용.
- ⚠ 게임만 독립 실행(에디터 없이)은 `--path .`만: `Start-Process .\Godot_v4.7.1-stable_win64.exe -ArgumentList "--path","."`.
- ⚠ 위 「실게임 MCP 필수」 서술들은 **검출력의 근거**(헤드리스 한계)이지 리드가 자동으로 MCP를 켜라는
  뜻이 아니다 — 그 확인은 이제 **사용자 손(F5)**으로 넘긴다.
- project.godot을 파일로 수정한 후에는 (에디터가 켜져 있을 때) `godot_project check_stale` → 필요시 에디터 restart
