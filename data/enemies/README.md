# data/enemies — 적 카탈로그

🔴🔴 **늑대(`hound`)가 첫 「진짜」 몬스터다.**

세99까지 여기 있던 `slime`·`mist`·`beetle`·`vine`(+ 네임드 `mist_elder`·`beetle_ancient`)은
**콘텐츠가 아니라 플레이스홀더**였다 — 세션이 임의로 만들어 채워 둔 것이고, 사용자 확정으로 지웠다
(원문: *"저것은 니가 임의로 추가한 몬스터들이고 늑대부터는 진짜게임에 쓸몬스터 추가하는거임"* ·
*"일단 늑대만 있으면 됨 깔끔하게 지우셈"*).

**앞으로 몹은 차차 추가된다. 새 몹 = 여기 `.tres` 한 장이다 — 기계는 전부 살아 있다.**

## 지금 있는 것

| id | 무엇 |
|---|---|
| `hound` | 잡몹. 챕터 1~3의 유일한 잡몹이다 |
| `hound_alpha` | 네임드(늑대의 강화판 — `size`·`tint`로 알아본다) |
| `slime_elite` · `gale` · `snake_boss` | 챕터 1·2·3 **보스** (잡몹이 아니다 — 지우지 마라) |

## 새 몹을 붙일 때 (기계는 이미 다 있다)

1. `data/enemies/<id>.tres` 한 장 — **파일명 == `id`가 규약**이다(`Db`가 그렇게 찾는다).
   행동은 `params.ai`(`chase` 기본 · `charge` · `hover` · `stationary` · `boss_snake` · `boss_gale`),
   생김새는 `params.sprite`·`size`·`tint`, 박자는 `params.anim_fps`, 맞는 몸은 `params.hitbox_radius`.
2. 드롭은 `drops`(`DropEntry`) — ⚠ `item_id` ↔ `unlock_id`는 **배타**이고, `unlock_id` ↔ `until_unlock`을
   **병용하면 `chance`가 통째로 무시돼 모든 잡몹 확정 드롭이 된다.**
3. 무대에 세우려면 `data/chapters/*.tres` — 자리를 손으로 박으려면 `mob_spawns`의 `enemy_id`,
   **돌려 가며 세우려면 `mob_pool`에 `MobWeight` 한 줄**(그 자리는 `pool_tag`만 쥔다).
4. 스프라이트는 `takbon-art`가 그린다 — 🔴 **도형 플레이스홀더 금지.**

## 지금 비어 있는 자리 (일부러 그렇다)

`mat_beetle_shell`·`mat_mist_essence`·`mat_slime_core`·`mat_vine`는 **떨구는 잡몹이 잠시 0곳**이다
(보스 셋이 일부 떨군다). 레시피·아이템은 **한 줄도 안 지웠다** — 그 자리는 「차차 추가할」 몹이 채운다
(사용자 확인). 🔴 **억지로 다른 몹에 갖다 붙이지 마라.**

## 그물

- `tests/test_progression_auto` — 이 폴더를 **전수 스캔**해 Db 로드를 잰다(`ENEMY_COUNT_EXPECTED`를
  같이 고쳐라) + 잡몹 재료·두루마리 드롭표.
- `tests/test_enemy_hitbox_auto` — `REQUIRE_KEY`에 든 적은 `hitbox_radius`를 반드시 쥔다.
- `tests/test_enemy_ai_auto` — AI 갈래(방어·재생·분산·leash)는 **in-memory 주입**으로 잰다
  (그 갈래를 쓰는 실적이 0종이어도 기계가 안 죽게 — 세61 콘텐츠 리셋과 같은 수법).
- `tests/test_chapter_auto` — 챕터별 배치 수(`MOB_COUNT`)·풀·네임드가 실재하는 적을 가리키나.
