# 하네스 이력 (탁본 전용 에이전트·스킬)

> 이 파일은 **역사 보관소**다 — CLAUDE.md에서 「왜 이렇게 됐나」를 떼어 온 것이다.
> 지금 지켜야 할 규칙은 CLAUDE.md 「개발 규칙」 절에 있다. 여기는 되돌릴 때·사유를 캘 때만 본다.
> 🔴 CLAUDE.md 본문에 **개수를 적지 마라**(스킬 43→36→33처럼 늘 낡는다). 개수는 `ls`로 세라.

## 왜 만들었나 (2026-07-19 세션 39 — godot-prompter 대체, 자립형)

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

## 변경 이력

| 날짜 | 변경 | 대상 | 사유 |
|------|------|------|------|
| 2026-07-19 | 초기 구성 | agents/takbon-{dev,architect,reviewer} · skills/takbon-{rules,verify} | godot-prompter가 제네릭이라 위임 시 규칙 주입 비용이 커 위임이 안 굴러감 |
| 2026-07-19 | UI·아트 에이전트 추가 | agents/takbon-ui(패널·mouse_filter 함정) · agents/takbon-art(aseprite 함정·아트 방향) | 탁본이 실제로 쓰는 영역(패널 천지·직접 스프라이트 제작) 커버 |
| 2026-07-19 | 자립형 전환 · 플러그인 끔 | 제네릭 스킬 26개 `.claude/skills/`로 복사 · settings.json에서 godot-prompter 제거 · 에이전트 참조를 로컬 이름으로 | 오버레이가 플러그인에 묶여 있어 플러그인을 끄면 참조가 끊김 → 자립형으로 |
| 2026-07-19 | 스킬 전체(51) 복사 + dev 매핑 완성 | 나머지 25개 스킬 복사(총 51) · takbon-dev 스킬 매핑에 animation/physics/camera/player 등 추가 | 사용자 걱정: "애니 등 만들 때 스킬 안 쓸까 봐" → 기능 지식=스킬이므로 전부 확보 + 에이전트가 부르게 매핑. 노이즈 정비는 추후 |
| 2026-07-19 | 나머지 에이전트 탁본화(총 9) | agents/takbon-{shader,animator,profiler,tools} 추가 | 사용자 "만들어만 둬줘". csharp만 제외(GDScript 전용 규칙과 충돌). 원본 복사 아닌 규칙 주입 재작성 |
| 2026-07-19 | 스킬 노이즈 정비 51→43 | 삭제 8: 3d-essentials·csharp-godot·csharp-signals·gdextension·xr-development·mobile-development·using-godot-prompter·godot-project-setup · takbon-dev 매핑·「휴면 방향」주석 갱신 | 2D·GDScript·데스크톱 확정으로 구조적 무관만 삭제. 멀티·dedicated-server·beehave·limboai·localization은 사용자가 방향을 안 접어 유지(삭제=방향 포기 신호) |
| 2026-07-19 | 제네릭 43개 SKILL.md 한국어 번역 + 벤더링 | skills/*/SKILL.md 본문 번역(references·코드블록·name은 원문) · 신설 `.claude/skill-vendor/`(영어 1.11.0 박제본+VERSION+check-upstream.sh) | 사용자 요청 한국어화. 상류와 갈라지므로 「관리된 갈라짐」 채택 = 월간 대조로 상류 변경분만 반영 |
| 2026-07-19 | references 심화문서 150개 삭제 | skills/*/references/ 40폴더 + godot-testing 최상위 참조 2개 삭제 · 본문 죽은 링크 정리 | 사용자 "깔끔하게 관리". skills/ 트리를 SKILL.md 한 장씩만 남김. 영어 전문은 skill-vendor 박제본+상류 github에 있어 영구 손실 아님(복구 가능) |
| 2026-07-20 | 위임 예외 목록 걷어냄 · 파이프라인 기본화 | CLAUDE.md 「개발 규칙」 | 사용자 세48: *"기획을 처음에 빡세게 잡고 가고 싶고, 코드의 퀄리티를 신경쓰고 싶어."* 옛 예외("회귀 위험·core 스키마·mcp__godot·커밋은 리드")가 너무 넓어 재밌는 작업이 죄다 예외에 걸려 위임이 안 굴러갔다 |
| 2026-07-20 | 🔴 보고서는 **파일로** 지시 | 위임 프롬프트 규약 | 세48~49에 채팅 보고 4건이 **증발**(idle 알림만 옴) · 파일로 시킨 2건은 도착. architect·reviewer는 산출물이 보고서뿐이라 치명적 |
| 2026-07-21 | 🔴 **도형 플레이스홀더 금지** 규칙 박음 | CLAUDE.md 살아있는 함정 + skills/takbon-rules §0 + agents/takbon-{architect,dev} | 사용자 확정(세54): 뱀 보스가 Polygon2D 도형으로 나감. 설계·구현이 "아트 병렬이니 도형으로 먼저"(drop_pickup 마름모 선례)를 관행처럼 써왔는데 **하네스 어디에도 금지 규칙이 없어** 재발. 이제 생명체·프롭 = takbon-art 도트 스프라이트 필수(VFX·가이드선은 예외) |
| 2026-07-24 | 🔴 **기획 스킬 `takbon-design` 신설 + architect 역할 재정의** | skills/takbon-design(신설) · agents/takbon-architect | 사용자: architect가 **혼자 정해 생각과 다르게** 나옴 → 서브에이전트는 구조상 대화 불가라 대화형 기획엔 부적합. 게임 방향(무엇/왜/재밌게)은 **리드가 `takbon-design`으로 사용자와 대화하며 확정**(한 번에 질문 하나·2~3안+추천·섹션별 승인·하드게이트·scratch 문서 착지), architect는 **확정된 설계를 받아 훑는 리뷰어**로 재정의(방향 뒤집기 금지). superpowers `brainstorming` 스킬의 탁본판. 구현 계획서 단계는 안 넣음(설계→dev 직행, 사용자 확정) |
| 2026-07-24 | **슬림화: 에이전트 9→7 · 제네릭 스킬 43→36** | 삭제 agents/takbon-{profiler,tools} · 삭제 skills 7(responsive-ui·multithreading·ai-navigation·ability-system·assets-pipeline·export-pipeline·procedural-generation) · takbon-dev 매핑 갱신 | 사용자 "슬림화 해줘". description은 매 세션 상주 로드라 안 쓰는 걸 줄이면 실익. 삭제 기준 = 2D 싱글 데스크톱 로그라이트 형식상 안 쓰는 순수 기술 스킬(방향 신호 아님) + profiler(성능 이슈 0회)·tools(에디터 툴링 거의 안 씀). 필요 시 git 복구·dev가 스킬 직접 로드. ⚠ 방향 신호 6(멀티×2·dedicated-server·beehave·limboai·localization)은 이번엔 유지 |
| 2026-07-24 | **입체화 에이전트 `takbon-relight` 신설** | agents/takbon-relight(신설) · agents/takbon-art(입체 규율 포인터) | 사용자: 스프라이트를 "하앙 입체적으로". 세69 relight 기법(`tools/relight_sprites.lua`·실루엣 재조명·건물 기준)을 전담 에이전트로. 방식 A(기존 PNG 후처리) + B(신규를 처음부터 입체). 🔴🔴 재익스포트 시 음영 침묵 원복 함정 내장. art는 신규를 입체로 그리고 큰 입체화는 relight에 위임 |
| 2026-07-24 | **기획 문서 보관소 `docs/takbon-design/` 신설** | 루트 scratch 설계 7개 이동(scratch_ 접두어 제거)·보고 3개 삭제·README 인덱스·takbon-design 스킬 착지 경로 변경·memory/CLAUDE.md/STATUS/PROGRESSION 살아있는 참조 갱신 | 사용자: 기획 문서를 리포 루트 흩뿌림 말고 영구 폴더에. 앞으로 `takbon-design`이 `docs/takbon-design/<주제>_design.md`로 착지. 구현 보고·리뷰는 여전히 일회성 루트 scratch(반영 뒤 삭제). ⚠ 이미 삭제된 옛 scratch 로그 참조(STATUS의 school_village·jin_slots 등)는 과거 기록이라 안 건드림 |
| 2026-07-24 | **`.claude/skill-vendor/` 통째 제거** | skill-vendor 폴더(upstream-1.11.0 박제본 43+VERSION+check-upstream.sh) 삭제·CLAUDE.md 「관리된 갈라짐」 서술 정리 | 사용자 확정: 상류(godot-prompter)와 계속 맞추지 않기로 함. 번역 스킬은 이제 상류 추종 안 하는 **탁본 로컬 포크**. 영어 원본이 필요하면 상류 github에서 꺼냄(세39 번역 이후 상류 대조를 실제로 돌린 적 없어 무게만 됐다) |
| 2026-07-24 | 🔴 **단일 진실원 `docs/GDD.md` 신설 + 수정 잠금** | 신설 docs/GDD.md(안정된 진실만) · settings.json `ask` 잠금 · WAND_CIRCLE.md 은퇴 스텁 · CLAUDE.md 정본 포인터 단순화(5곳→GDD 헤드) · memory 주 정본 갱신 | 사용자: "진실원(GDD)을 두고 허락 받아야 수정하게, 문서가 많아서". 진실이 5곳(CLAUDE.md·STATUS·WAND_CIRCLE·PROGRESSION·memory)에 흩어져 있던 걸 GDD가 "게임이 무엇인가"의 단일 정본으로 흡수. 잠금 = settings.json `Edit/Write(docs/GDD.md)=ask`(매 수정에 허락 프롬프트). 세39에 지운 옛 TRUTH.md의 부활 격 |
| 2026-07-25 | 🔴 **멀티 방향 은퇴 · 스킬 36→33** | 삭제 skills 3: multiplayer-basics·multiplayer-sync·dedicated-server · 「휴면 방향」 서술 갱신 | 사용자 확정(세75): *"멀티 안하기로하자"*. 세39·세73에 「방향 신호」로 일부러 남겨뒀던 멀티 3종을 방향 자체를 접어 삭제(삭제=방향 포기 신호). beehave·limboai·localization은 아직 유지. 게임은 2D 싱글 데스크톱 로그라이트로 확정. 되돌리려면 git 이력 |
| 2026-07-26 | ✅ **제네릭 스킬 33개 전량 유지 확정**(삭제 0) | beehave·limboai·localization 거취 재검토 → **유지**(사용자 확정) | 세87에 삭제를 검토했다가 **실측이 삭제 논거를 무너뜨렸다**: ⓐ 매 세션 상주하는 건 **frontmatter뿐**(제네릭 33개 합쳐 5,854 B ≈ 1,460토큰)이고 본문 10,439줄은 **호출될 때만** 로드된다 → 「안 쓰는 스킬이 매 세션 비용을 먹는다」는 전제가 거짓 ⓑ 후보 3개는 **556 B = 9.5%**뿐인데 삭제는 **방향 포기 신호**(세75 멀티 선례: 사용자가 방향을 접고 나서야 지웠다). 🔴 부수 교훈 = 감사의 「참조 0건」이 **백틱 없는 평문을 못 센 집계 artifact**였다(셋 다 `takbon-dev.md`에 실재) — **참조 0을 삭제 근거로 쓸 때 백틱만 세지 마라**(세85 `fail=N` 오집계와 같은 종류) |
| 2026-07-26 | 📦 **하네스 역사를 이 파일로 이관** | CLAUDE.md 210-233(자립형 blockquote)·271-291(변경 이력 표) → `docs/HARNESS_LOG.md` 신설 | CLAUDE.md 정비(세86 후속): 24줄 blockquote + 18행 표가 전부 **과거 시제**인데 매 세션 상주 로드였다. 지금 판단에 쓰이는 2행(도형 금지·보고서는 파일로)은 **이미 CLAUDE.md 본문에 정식 규칙으로 등재**돼 있어 삼중이었다. ⚠ 표와 본문이 실제로 어긋나 있었다(표 「스킬 36→33」 ↔ 본문 「제네릭 스킬 36개」) = 역사를 규칙 옆에 두는 게 정합성을 못 지킨다는 증거 |
