---
node: nested
stage: building
owns: [rune_fill]
needs: [jin_interpretation]
blocked: 개념 프레임이 세72·78에 은퇴했다 — 문서대로 구현하면 은퇴한 발사 모델을 되살린다. 살아있는 것은 #5 rune_fill 입력 수단과 #7뿐이고 거취가 미정이다(TODO.md 「rune_fill 거취」)
dead: true
---

# 설계: 중첩 마법진 통합 (복합 룬 × 재귀 진 × rune_fill)

> ⚠🔴 **프레임 은퇴 (세78 교차 감사).** 이 문서의 개념 프레임(진이 날아가 **자식 진을 착탄점서 재발사=재귀 배달** ·
> 문양=8칸 착탄 · 평평한 `runes[]` 자동 반응)은 **세72(진 안 날아감)·세68(문양=조립 감쌈)에 토대가 은퇴**했다.
> **`jin_interpretation_design.md`(세78)가 이 프레임을 대체한다 — 공존 아님.** 문서대로 구현하면 은퇴한 발사 모델을 되살린다.
> **살아있는 것 = 참고 자산뿐**: ①의 코드 인벤토리(`projectile.rune_hits`·`ring_carrier.deployed` 실사) + rune_fill 소비자
> 0곳 진단 + "원소 반응(status_holder) = jin_interpretation ②「진 규칙」의 한 인스턴스(융합진)"라는 흡수. 삭제는 안 함(이 자산 때문).
>
> ⚠🔴 **세87 실측 — 남은 8개 결정점 중 살아있는 건 둘뿐이다.** 삭제 후보로 올랐다가 **존치**로 결론났다.
> 🔴 **세108 정정 — 그때 적은 존치 근거 셋(`CLAUDE.md`·`PROGRESSION.md`·memory 한 장이 이 문서를 가리킨다)이
> 전부 죽었다**: `CLAUDE.md`는 세98 축소로 이 문서를 안 가리키고, `PROGRESSION.md`는 세97 전면 재작성으로
> 안 가리키며, 그 memory(스테이지 형식 결정)는 세107에 지워졌다.
> **살아있는 존치 근거는 둘이다** — `docs/takbon-design/README.md`의 `building` 표 · `docs/TODO.md` **「rune_fill 거취」**
> (`rune_fill` 소비자 0곳 · 살릴지 접을지 미정). 즉 **이 문서가 유일하게 드는 자산은 `rune_fill` 입력 수단 안(#5)과 #7**이다.
> - ❌ **#4 복합 룬 = 해소됨** — 세81 M2가 `JinDef.rune_slots`로 실현했다(`JinDef`의 `rune_slots` ·
>   `data/jin/jin_fuse.tres` · 합산은 `ring_spell_system._fire_hit`의 share).
>   ⚠ 세87엔 `PROGRESSION.md`가 이걸 「미구현」으로 적고 있었으나 **세97 재작성 때 고쳐졌다**(지금은 *"발사에 실재한다"*).
> - ❌ **아래 ① 코드 인벤토리는 낡았다** — "평평하다: `rune:int` 하나"라 적었지만 지금
>   `RingDesign`은 `runes: Array`와 `runes_of()`를 든다(세81). 인벤토리를 근거로 쓰지 마라.
> - ✅ **#5 `rune_fill` 입력 수단** = 살아있는 미결. CLAUDE.md 「남은 빚」이 *"살릴지 접을지 결정 필요"*라고만
>   적고 **입력 수단 안은 이 문서에만 있다**(그래서 안 지웠다).
> - ✅ **#7** = 살아있는 미결.
>
> takbon-architect(nested-design) 산출물. 코드 없음 — 설계안만.
> 정본 대조: **`docs/GDD.md` §5**(마법진=수식 · *"배치만 바뀌어도 결과가 통째로 달라진다"*) · `takbon-rules` 스킬 읽음.
> (⚠ 옛 대조처 `docs/WAND_CIRCLE.md`는 **삭제돼 없다** — 진실원 = `docs/GDD.md`.)
> 아래 "검증한 것"은 **세?? 당시** 코드를 Read/Grep으로 확인한 사실이다 — 위 ⚠대로 지금은 일부 낡았다.

---

## ① 현재 상태 — 직접 검증한 것

| 항목 | 확인 결과 |
|---|---|
| `RingDesign` (`src/core/schemas/ring_design.gd`) | 평평하다: `rune:int` 1개 + `rings[0]` 8칸 + jin/ink/special/size/score. 칸 값 = 문양 코드 int. 트리 없음. `to_assembly()`/`from_assembly()`가 발사·저장 계약. |
| `ring_carrier.gd` | "껍질=배달" 깊이 1은 산다: 착탄 → `deployed(ring, at, travel)` → ring_spell_system이 전개. **단, setup이 룬 1개 인자**(rune_hits 없음). |
| `projectile.gd` | 🟢 **복합의 절반이 이미 완성**: `rune_hits: Array` + `setup(..., p_rune_hits)` + `_deal_damage`가 primary(피해+상태) → 나머지 `take_hit(0.0, ...)` 순회(projectile.gd:313-323). 호출자가 안 채울 뿐. 옛 SpellDesign `children`(재귀)은 세22에 매장 — git에만 있다. |
| `pillar.gd` | `setup(damage, rune_type, status, status_power)` 4인자 — rune_hits **미지원**. 복합을 켜면 응집 기둥도 확장 필요. |
| `ring_spell_system.gd` | 유일 발사 경로. `_deploy_now`가 8칸을 돌며 발산탄/기둥 스폰. `_fire_hit`가 룬 1개 전제. `_on_carrier_deployed`가 power/status_mult/rune_type을 bind로 나른다 — 자식 진을 실어 나를 자리도 같은 패턴이 된다. |
| 🔴 **`rune_fill`은 소비자 0곳이 아니라 생산자도 0곳** | 옛 `design_builder.rune_fill_of()`는 세21 대청소에 매장. 지금 살아 있는 것 = ①`ring_board._rune_scale`(룬 크기 **휠** — 렌더·가이드 크기에만 쓰임, `_rune_size() = outer*0.16*_rune_scale`) ②balance의 유령 필드 `rune_density_min 0.5`/`rune_density_max 1.8`/`rune_density_mana_mult 4.0`. `get_assembly()`(ring_board.gd:229)는 `size`(진 크기)만 싣고 룬 크기는 **버린다**. 즉 부활 = "휠 값을 싣고 → 소비자를 정한다" 두 걸음이고 balance 필드는 공짜다. |
| `status_holder.apply_incoming` (core) | 순서가 규칙: ①바람=확산 후 즉시 반환 ②붙은 바탕과 반응 있으면 반응이 이김 ③아니면 덮어쓰기. → **`rune_hits` 순회가 돌면 한 탄 안에서 셋업+기폭이 자동 성립한다**(물 primary가 WET을 얹고, 다음 순번 BOLT가 ②에 걸려 감전 burst). 순서 = 배열 순서. 별도 기계가 필요 없다 — 밸런스 결정만 남는다. |
| 저장 | `SaveManager`가 도안마다 `ResourceSaver.save`로 개별 .tres. **자식 RingDesign을 프로퍼티로 물리면 서브리소스로 인라인 저장돼 라운드트립이 공짜**(별도 파일 관리 불필요). 장착은 인덱스 참조(`ring_designs.find`) — id 조회 체계는 없다(RingDesign.id는 사실상 미사용). |
| `ring_power.gd` | power_of = max × score^curve × ink × size^exp. 단일 소스. 재귀 위력 감쇠도 여기 한 곳에 둬야 한다. |
| 발사 계약 | `Enums.GlyphCode` 0~5 — **밀 수 없다.** 칸 값에 새 의미를 끼우는 설계는 탈락 사유다(아래 스키마 대안에서 그렇게 걸렀다). |

---

## ② 통합 모델 — 세 축이 한 그림에서 만나는 곳

**한 문장: 진 = 트리 노드다. 노드마다 「진(그릇) + 룬 1..N(각자 그린 크기 = fill) + 문양 칸 + 자식 진 0..M(칸 방향에 박힘)」이고, 캐리어가 착탄점에서 내용물을 전개할 때 문양 탄·기둥과 함께 자식 진을 그 칸 방향으로 또 쏜다.**

```
RingDesign (뿌리 = 지금과 동일)
 ├─ jin (그릇·형태)                     ← 기존
 ├─ 룬들 [{type, fill}]                 ← 복합: N개, fill = 그린 크기 (rune_fill 부활)
 ├─ rings[0] 8칸 (GlyphCode)            ← 기존, 계약 무변경
 └─ 자식 진들 [{slot, design}]          ← 재귀: 칸 방향에 박힌 완성 도안 (트리)
```

- **rune_fill의 소비자 = 상태이상 세기 배율**: `status_power ×= lerp(rune_density_min, rune_density_max, fill)`. balance 필드가 이미 있고(0.5~1.8), **단독 룬에도 즉시 의미가 생긴다**(크게 그린 불 = 더 아픈 화상). 복합에서는 fill이 곧 **비중 분배**다 — 두 룬을 그리면 판 중심 공간을 나눠 써 각자 fill이 줄고, 반응(셋업+기폭)의 세기가 자연히 깎인다. **fill이 복합의 밸런스 브레이크를 겸한다** — 이게 세 축을 따로 하지 않고 통합하는 이유다.
- **재귀의 방향 = 배치**: 자식이 박힌 칸(0=위, 시계방향)이 착탄 후 자식 캐리어가 날아가는 방향이다. "배치가 결과를 바꾸는가? 안 바꾸면 스위치다"(정본 = `docs/GDD.md` **§5** *"배치만 바뀌어도 결과가 통째로 달라진다"* + **§7** *"스칼라(세기)만 바꾸는 축은 자유도가 아니다"*)와 정합.
- **원칙 유지**: 「단독은 약한 바탕, 조합에서 폭발한다」(세49) — 복합은 그 조합을 한 탄에 압축하는 대신 fill 나눔으로 값을 치르고, 재귀는 공간(칸)과 위력 감쇠로 값을 치른다.

---

## ③ 스키마 변경안 (⚠ 전부 리드가 core에 반영 — 여기선 제안만)

### 대안 비교

| | A. 인라인 트리 (자식 = 서브리소스 스냅샷) | B. 칸 값에 도안 id 참조 | C. 별도 컨테이너 리소스(NestedDesign) |
|---|---|---|---|
| 저장 라운드트립 | 🟢 공짜 — ResourceSaver가 서브리소스 인라인 | 🔴 id 조회 체계가 없다(도안은 인덱스 참조). 참조 도안 삭제·수정 시 침묵 파손 — 세50 "조용히 사라진다" 그 자리 | 🟡 되지만 파일·개념이 하나 더 |
| GlyphCode 계약 | 🟢 무변경 (자식은 칸 값이 아니라 별도 배열) | 🔴 칸 int에 "id 인덱스" 의미를 끼움 = 계약 오염 | 🟢 무변경 |
| 하위호환 | 🟢 옛 도안 = 빈 배열 = 지금과 동일 | 🟡 | 🟢 |
| 원본 수정 전파 | 스냅샷이라 전파 안 됨 (박은 시점의 그림·점수 고정 — **예측 가능**) | 전파됨 (원본을 고치면 이미 만든 중첩 도안이 조용히 바뀜) | 선택 가능 |
| 비용 | 낮음 | 중간 | 높음 |

**추천 = A.** 자식은 **박는 순간 duplicate(true)로 복사한 스냅샷**이다. "탁본"이라는 게임 정체성과도 맞다 — 박은 건 그 순간의 탁본이지 살아 있는 링크가 아니다.

### RingDesign 변경 목록 (리드 반영용, 전부 하위호환 기본값)

```gdscript
## 🔴 복합 룬 (세션??). [{ "type": int(RuneType), "fill": float(0..1) }, ...].
## [0] = primary(피해·색·탄 씬). 빈 배열 = 옛 도안 = rune 하나에 fill 기본값 — 하위호환.
@export var runes: Array = []          # 기존 rune:int은 primary 미러로 유지 (옛 소비자·저장 안 깨게)
## 🔴 자식 진 (재귀). [{ "slot": int(0..7), "design": RingDesign(스냅샷) }, ...]. 빈 배열 = 지금과 동일.
@export var children: Array = []
```

- `rune: int`는 **지우지 않는다** — primary의 미러로 남긴다(HUD·옛 세이브·`assembly.rune` 소비자 다수). `runes`가 비면 `[{type: rune, fill: 기본}]`로 해석.
- `to_assembly()`에 키 추가: `"runes"`(배열), `"children"`([{slot, assembly}] — **자식도 to_assembly() 재귀**, 자식 score가 실려야 자식 위력이 그때 그린 값). `from_assembly()` 역방향 재귀.
- ⚠ fill 기본값: 옛 도안·rune_fill 미측정 도안은 **fill = 배율 1.0이 되는 값**(lerp(0.5,1.8,x)=1.0 → x≈0.385)로 폴백해야 기존 세이브의 상태 세기가 안 변한다. balance에 `rune_fill_neutral` 한 줄로 두는 걸 추천(코드에 수치 금지 규칙).

### balance.tres 추가 (리드)

- `nested_depth_max: int = 2` — 발사 시 전개 깊이 캡(스키마는 무제한, 전개만 자름).
- `nested_child_power_mult: float = 0.6` — 자식 위력 감쇠(⑥ 참조). 적용 함수는 `ring_power.gd`에 신설(단일 소스).
- `rune_fill_neutral: float ≈ 0.385` — 위 폴백.
- (기존 `rune_density_min/max` 재사용 — 신설 아님.)

### EventBus — **신규 시그널 없음**

자식 전개는 `ring_spell_system` 내부에서 닫힌다(`deployed` 콜백 bind에 자식 목록을 실어 나르면 끝 — 지금 power/status_mult를 나르는 그 패턴). 세36 퀘스트 방식(기존 계약 무접촉)과 같은 결의 저회귀 설계다.

### 기타 확장 (core 아님 — dev 몫)

- `ring_carrier.setup`에 `p_rune_hits: Array = []` 추가(끝에 기본값 — 옛 호출·테스트 무변경) + `_hit_enemy`에서 projectile과 같은 순회.
- `pillar.setup`도 동일하게 확장.
- `ring_assembly`: `_runes: Array` + `add_rune()`/`set_rune_fill()` · `_children: Array` + `attach_child(slot, design)` → `get_assembly()`에 싣기.
- `ring_board.get_assembly()`: 룬마다 그때의 `_rune_scale`을 fill(0..1 정규화)로 실어 싣는다 — **생산자 부활 지점**.

---

## ④ 그리기 UX안

### 재귀 — 자식 진을 어떻게 넣나

| | ①줌 인 (칸 클릭 → 판이 자식 진으로 전환, 이어 그리기) | ②박아넣기 (완성 도안을 책에서 골라 칸에 탁본) | ③진 안에 작게 직접 그리기 |
|---|---|---|---|
| "손으로 그려야 확정" 정체성 | 🟢 최상 | 🟢 **성립** — 자식도 손으로 그려 맺은 도안이고 그때 점수를 지님. "그린 것만 박을 수 있다" | 🟢이지만… |
| 실현성 | 🔴 보드 상태기계·채점기·브레드크럼 스택 — 큰 공사 | 🟢 책 탭 하나(진·룬 탭 미러) + 스냅샷 복사 | 🔴 칸 자리 미니 진 ≈ 십수 px — 마우스로 못 긋는다. **각하** |
| 회귀 위험 | 높음 (ring_board 757줄 재분할 급) | 낮음 (순수 추가) | — |

**추천 = ②로 시작, ①은 후속 확장.** 책 오른쪽에 **「도안」 탭**(보유 `GameState.ring_designs` 셀 목록 — 룬 탭과 같은 규약, takbon-dev 몫) → 문양 단계에서 열린 칸 클릭 → 문양 대신 도안을 고르면 그 칸에 자식이 박힌다(스냅샷). 판에는 그 칸 위치에 **박힌 자식의 축소 먹선**을 렌더(자식 strokes가 아니라 요약 렌더 — 캐리어 `_draw` 재사용 결). 문양이 박힌 칸에는 못 박고, 자식이 박힌 칸에는 문양을 못 놓는다(한 칸 한 물건).

- 채점: **레벨마다 따로.** 부모 판 점수는 부모가 그린 것(진·룬·문양)만 잰다. 자식은 자기 `total_score`를 이미 지니고 있다. 합산하지 않는 이유 — 잘 그린 자식을 박았다고 부모 점수가 오르면 "그리기 없이 점수 사기"가 된다.
- 🔴 비주얼: 판 위 자식 마커·축소 먹선은 **절차적 드로잉(가이드선 계열)이라 도형이 맞다** — 도형 금지 예외 해당. **새 도트 아트 필요 없음**(takbon-art 태울 것 없음). 책 「도안」 탭 셀도 기존 셀 규약의 절차 렌더.

### 복합 룬 — 어디에 어떻게 그리나

룬 단계에서 첫 룬을 그려 잠근 뒤 **[룬 추가]**(문양 단계로 넘어가기 전, 상한 2개로 시작). 두 번째 룬은:
- **크기 = 휠**(기존 `_rune_scale` 그대로 — 새 입력 없음). 그린 크기가 fill이다.
- **위치 = 중심 비켜 배치**: 첫 룬을 잠그면 두 번째 가이드는 중심에서 살짝 비낀 자리(예: 첫 룬 우하단). 겹쳐 그리면 먹선이 떡진다.
- 🔴 **fill 합 상한** = 트레이드오프의 실체. 두 룬의 fill 합이 진 크기(`_jin_scale`)가 허락하는 상한을 못 넘게 — "큰 종이·큰 진 = 큰 복합"으로 종이 경제(세28~29)와 이어진다. 상한 수치는 balance.
- 채점은 룬마다 별개 조각(`piece key`에 rune 슬롯 붙임 — trace_scorer 규약 확장, 채점 공식 자체는 무변경).

### fill 측정 — 휠 값 vs 실측

| | 휠 값(`_rune_scale` 정규화) | 그린 먹선 bbox 실측 (옛 rune_fill_of 방식) |
|---|---|---|
| 비용 | 🟢 0에 가까움 | 🟡 부활 필요 + 세션9의 "AABB 회전 불변" 함정 재상속 |
| 정직성 | 🟡 휠은 가이드 크기 — 실제 그린 크기와는 보정 오차 | 🟢 그린 것 그대로 |
| 함정 | 낮음 | 옛 세션 기록(git) "룬을 돌려 그리면?" — 회전 불변 아님 문제를 다시 밟는다 |

**추천 = 휠 값으로 시작.** 가이드 크기를 휠로 정하고 그 위를 그리므로 "얼마나 크게 그렸나"의 근사로 충분하고, 실측은 손맛 불만이 나오면 후속.

---

## ⑤ 발사·전개 흐름

```
fire → to_assembly() (재귀: children에 자식 assembly)
 → ring_cast_requested → _on_ring_cast
 → 캐리어 setup(..., rune_hits=[{type,status,status_power×density(fill)}...])   ← 복합
 → 착탄: 캐리어 몸 take_hit 순회(primary 피해, 나머지 상태만)
 → deployed → _deploy_now(ring, at, travel, ..., children, depth)
     ├─ 문양 칸: 지금과 동일 (발산탄·기둥 — 탄·기둥에도 rune_hits 실림)
     └─ 자식 칸: depth < nested_depth_max 이면
          자식 assembly로 **새 캐리어**를 at에서 (travel + TAU·slot/8) 방향으로 스폰
          — 자식의 jin pattern/motion 그대로 (안쪽 진도 완전히 같은 규칙, 사용자 확정)
          — 자식 위력 = 자식 자신의 power_of(자식 score·ink·size) × nested_child_mult(depth)
          → 자식 착탄 → 재귀 (depth+1)
```

- **제자리 전개가 아니라 칸 방향 재발사**를 추천한다: 배치(어느 칸에 박았나)가 결과(어디로 2차가 가나)를 바꿔야 하고, "껍질이 배달한다"의 자연 연장이다. 제자리 전개는 칸 선택을 스위치로 만든다. (단, 자식 캐리어의 초기 사거리를 짧게 잡을지 — 손맛 영역, 사용자 튜닝.)
- 위력: `ring_power.gd`에 `nested_child_mult(depth: int) -> float` 신설(= `nested_child_power_mult ^ depth`). 리포트(책)와 발사가 같은 함수를 불러야 하므로 **core 단일 소스** — 복사 금지.
- 지연 스폰 함정 상속: `_spawn_carrier`의 `is_inside_tree()` 가드·`call_deferred` 전개(flushing queries)가 자식 경로에도 그대로 적용돼야 한다 — 기존 함수를 재사용하면 공짜.
- rune_fill이 위력(피해)엔 **곱하지 않는다** — 피해 축은 score×ink×size로 이미 셋(세29 "축 겹침" 경고). fill = 상태 세기 축 전용. 축이 겹치면 잉크·종이 경제가 죽는다.

---

## ⑥ 밸런스 함의

1. **한 탄 셋업+기폭이 자동 성립한다** (`apply_incoming` 순서 — ①에서 검증). 물+번개 복합 한 발 = WET 얹고 즉시 감전 연쇄. **허용을 추천**하되 브레이크 둘:
   - fill 나눔: 두 룬을 그리면 각자 fill↓ → density 배율↓(0.5까지) → 반응 power↓. 두 발에 나눠 쏘는 것(각자 큰 fill)이 세고, 한 탄 콤보는 편한 대신 약하다 — "편함 vs 세기" 트레이드.
   - 순서 = **그린 순서**(runes 배열 순서). 물→번개와 번개→물은 다르다(후자는 SHOCK 위에 WET 덮어쓰기 — 반응 없음). 배치가 결과를 바꾼다는 정체성이 여기서도 성립하고, 플레이어가 통제한다.
2. **바람 복합** = 같은 탄이 primary 상태를 즉시 주변에 확산(바람이 runes 뒤 순번이면 방금 얹은 상태도 번진다). 강력하지만 바람의 정체성(촉매) 그대로 — 쏴 보고 조인다.
3. ⚠ **취약 이중 증폭 빚(세50, 미결)과 곱해진다** — 흙 복합으로 취약을 한 탄에 얹기 쉬워지면 이 빚이 더 커진다. 이번에 같이 결정하는 걸 추천(결정점 ⑧-7).
4. **재귀 감쇠 없으면 폭발**: 8칸에 자식 8장 × 각 자식이 또… → 감쇠(0.6^depth)+깊이 캡(2)+칸 경쟁(자식이 칸을 먹으면 문양이 줄어듦)이 3중 브레이크. 마나(`cast_mana_cost`)에 노드 수 반영은 후속(지금 고정 — 함수가 이미 단일 소스라 나중에 한 곳만 고치면 됨).
5. 수치(감쇠 0.6·깊이 2·fill 상한 등)는 전부 **시작값** — 사용자가 쏴 보고 조인다. balance.tres에만 둔다.

---

## ⑦ 마일스톤 (각 단계 단독 가치)

**M1 — 복합 룬 + rune_fill 부활 (한 세션).**
스키마 `runes`(+assembly 키) → 보드 [룬 추가]+fill 싣기 → `_fire_hit`가 rune_hits 생성(density 배율 포함) → carrier/pillar setup 확장 → projectile은 이미 준비됨.
단독 가치: 룬 조합 한 탄 콤보 + **rune_fill 빚 청산**(단독 룬도 "크게 그리면 상태가 세다" — 그리는 재미 축 부활). 회귀 그물: 옛 도안(runes 빔) 폴백 경로 뮤테이션, 두 몸(forest_enemy·dummy_target) 각각(세56 교훈).

**M2 — 재귀 깊이 1: 박아넣기 (한 세션).**
스키마 `children` → 책 「도안」 탭(takbon-dev) → `_deploy_now` 자식 캐리어 스폰 + `nested_child_mult`.
단독 가치: "배달 마법" — 산탄진 안에 유도 단발진을 박으면 산탄이 퍼진 자리마다 유도탄이 또 나간다. 회귀 그물: children 빈 도안 = 기존과 픽셀 동일(뮤테이션), 저장 라운드트립(서브리소스), 깊이 캡.

**M3 — 심화 (필요해지면).** 줌 인 직접 그리기(UX ①) · 깊이 2 손맛 · 마나 노드 합산 · fill 실측 전환 · 밸런스 조임.

M1을 먼저 하는 이유: 비용이 더 낮고(기계 절반이 이미 있다), M2의 자식 진도 복합 룬을 품을 수 있어 순서가 자연스럽다. 역순이면 M2를 M1 뒤에 다시 열어야 한다.

---

## ⑧ 사용자 결정점 (AskUserQuestion 소재)

1. **자식 진 넣기 = 완성 도안 박아넣기(스냅샷)로 시작?** (추천 ②박아넣기 → 줌인은 후속. "그린 것만 박을 수 있다"로 정체성 유지) — vs 처음부터 줌 인 직접 그리기(큰 공사).
2. **자식 전개 = 칸 방향으로 재발사**(추천 — 배치가 방향을 정함) vs 착탄점 제자리 전개?
3. **한 탄 셋업+기폭 허용?** (추천: 허용 + fill 나눔·그린 순서가 브레이크) vs 같은 탄 안 반응 금지?
4. **복합 룬 상한 2개 시작?** (fill 합 상한은 진 크기·종이에 묶음)
5. **fill 입력 = 룬 크기 휠 그대로?** (추천 — 실측은 후속) 
6. **재귀 깊이 캡 2 · 자식 감쇠 0.6 시작값?** (전부 balance — 쏴 보고 조임)
7. **취약 이중 증폭(세50 빚)** — 복합이 이걸 키우는데, 이번에 "의도(조합 보상)"로 확정할지 "사고(한 번만 곱함)"로 고칠지.
8. (곁가지) `rune: int` 미러 유지 확인 — 옛 세이브·HUD 소비자 보호용.

---

## 검증 포인트

- **헤드리스 가능**: to_assembly 재귀 라운드트립(저장→로드→재발사 점수 유지) · runes 폴백(옛 도안 무변경 — 뮤테이션으로 검출력) · rune_hits 순서→반응(status_holder는 순수 로직) · density 배율 · 자식 캐리어 스폰 수·감쇠 배율·깊이 캡 · **두 몸 각각**(세56: dummy만 되돌려도 그린이었다).
- **실게임만**: 책 「도안」 탭·[룬 추가] 클릭 도달(push_input — 세25 함정) · 판 위 자식 렌더·두 번째 룬 가이드 위치 · 자식 전개가 눈에 읽히는지 · fill 손맛(직접 그려야 함 — 채점 수치는 헤드리스 불가).
- ⚠ .tres에 자식 서브리소스가 실리므로 **로드 확인 그물**(세50 "파일 만들었다≠완료") — 저장 후 Db가 아니라 SaveManager 경로지만 같은 병: 라운드트립 테스트가 자식 필드까지 비교해야 한다.
