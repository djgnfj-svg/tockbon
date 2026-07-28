extends Node2D
## 챕터 보스방 (세58-B 세피리아식 메인 루프) — 옛 `forest.gd`의 원정 계약을 물려받은 축소판.
## ⚠ 아래에서 「forest.gd·forest.tscn 이관」으로 부르는 두 파일은 **세58-B에 삭제됐다**
## (찾지 마라 — 필요하면 git 이력). **원정 계약의 라이브 정본은 이 파일이다.**
##
## 루프: 베이스 숲길 [E] → 챕터 선택 → 이 방(보스 + 잡몹) → 처치 → 낱개 드롭 줍기 → 귀환 [E] → 베이스.
## ⚠ 「상자 루팅」 단계는 없다 — 상자는 세66에 은퇴했고 모든 적이 낱개로 떨군다(`drop_roll.spawn_loose`).
## 죽으면 즉시 베이스 + 가방 손실(bag_lost). 어느 챕터인가는 `GameState.pending_chapter`가 나른다
## (change_scene_to_file이 인자를 못 실어 오토로드가 나른다 — in_expedition과 같은 결).
##
## 🔴🔴 **나가는 길은 「상시 출구」 한 종류뿐이다** (세99 D1·D7 — **포탈은 세99에 은퇴했다**).
##  • 전부 `zone_id = &"exit"`이고 전부 `_extract` **하나**로 간다. **처음부터 서 있고 조건이 없다.**
##  • 여럿 — `ChapterDef.extract_points`에 좌표를 적으면 그 자리에 `exit_zone.tscn`이 선다.
##    비면 씬의 남쪽 `$Exit` 하나 = **세98까지와 동일**(회귀 0).
##    🔴 **단수 참조를 되살리지 마라** — `_exits` 배열이 ⓐ `_extract` 연결 ⓑ `_fill_tiles` 흙길의
##    **공통 출처**다. 하나라도 빠지면 「E는 먹히는데 아무 일도 안 나고 가방이 조용히 증발」하거나
##    「나갈 데가 있는 줄 모른다」가 된다(설계 §6 S12).
##  • 홀드 — `InteractZone.hold_sec`은 **길이가 아니라 스위치**다(실제 초 = `balance.extract_hold_sec`).
##    켜는 자리는 `_wire_extract_zone` **한 곳**이다 — 연결과 홀드를 같이 걸어야 새 길을 뚫을 때
##    한쪽만 빠지지 않는다.
##
## 🔴 **은퇴한 것 = 보스 자리 「귀환 포탈」**(`zone_id = &"portal"` · `src/props/portal.tscn` 삭제).
##  사용자 확정(세99): *"보스죽으면 포탈 x"*. **왜 없앴나** — D1이 탈출구를 여럿으로 만들고 D7이
##  전부 꾹 눌러 나가게 했는데 **포탈만 「보스를 잡아야 열리는 특별한 물건」**으로 남아 규칙이 둘이
##  됐다. 지금은 **보스를 잡아도 살아서 출구까지 돌아가야 한다**(익스트랙션의 결).
##  🔴 **`&"portal"`을 되살리지 마라** — 그 값을 쥔 씬도·스폰하는 코드도·재는 그물도 전부 없앴다.
##  보스 자리에서 남쪽까지 되돌아가는 먼 길은 **`extract_points`에 보스 근처 좌표를 한 줄** 적어
##  덜어 준다(= 지름길도 그냥 「상시 출구」다. **데이터라 F5로 옮길 수 있다** — 코드가 아니다).
##
## 🔴 **한 씬 + ChapterDef 파라미터다** — 챕터별 씬 3장을 만들지 않는다(설계 확정). 방 구성이
## 동일(바닥·보스 하나·입구)하고 다른 건 데이터(보스·색)뿐이라, 씬을 늘리면 mouse_filter·z_index·
## 레이어 함정을 그 수만큼 다시 밟는다. "새 챕터 = data/chapters/*.tres 한 장"이 여기서 성립한다.
## ⚠ **세99: 위 「설계 확정」은 뒤집혔다** — 사용자가 챕터마다 무대를 따로 만들기로 정했고
##  (`docs/takbon-design/dungeon_structure_design.md` D8), 그 손잡이인 **`ChapterDef.room_scene_path`가
##  이미 들어와 있다**. 이 씬은 이제 **그 필드가 비었을 때의 기본값**이다.
##  🔴 위 문단이 경고한 함정(mouse_filter·z_index·레이어)은 **여전히 유효하다** — 그래서 새 맵은
##  **상속 씬**으로 만들어 이 씬의 노드 계약을 물려받는 것을 권한다(설계 §7 단계 4).
##
## 🔴🔴 **세99 D5·D6 — 무대는 고정, 서 있는 것은 매 판 굴러간다.**
##  • **몹 풀**(D5): `MobSpawn.pool_tag` → `ChapterDef.mob_pool`에서 **weight 비례**로 뽑는다.
##    🔴 **좌표는 절대 안 굴린다**(사용자 확정 *"지형은 동일하고 나오는 몬스터들이 랜덤"*) —
##    자리는 지형이 정하는 것이라 사람이 놓고, 바뀌는 건 「거기 뭐가 서 있나」뿐이다.
##    `pool_tag`가 비면 `enemy_id` 그대로 = **세98까지와 동일**(회귀 0).
##  • **네임드**(D6): `ChapterDef.named_pool`을 **항목마다 독립으로** 굴린다.
##    🔴 **「하나도 안 뜸」이 정상 결과다** — 그게 「오늘 뭔가 있다」를 만든다.
##    🔴 **표시는 생김새다(덩치·몸 색조) — 빛나게 하지 마라**(*"몸에서 빛이나는거 까진 별로임"*).
##    오라·HUD 알림·입장 문구는 **각하됐다.**
##    ✅ **세101: `at_landmark`가 해석된다**(D13) — 채우면 **그 지점 자리마다** 확률로 선다.
##    🔴 우두머리는 **잠금이 아니다**(D10-b) — 잡든 말든 [E]로 열린다.
##  • **지점**(D3·D4 — 세99 단계 3): `ChapterDef.landmarks` → `Db.landmarks` → 프롭 씬(`_spawn_landmarks`).
##    🔴 **자리는 절대 안 굴린다**(`MobSpawn`과 같은 이유 — 지형이 정하는 것이다).
##    🔴🔴 **지점을 세우면 입구에서 거기까지 흙길이 깔린다**(`_landmark_road_cells`) — 방이 열린 숲이라
##     길이 없으면 「저쪽에 뭔가 있다」를 알 방법이 아예 없다. 세우기만 하고 길을 안 깔면 **에러 0으로
##     아무도 안 가는 물건**이 된다(출구가 겉모습 없이 서는 것과 같은 병 — 설계 §6 S12).
##    ✅ **세101(N26): 밟을 수 있게 됐다** — 지점이 [E] 한 번에 열리고(D10) **한 판에 한 번뿐**이며(D11)
##     열리면 `opened`가 온다. **산출을 굴려 뿌리는 건 여기다**(`_on_landmark_opened` · 설계 §3 소유권 ⓑ) —
##     지점 씬은 자기가 무엇을 주는지 **모른다**. 🔴 재열기 가드는 **지점이 진다**(S25 — 가드를 두 벌로
##     두면 한쪽을 지워도 그린이다). ⚠ 무한 스폰·핵 깨기는 **각하됐다**(D10·D11) — 만들지 마라.
##  🔴🔴 **잡몹·네임드는 `_spawn_enemy_at` 한 문을 지난다 — 거기 보스 id 제외 가드가 있다**(설계 §6 S9).
##   새 스폰 경로를 만들거든 **그 문을 지나게 해라.** 안 지나면 풀에 보스 id가 섞이는 날
##   **잡몹 한 마리로 `chapter_clear_*` + 보상 룬이 조용히 나간다(에러 0).**
##  🔴 **시드를 고정하지 마라** — 랜덤이 전역 스트림 하나뿐이라 테스트가 `seed()`를 잡으면 드롭 굴림 등과
##   스트림을 나눠 써 flake가 된다. 그물(`tests/test_mob_roll_auto.gd`)은 **확률·가중치 양끝을 주입**해 잰다.
##
## 🔴 **HP는 GameState가 쥔다** — 오토로드라 씬을 갈아타도 남는다 (forest.gd와 같은 이유).
## 출격 = 만HP/만마나는 **이 씬이 한다** (베이스가 아니다 — 다른 진입 경로로 들어가면 조용히 달라진다).
##
## 씬(boss_room.tscn) 쪽 결정 — .tscn엔 주석을 못 달아서 여기 적는다 (forest.tscn 주석 이관):
##  • 🔴 **`Ground.mouse_filter = 2`(IGNORE) — 지우면 발사가 통째로 죽는다.** Ground는 화면을
##    다 덮는 ColorRect인데 Control의 기본 mouse_filter는 STOP이라 바닥이 좌클릭을 전부 먹는다
##    → `_unhandled_input`에 안 와서 발사가 아예 안 불린다. **에러도 경고도 없고, 헤드리스로는
##    절대 못 잡는다** (세25 베이스·세26 숲이 정확히 이걸로 밟았다 — 새 씬마다 되살아나는 함정).
##  • `RingSpellSystem.z_index = 10` — 안 올리면 날아가는 진·탄·기둥이 Ground(z=0) 뒤에 가려 안 보인다.
##  • 나무는 **물리 몸이 없는 장식**(tree.tscn) — StaticBody2D로 만들면 world 레이어라 캐리어(마스크 5)가
##    나무마다 터진다. 🔴 **세99에 감지용 `Area2D`가 하나 붙었다**(플레이어가 뒤로 가면 비치게 —
##    tree.gd 머리말) — 그 Area는 `collision_layer = 0`이라 **아무도 나무를 감지하지 못한다.**
##    레이어를 채우는 순간 위 함정이 그대로 되살아난다.
##    ⚠ 겹치면 **가린다** — 프롭은 다섯 규칙으로 놓는다(ⓐ~ⓔ · `_spawn_props` 참조):
##    ⓐ 잡몹·네임드·보스 스폰(`ChapterDef.mob_spawns`·`named_pool`·`boss_spawn`)에서 **100px 이상**
##    ⓑ 플레이어 스폰·**모든 탈출구**에서 **150px 이상**(시작 시야·[E] 찾기)
##    ⓒ 어귀·중간·깊은 대역에 고르게
##    ⓓ 🔴 **흙길 위 금지** — 출구는 겉모습이 없어서 **보이는 안내가 그 길뿐**이다(설계 §6 S12).
##       길 위에 나무가 서면 「나가는 길이 막혔다」로 읽힌다.
##    ⓔ 🔴 **지점(둥지) 둘레를 비운다** — 랜드마크가 프롭에 파묻히면 「저건 다르다」가 죽는다.
##    🔴🔴 **세101: 이 다섯이 사람의 손버릇에서 코드로 내려왔다** — 그전엔 씬에 나무 20그루를 손으로
##     찍고 위 규칙을 **주석으로만** 들고 있었다(= 어겨도 아무도 모른다). 지금은 `_spawn_props`가
##     규칙을 실행하고 `tests/test_prop_layout_auto.gd`가 **손으로 놓은 20그루까지 같은 목록으로**
##     잰다 — 규칙은 「누가 놓았나」를 안 본다.
##    🔴 스폰 좌표의 **정본은 `data/chapters/*.tres`의 `position`이다**(설계 문서 §13-2 표와 이미
##     갈라져 있다) — 그래서 `_spawn_props`는 그 데이터를 직접 읽는다(좌표를 코드에 안 베낀다).
##  • 방 크기 **2400×2200**(x −1200~1200 · y −1500~700, 세88에 1200×1040에서 키웠다) — 세로로 긴
##    이유는 남쪽 입구(플레이어 스폰 y=+600)에서 북쪽 보스(y=−1350)까지 「깊이 들어간다」가 이동으로
##    읽히게. 구역(어귀·중간·깊은)은 **코드 개념이 아니라 `mob_spawns` y좌표 관례**다 — 새 스키마 0.
##  • 🔴🔴 **세99: 방은 낮이다** (사용자 확정 *"조명이 좀 어색하네? 그냥 낮으로 바꾸자"*).
##    바뀐 축 셋 — ⓐ `Dusk`(CanvasModulate 0.85,0.84,0.93) → **`Daylight`(1,0.99,0.96)**: 앰비언트로
##    화면을 누르지 않는다. ⓑ **횃불 8개 삭제**(아래 참조) → 볕뉘 `Sun1~4`+`SunGlade`. ⓒ 바닥 =
##    **낮 밝기로 그려진 새 시트**(`tileset_ground.png` = 타일셋 source 2)로 갈았고,
##    `ChapterDef.room_ground_color`는 **옅은 틴트**로만 얹힌다(`_apply_chapter_tint`).
##    🔴 그 사이에 잠깐 있던 `_apply_floor_daylight`(검은 타일을 2~3배로 밝히던 우회로)는 **지웠다** —
##    이미 밝은 시트에 그 곱을 물리면 **에러 0으로 화면만 형광색이 된다**(그 함수 자리의 주석 참조).
##    🔴 **세73(「밝게 유지 + 빛 웅덩이만」)로 되돌아간 것이지 그 결정을 뒤집은 게 아니다** — 어두운
##    던전·노멀맵은 그때 각하됐는데 이 방이 그새 어두워져 있었다.
##  • 🔴 **횃불(따뜻 · energy 0.9 · x=∓500 · y ∈ {+450,−150,−750,−1300})을 왜 지웠나**: 낮엔 「누가
##    켰나」가 설명되지 않고, 무엇보다 **밝은 바닥 위의 additive 웅덩이는 빛이 아니라 희뿌연 얼룩**으로만
##    읽힌다(세99 전 스샷이 정확히 그 그림이었다 — 사용자가 *"어색하다"*고 한 자리). 「빛 웅덩이」축은
##    죽이지 않고 **볕뉘**(energy 0.22 · 따뜻 · 넓게 · 비대칭)로 옮겼다. 되살리고 싶거든 **밤 챕터를
##    만들 때** 되살려라 — 낮 방에 다시 걸면 같은 얼룩이 돌아온다.
##
## 🔴 바닥 타일은 `_ready`가 코드로 깐다 — .tscn에 tile_map_data 베이스64를 손으로 굳히면
## 방 크기를 바꿀 때마다 에디터로 다시 칠해야 한다. Ground rect에서 셀 범위를 파생시켜 늘 맞는다.

const InteractZone := preload("res://src/actors/interact_zone.gd")
const Player := preload("res://src/actors/player.gd")
const Hud := preload("res://src/hud/hud.gd")
## 범용 보스 스폰 몸 — ChapterDef.boss_scene_path가 비면 이 씬 + enemy_id로 스폰한다.
## preload가 안전한 이유: forest_enemy는 boss_room을 안 문다 (base⇄forest 순환 함정 무관).
const EnemyScene := preload("res://src/field/forest_enemy.tscn")
## 🔴 늘린 탈출구 (세99 D1) — **`zone_id = &"exit"`을 파일에 굳힌 전용 프롭**이다.
## ⚠ 겉모습은 없다(씬의 `$Exit`와 같은 결) — **보이는 표시는 `_fill_tiles`의 흙길이 전부**다.
##  좌표만 늘리고 길을 안 깔면 플레이어는 「거기 나갈 데가 있다」를 알 방법이 없다(설계 §6 S12).
##  ⚠ 설계 문서(§6 S12)·이 파일의 옛 서술이 그 표시를 **「풀길」**이라 부른다 — 세99에 **흙길**로 갈았다.
const ExitZoneScene := preload("res://src/props/exit_zone.tscn")
## 🔴 codex 해금 id → 「이름(어디에 쓰는지)」 단일 소스 (세87 S4). 여기서 `Db.get_glyph_ring` 하나만
## 부르면 **룬 보상이 원시 id + 거짓 안내**("rune_water(책상에서 밴드에 끼워라)")로 나간다 —
## 밴드는 고리 자리고 룬은 중심 자리다. 발신처가 셋(클리어·제작·두루마리)이라 core에 뽑혀 있다.
const CodexText := preload("res://src/core/codex_text.gd")
## 🔴🔴 드롭 굴림·낱개 스폰의 **단일 소스** (세101 · 설계 §10-4 **S17**). 적(`forest_enemy`)과 지점이
##  **같은 함수**를 부른다 — 지점이 자기 굴림을 새로 쓰면 `DropEntry`의 배타 짝 규칙 셋이 두 벌이
##  되고 그게 조용히 갈라진다(takbon-rules §5-1).
## ⚠ **여기 굴림 로직을 적지 마라** — 이 파일이 지는 건 「언제·어디에」뿐이고 「무엇이 몇 개」는 저기다.
const DropRoll := preload("res://src/field/drop_roll.gd")
## 🔴 시야 안개 (세104) — 부채꼴 밖을 **20%만** 누르는 화면 덮개. 이 방에만 선다(마을엔 시야가 없다).
##  ⚠ 이 파일이 지는 건 「어디에 얼마나 크게」뿐이다 — 모양·수치는 그 노드가 balance에서 직접 읽는다.
const VisionOverlay := preload("res://src/actors/vision_overlay.gd")

## 돌아갈 곳 — 🔴 **PackedScene이 아니라 경로다. 바꾸지 마라.** base가 boss_room을 경로로 물고
## boss_room이 base를 PackedScene으로 물면 **순환 preload**로 한쪽이 노드 0개 껍데기가 돼
## 귀환·사망 시 베이스로 못 돌아간다 (세26 forest가 실측 — 헤드리스는 못 잡고 실게임 부팅에서만 드러난다).
@export_file("*.tscn") var base_scene_path: String = "res://src/base/base.tscn"

## 쓰러진 뒤 베이스로 돌아가기까지 (초) — 연출값. 0이면 뭘 맞고 죽었는지 못 보고 화면이 바뀐다.
const DEATH_BEAT_SEC := 0.9

## 🔴🔴 **바닥은 source 2 한 장이 전부다** (세99 — `assets/sprites/field/tileset_ground.png`).
## 옛 `TILE_SRC_GRASS = 0`(마을 풀 · 나가는 길)·`TILE_SRC_FLOOR = 1`(거의 검은 슬레이트 · 방 바닥)은
## **이 씬에서 소비자가 사라졌다.** 두 source는 타일셋에 그대로 살아 있지만 방은 안 쓴다
## (지우려면 타일셋을 손대야 하고, 그건 source id를 밀어 이 상수를 조용히 어긋나게 한다 — 그냥 둔다).
## ⚠ **길의 종류가 바뀌었다**: 나가는 길은 「밝은 풀 네모」가 아니라 **흙길**이다. 낮이 되며 바탕도
##  초록이 되자 풀길이 길로 안 읽혔다(리드 스샷 확인). 그물(`test_extract_hold_auto`)도 같이 옮겼다 —
##  「풀 칸이 이어지나」 → 「**흙길 칸**이 이어지나」.
const TILE_SRC_GROUND := 2

## 🔴 이웃 비트마스크 — 「어느 변이 흙이 아닌가」(cons)·「어느 쪽으로 이어지나」(conn)에 같이 쓴다.
const DIR_T := 1
const DIR_B := 2
const DIR_L := 4
const DIR_R := 8

## 🔴🔴 흙길 아틀라스 표 — **이웃이 좌표를 고른다**(9분할 오토타일). 키 = 흙이 **아닌** 변의 비트마스크.
## 정본 = `docs/_reports/tile_dirt.md` §3 + 실측(칸마다 변의 풀 픽셀을 세어 대조했다).
## 🔴 **좌표를 짐작하지 마라** — 시트 40칸은 「넓은 길(9분할)」과 「폭 1칸 오솔길」이 섞여 있고
##  둘은 변의 풀 두께가 다르다(실측 12px ↔ 24px). **한 줄기 안에서 섞으면 이음매가 어긋난다.**
const ROAD_EDGE := {
	0: Vector2i(5, 0),            # 사방이 흙 = 중앙 (변형은 `_road_center_atlas`가 고른다)
	DIR_T: Vector2i(1, 0),        # 위가 풀 = 상변 A (B는 `_road_edge_atlas`가 번갈아 깐다)
	DIR_B: Vector2i(1, 1),        # 아래가 풀 = 하변 A
	DIR_L: Vector2i(4, 0),        # 왼쪽이 풀 = 좌변
	DIR_R: Vector2i(6, 0),        # 오른쪽이 풀 = 우변
	DIR_T | DIR_L: Vector2i(0, 0),
	DIR_T | DIR_R: Vector2i(3, 0),
	DIR_B | DIR_L: Vector2i(0, 1),
	DIR_B | DIR_R: Vector2i(3, 1),
}
## 상·하변의 B판 — 🔴 **같은 것만 이으면 굴곡이 주기로 반복돼 격자가 보인다**(art 손질 1·3회차의 결함).
const ROAD_TOP_B := Vector2i(2, 0)
const ROAD_BOTTOM_B := Vector2i(2, 1)
## 안쪽 모서리(흙 한복판에 풀이 모서리로 파고든 칸) — 키 = 파고든 모서리의 비트마스크.
const ROAD_NUB := {
	DIR_T | DIR_L: Vector2i(4, 1),
	DIR_T | DIR_R: Vector2i(5, 1),
	DIR_B | DIR_L: Vector2i(6, 1),
	DIR_B | DIR_R: Vector2i(7, 1),
}
## 폭 1칸 오솔길 — 키 = 흙으로 **이어지는** 변의 비트마스크(9분할과 키의 뜻이 반대다).
## ⚠ 지금 방의 길은 전부 3칸 폭이라 여기로 안 온다. 랜드마크 길을 1칸으로 깔 때 산다.
const ROAD_NARROW := {
	0: Vector2i(4, 4),                     # 외딴 한 칸 — 시트에 없는 형태라 맨흙으로 떨어뜨린다
	DIR_T: Vector2i(0, 3),
	DIR_B: Vector2i(1, 3),
	DIR_L: Vector2i(2, 3),
	DIR_R: Vector2i(3, 3),
	DIR_T | DIR_B: Vector2i(0, 2),
	DIR_L | DIR_R: Vector2i(2, 2),
	DIR_B | DIR_R: Vector2i(4, 2),
	DIR_B | DIR_L: Vector2i(5, 2),
	DIR_T | DIR_R: Vector2i(6, 2),
	DIR_T | DIR_L: Vector2i(7, 2),
	DIR_B | DIR_L | DIR_R: Vector2i(5, 3),
	DIR_T | DIR_L | DIR_R: Vector2i(6, 3),
	DIR_T | DIR_B | DIR_R: Vector2i(7, 3),
	DIR_T | DIR_B | DIR_L: Vector2i(0, 4),
	DIR_T | DIR_B | DIR_L | DIR_R: Vector2i(4, 3),
}
const ROAD_NARROW_VERT_B := Vector2i(1, 2)
const ROAD_NARROW_HORZ_B := Vector2i(3, 2)

## 🔴 벌판·길 한복판의 **변형** — 「무늬 없는 한 칸을 반복해 깔면 벌판이 단조롭다」의 답이다.
## ⚠ **얼룩 칸 (7,4)는 일부러 뺐다** — 변에 걸친 풀 얼룩이 16%라 **자기 자신 옆에서만** 이어진다
##  (실측: 변 픽셀 256칸 중 42칸이 흙이 아니다). 섞어 깔면 반쪽 얼룩이 잘려 이음매가 튄다.
const GRASS_PLAIN := Vector2i(1, 4)
const GRASS_SUN := Vector2i(2, 4)     # 볕에 마른 풀
const GRASS_SPROUT := Vector2i(3, 4)  # 새순·잔꽃 (밝은 점 — 조금만)
const ROAD_CENTER_B := Vector2i(7, 0)
const ROAD_WEEDY := Vector2i(6, 4)    # 잔풀 난 흙 — 🔴 긴 길의 단조로움을 깨는 칸
const ROAD_GRAVEL := Vector2i(5, 4)

## 🔴 풀 타일(시트 (1,4))의 **바탕색** — 64×64 중 95%가 이 한 색이다.
## 🔴 **PNG에서 베낀 사본이다**(옛 `FLOOR_TILE_BASE`가 같은 자리였다) — 그림을 다시 그리면 낡는다.
##  그물(`tests/test_daylight_tree_auto.gd`)이 PNG를 직접 읽어 이 상수와 대조하므로 어긋나면 빨개진다.
const GRASS_TILE_BASE := Color(0.2745, 0.5098, 0.1961)

## 🔴🔴 챕터 색을 **옅은 틴트**로 읽는 세기 (세99 — 옛 `_apply_floor_daylight`의 자리).
## 0이면 세 챕터가 한 색이 되고(D8이 죽는다), 1에 가까우면 채도·명암이 세져 흙이 형광으로 탄다.
## ⚠ 상·하한은 **안전선**이다 — 새 챕터가 아주 진하거나 아주 어두운 색을 실어도 곱이 여기를 못 넘는다
##  (하한이 없으면 「어두운 챕터」 하나가 방을 다시 밤으로 되돌린다 — 세99에 뒤집은 그 상태다).
##
## 🔴 **밝기를 정규화하지 않는다 — 그게 D8의 몸이다.** 챕터마다 색의 **평균을 1로** 맞춰 색조만
##  남겨 봤더니(첫 시도) 세 챕터의 화면색 차이가 채널당 **3~4/255**로 줄어 사실상 한 무대가 됐다
##  (세98까진 바닥이 `room_ground_color` **그 자체**여서 「깊은 숲」이 눈에 띄게 어두웠다).
##  그래서 기준을 **고정 참조 밝기**로 잡는다 — 챕터가 그보다 어두우면 방도 그만큼 어두워진다.
## ⚠ `CHAPTER_TINT_REF_LUM`은 데이터의 사본이 아니라 **「곱이 1이 되는 챕터 밝기」라는 기준점**이다
##  (지금 세 챕터의 평균 밝기가 0.25~0.34라 그 한복판을 잡았다). 챕터를 더 밝게/어둡게 만들고 싶으면
##  **`data/chapters/*.tres`의 `room_ground_color`를 움직여라** — 그게 F5로 조이는 손잡이다.
const CHAPTER_TINT_STRENGTH := 0.42
const CHAPTER_TINT_REF_LUM := 0.32
const CHAPTER_TINT_MIN := 0.80
const CHAPTER_TINT_MAX := 1.12

## 출구에서 방 밖으로 이어지는 **흙길** (칸 수 — 연출값). 출구 자체는 겉모습이 없는 InteractZone이라
## (보라색 차원문 Polygon2D를 베끼지 않기로 한 결정) **이 길이 「저기가 나가는 길」의 유일한 표시**다.
## 🔴 **길의 중심은 출구 노드에서 파생한다** — 좌표를 두 번 적으면 출구를 옮길 때 길만 제자리에 남는다.
## 🔴🔴 **`EXIT_PATH_ROWS = 0`은 「나가는 길」만 끈다**(세100에 현행화 — 세99 단계 3에 갈렸다).
##  `_road_cells`에서 이 손잡이가 감싸는 건 **출구 줄기 ⓐ뿐**이고, **들어가는 길**(입구→지점)은
##  `_landmark_road_cells`가 그 밖에서 깐다 — 그 손잡이는 **`ChapterDef.landmarks`**다(비우면 사라진다,
##  `test_landmark_road_auto [7]`이 그 파생을 잰다). 0으로 두고 「길이 다 꺼졌다」고 읽지 마라.
## ⚠ 폭을 1로 줄이면 시트의 **오솔길 칸**(`ROAD_NARROW`)으로 갈린다 — 두 줄기가 **같은 폭**을 쓰므로
##  `EXIT_PATH_WIDTH_CELLS`는 들어가는 길에도 그대로 걸린다(`_road_cells`가 `half`를 둘에 같이 넘긴다).
## 🔴 **길이를 3 → 7로 늘렸다**(세99): 3칸이면 폭(3칸)과 같아 **정사각형 얼룩**으로 읽힌다 —
##  타일만 흙으로 갈고 길이를 그대로 뒀더니 「색만 바꾼 네모」가 됐다(실측 스샷). 길은 **폭보다
##  뚜렷하게 길어야** 「어디로 이어지는 것」으로 읽힌다. ⚠ 그물(`test_extract_hold_auto`)이 이 값을
##  **손으로 들고** 대조한다 — 여기만 바꾸면 빨개진다(그게 「연출값이 조용히 흐르는 것」을 막는다).
const EXIT_PATH_WIDTH_CELLS := 3
const EXIT_PATH_ROWS := 7

## 🔴 D7 — 탈출 지점의 홀드를 **켜는** 값. `InteractZone.hold_sec`은 「몇 초」가 아니라
## 「0이냐 아니냐」 스위치라(실제 초 = `balance.extract_hold_sec`) 맨숫자 `1.0`을 씬·코드에 흩뿌리면
## 다음 사람이 **1초로 읽는다.** 이름을 붙여 그 오독을 막는다.
const HOLD_ON := 1.0

## 🔴🔴 **지점 노드 ↔ `landmark_id` 짝** (세101 N26 · 설계 §10-4 **S27**의 「덤」).
##
## 🔴 **왜 필요한가**: `_landmarks`는 **노드만** 들고 id를 안 든다. 그런데 두 소비자가 id를 묻는다 —
##  ⓐ 열렸을 때 「어느 지점의 `drops`인가」 ⓑ `NamedSpawn.at_landmark`가 「어느 자리인가」.
## 🔴 **왜 meta인가 — 슬롯 배열을 다시 훑는 쪽을 안 골랐다.** 다시 훑으면 「몇 번째 노드가 몇 번째
##  슬롯인가」를 **순서로** 맞춰야 하는데, `_spawn_landmarks`는 실패한 슬롯을 `continue`로 건너뛴다
##  → **슬롯 하나가 죽는 순간 그 뒤가 통째로 한 칸씩 밀리고 에러가 0이다.** meta는 노드를 만든
##  **그 줄에서** 붙으므로 어긋날 자리가 구조적으로 없다.
## ✅ **S27이 여기서 풀린다** — 같은 `landmark_id` 슬롯이 둘이면 노드도 둘이고 **둘 다 같은 meta**를
##  들어서, `_landmark_sites`가 「첫 번째」가 아니라 **전부**를 돌려준다.
const LANDMARK_ID_META := &"landmark_id"

## 🔴🔴 **프롭 표 — 「새 프롭 = 씬 한 장 + 여기 한 줄」** (세101).
##
## ⚠ **큰 것부터 놓는다**(위에서 아래로) — 큰 것이 자리를 먼저 잡고 작은 것이 사이를 채운다.
##  🔴 **다만 이건 손버릇이지 계약이 아니다** — 세101에 순서를 뒤집어 실측했더니 ch1 나무가 **35 → 33**,
##   나머지 층은 ±2였다(격자 칸마다 종류가 하나로 정해져서 서로 자리를 다투는 일이 애초에 적다).
##   그물도 이 순서를 **안 지킨다**(뒤집어도 그린이다). 「순서를 뒤집으면 나무가 사라진다」고 적어 두면
##   그게 곧 T4(주석이 계약인 척하는데 아무도 안 재는 것)라서 여기 실측을 남긴다.
## 🔴 크기 계단이 **128(나무) → 42(수풀)**(그 사이에 플레이어 56)이라 아트가 일부러 층을 만들어 뒀다 —
##  큰 것만 늘리면 「기둥 밭」이 그대로고, 작은 것으로 사이를 채워야 깊이가 생긴다.
##  ⚠ 세107에 중간 계단(큰 바위 64·잔돌 18)이 빠져 **층이 둘뿐이다**(아래 은퇴 문단).
##
##  • `share` = 격자 한 칸이 이 종류가 될 확률(백분위 · 누적으로 잘린다). 둘의 합 32 = 나머지 68%는 빈칸.
##    ⚠ **후보 수 ≠ 선 수다** — 나무는 회피·겹침에 가장 많이 걸려 후보의 절반쯤만 선다. `share`를
##     조일 땐 그물이 찍는 실제 개수(`test_prop_layout_auto [1]`)를 보고 맞춰라.
##  • `sep`   = 이웃과의 최소 간격에 쓰는 반지름 — 문턱은 **둘의 합**이다(나무끼리 120px · 수풀끼리 44px).
##  • `road`  = 🔴 **밑동 반폭**. 흙길 칸에서 이만큼 떨어진다(ⓓ).
##    ⚠ **그림 반폭이 아니라 밑동 반폭이다** — 나무는 그림이 128px인데 「길을 막는다」로 읽히는 건
##     기둥이지 가지가 아니다. 가지가 길가에 걸치는 건 오히려 숲답다(덤불은 통짜라 그림 폭 그대로).
##    🔴 그물(`test_prop_layout_auto [5]`)이 **같은 값을 따로 들고** 대조한다 — 사본이 아니라
##     「손으로 든 기대치」다(`test_landmark_road_auto`의 타일 상수와 같은 관행). 여기를 줄이면 빨개진다.
##
## ⚠ **세107에 줄 둘(`rock_big`·`rock`)과 `occlude` 키가 통째로 빠졌다** — 사용자 확정
##  (*"맵에 바위도 없애줘볼래?"* · *"구지 나무나 돌맹이에 시야가 가려지지 않도록"*).
##  🔴 **씬·PNG는 살아 있다**(`src/props/rock.tscn`·`rock_big.tscn`) — 되살리려면 **여기 줄만** 되돌려라.
##  ⚠ 그때 `share` 합이 32에서 63으로 돌아가 **빈칸이 68% → 37%로 줄어든다**(밀도가 두 배가 된다).
##  차폐(`occlude` 반경)의 경위는 `src/core/vision.gd` 머리말 · `git show`(세105~107).
const PROP_TABLE: Array[Dictionary] = [
	{"scene": "res://src/props/tree.tscn", "share": 14, "sep": 60.0, "road": 40.0},
	{"scene": "res://src/props/bush.tscn", "share": 18, "sep": 22.0, "road": 28.0},
]
## 🔴 나무만 씬의 `Trees` 아래로 간다 — 손으로 놓은 20그루와 **같은 물건**이라 홀더를 안 가른다
##  (`test_daylight_tree_auto`가 그 홀더로 나무 계약을 재므로 새 나무도 저절로 그 그물에 든다).
##  나머지(지금은 수풀 하나)는 새 `Props` 홀더로 가고, 그 홀더는 **타일 바로 뒤**에 꽂혀 몸·적·마법 아래에 깔린다.
const PROP_TREE_KIND := 0
const PROP_HOLDER := "Props"

## 배치 격자 (연출값 — 손맛). 지터를 안 주면 프롭이 **격자로 줄을 서** 벽지가 된다(`_grass_atlas`와 같은 병).
## ⚠ `PROP_JITTER`가 `PROP_GRID`의 절반에 가까워질수록 이웃이 붙어 겹침 검사가 많이 쳐낸다.
const PROP_GRID := 148.0
const PROP_JITTER := 56.0
## 방 가장자리 여백 — 프롭이 벽선 밖으로 반쯤 걸치지 않게.
const PROP_EDGE_MARGIN := 60.0
## ⓓ 흙길 회피의 **세로 두께** — 밑동이 길 칸에 걸치는지만 보면 되므로 얇다(가로는 `road` 반폭).
const PROP_ROAD_BAND := 16.0
## ⓐ 잡몹·네임드 자리 — 적이 프롭에 파묻히면 「보이는 몸에 쏜다」가 깨진다.
const PROP_CLEAR_SPAWN := 100.0
## 🔴 보스 자리만 더 넓다 — 여긴 **무대**다(볕이 드는 빈터 `SunGlade`). 뱀 보스는 마디 12개라
##  100px로는 몸이 프롭에 걸린다. ⓐ의 하한(100)을 지키면서 여기만 더 준다.
const PROP_CLEAR_BOSS := 260.0
## ⓑ 입구·탈출구 — 시작 시야와 [E] 찾기.
const PROP_CLEAR_GATE := 150.0
## ⓔ 지점(둥지) — 둥지 그림이 192×152라 반폭 96 + 여유. 파묻히면 「저건 다르다」가 죽는다.
const PROP_CLEAR_LANDMARK := 220.0

@onready var _ground: ColorRect = $Ground
@onready var _tiles: TileMapLayer = $TileGround
@onready var _tree_holder: Node2D = $Trees
@onready var _player: Player = $Player
@onready var _hud: Hud = $Hud/Hud
@onready var _fog: VisionOverlay = $VisionFog

var _chapter: ChapterDef = null
## 🔴 **나가는 길 전부**(세88 하나 → 세99 여럿). 씬의 남쪽 `$Exit` + `ChapterDef.extract_points`.
## **`_extract` 연결과 `_fill_tiles` 흙길이 둘 다 이 배열을 순회한다** — 단수 참조로 되돌리지 마라.
## ✅ 세99에 포탈이 은퇴해 **이 배열이 방의 탈출구 전량**이다(예외로 빠지는 길이 하나도 없다).
var _exits: Array[InteractZone] = []
## 🔴 이 판에 실제로 선 지점들 (세99 D3·D4 — `ChapterDef.landmarks`가 세운다).
## **`_road_cells`의 입구→지점 흙길이 이 배열에서 파생한다** — 좌표를 두 번 적으면 지점을 옮길 때
## 길만 제자리에 남는다(`_exits`가 흙길의 출처인 것과 같은 결).
var _landmarks: Array[Node2D] = []
## 🔴🔴 이 판에 실제로 깔린 **흙길 칸**(`_fill_tiles`가 채운다 — 키 = 타일 셀).
##  프롭 회피(ⓓ)가 **바로 이 표를 읽는다** — 「길이 어디 있나」를 두 번 계산하면 길 규칙을 고칠 때
##  타일과 프롭이 조용히 갈라진다(감사 T5). 그래서 `_spawn_props`는 `_fill_tiles` **뒤**다.
var _road: Dictionary = {}
## 클리어 처리는 한 번뿐 — enemy_died는 EventBus 전역이라 가드 없이는 무엇이든 두 번 처리될 수 있다.
var _cleared: bool = false
## 씬 전환은 한 번뿐 — 귀환 도중 죽거나, 죽는 중에 E를 누르면 두 번 갈아탄다 (forest 계약 이관).
var _leaving: bool = false


func _ready() -> void:
	# 🔴 출격 = 만HP/만마나 (forest.gd 계약 이관). 이게 없으면 죽는 게 이득이 된다 —
	# 다친 몸으로 출구까지 버티느니 그 자리에서 죽는 편이 싸진다.
	GameState.reset_player_hp()
	GameState.restore_mana_full()
	GameState.in_expedition = true
	# 🔴 모달 플래그를 내린다 — 오토로드라 씬 전환에도 남는다 (base.gd _ready와 같은 안전망).
	GameState.ui_modal_open = false
	_player.caster.notice.connect(_hud.say)
	_player.caster.slot_changed.connect(_hud.select)
	_hud.select(_player.caster.slot())
	# ⚠ 출구 세우기·연결은 **챕터를 안 뒤**다(`extract_points`를 읽어야 한다) — 아래 `_build_exits`.
	EventBus.player_hp_changed.connect(_on_hp_changed)
	EventBus.enemy_died.connect(_on_enemy_died)
	# 목표 달성 넛지 (세40 턴인 — forest 선례): 완료가 아니라 정산 대기라 quest_ready를 듣는다.
	EventBus.quest_ready.connect(_on_quest_ready)

	# 🔴 시야 안개를 방 바닥에 맞춘다 — 사각형은 **Ground에서 파생한다**(`_clamp_camera_to_room`과
	#  같은 이유: 방을 또 키우면 따라온다. 좌표를 베끼면 그 순간 갈라진다).
	# 🔴 **챕터 확인보다 앞이다** — 아래 `_chapter == null` 분기가 `_ready`를 통째로 끊는데,
	#  뒤에 두면 그 경로에서 크기가 0인 채 남아 노드가 「안 붙었는지 못 붙였는지」가 흐려진다.
	_fog.fit_to(Rect2(_ground.global_position, _ground.size))
	# 🔴 어느 챕터인가 — 비었거나 미등록이면 **조용히 빈 방을 띄우지 않는다** (침묵 금지).
	# F6으로 이 씬을 직접 실행하면 pending_chapter가 비어 여기로 온다 — 베이스로 되돌린다.
	_chapter = Db.get_chapter(GameState.pending_chapter)
	if _chapter == null:
		push_error("boss_room: pending_chapter '%s'가 Db.chapters에 없다 — 베이스로 되돌아간다"
			% String(GameState.pending_chapter))
		_leaving = true
		_to_base.call_deferred()
		return

	_apply_chapter_tint()
	# 🔴 **`_fill_tiles`보다 먼저다** — 흙길이 `_exits`에서 파생하므로, 순서가 뒤바뀌면 늘린 출구가
	# 화면에 **아무 표시 없이** 서고 D1이 통째로 무효가 된다(설계 §6 S12). 에러는 0이다.
	_build_exits()
	# 🔴 **지점도 `_fill_tiles`보다 먼저다 — 같은 이유이자 더 센 이유다.** 입구→지점 흙길이
	# `_landmarks`에서 파생한다. 순서가 뒤바뀌면 지점은 서 있는데 **길이 안 깔려** 방 한가운데
	# 아무도 안 가는 물건이 되고, 여기 에러도 0이다(세99 목표가 통째로 무효).
	_spawn_landmarks()
	_fill_tiles()
	# 🔴 **`_fill_tiles` 뒤다** — 프롭이 흙길을 피하려면(ⓓ) 길이 이미 깔려 있어야 한다(`_road`).
	#  순서가 뒤바뀌면 표가 비어서 **회피가 통째로 무효**가 되는데 에러는 0이다(길 위에 나무가 선다).
	# 🔴 그리고 **잡몹·보스보다 앞이다** — `add_child` 순서가 곧 그리는 순서라, 뒤로 밀면 프롭이
	#  적·플레이어 위에 덮인다(둘 다 z 0이다 — `test_charge_telegraph_auto [7]`이 같은 자리를 잰다).
	_spawn_props()
	_clamp_camera_to_room()
	# 🔴 스폰이 실패하면 **여기서 멈춘다** — `_spawn_boss` 안의 `return`은 자기 함수만 벗어나므로,
	# 예전엔 이미 떠나기로 한 방(`_leaving = true`)이 잡몹을 깔고 「…를 쓰러뜨려라」를 한 프레임
	# 띄웠다(세84 감사 #38). 챕터-null 분기(위)는 return이 `_ready` 자신이라 원래부터 제대로 멈춘다.
	if not _spawn_boss():
		return
	_spawn_mobs()
	# 🔴 네임드는 **잡몹 뒤**다 — 보스·잡몹이 다 선 뒤라야 「이 판에 얹힌 것」이라는 순서가 읽히고,
	#  그물도 「보스1 + 잡몹N + 네임드0~M」이라는 같은 순서로 개수를 잰다(test_chapter_auto).
	_spawn_named()
	var boss_def := Db.get_enemy(_chapter.boss_enemy_id)
	var boss_name := boss_def.display_name if boss_def != null else String(_chapter.boss_enemy_id)
	# 🔴 세84 #36: `sticky` — **방의 목표 줄이다**. say()에 수명이 붙었으므로(경고가 목표를 덮고
	# 영구 상주하던 걸 고쳤다) 여기 안 붙이면 목표가 4.5초 뒤 조용히 사라진다.
	# 🔴🔴 세99(D2): 옛 줄은 *"«보스»를 쓰러뜨려라"*였는데 **확정은 「탈출이 목표 · 보스는 선택」**이다
	#   — 방의 **유일한 안내**가 거짓 지시로 남아 있었고 재는 그물이 없었다(설계 §6 S13).
	#   sticky는 **「유효한 지시만」**이 계약이라 이 줄이 곧 계약 위반이었다.
	# ⚠ **두 문장이 같이 읽혀야 한다** — 챕터 잠금은 여전히 `chapter_clear_*`를 요구하므로
	#   「보스는 선택」만 적으면 *"그럼 왜 잡나"*가 되고, 「잡아라」만 적으면 D2가 죽는다.
	_hud.say("%s — 살아서 나가면 이긴다. 출구에서 [E] 꾹. %s는 선택이지만 잡아야 다음 챕터가 열린다"
		% [_chapter.title, boss_name], false, true)


## 🔴🔴 챕터 분위기 = **옅은 틴트** (세99 — 옛 `_apply_floor_daylight`가 있던 자리).
##
## 🔴 **왜 옛 함수를 지웠나**: 그건 `room_ground_color / FLOOR_TILE_BASE`로 **2~3배**를 곱했다 —
##  거의 검은 `tile_boss_floor.png`(바탕 32,46,55)를 낮으로 끌어올리는 **우회로**였다. 새 시트는
##  이미 낮 밝기로 그려져 있어서, 그 곱을 그대로 두면 **곱을 두 번 먹고 탄다**(흙 `#ad7757` →
##  `#ffff6d` 형광 노랑 · 에러는 0이고 화면만 탄다 — `docs/_reports/tile_dirt.md` §0의 표).
##  **소비자가 사라진 손잡이를 남기면 거짓 손잡이가 된다**(감사 T3)라서 함수·상수를 같이 걷었다.
##
## 🔴 대신 무엇을 하나 — `ChapterDef.room_ground_color`의 **뜻은 그대로 「이 챕터의 바닥색」**이고
##  **해석만 바뀌었다**: 「타일이 정확히 이 색이 되게 곱한다」 → 「이 색의 **색조만** 뽑아 1.0 언저리로
##  옅게 덮는다」. 밝기(평균)를 1로 정규화해 **어느 챕터도 화면을 어둡게도 타게도 못 한다.**
##  ⚠ 필드는 core 소유라 이름·타입을 안 건드렸다 — 새 스키마 0.
##
## ⚠ 테두리(`Ground` ColorRect)도 **같은 틴트를 먹은 풀색**으로 맞춘다 — 타일이 못 덮는 가장자리
##  한 칸이 다른 색이면 방에 액자가 둘린다(세98까지가 그 그림이었다).
## ⚠ 이 곱은 `Daylight`(CanvasModulate) **앞**이다 — 화면 실색 = 타일색 × 틴트 × Daylight.
func _apply_chapter_tint() -> void:
	var tint := _chapter_tint()
	_tiles.modulate = tint
	_ground.color = Color(
		GRASS_TILE_BASE.r * tint.r, GRASS_TILE_BASE.g * tint.g, GRASS_TILE_BASE.b * tint.b, 1.0)


## 챕터 색 → 옅은 틴트. **고정 참조 밝기**로 나눠 색조와 명암을 같이 남기고, 흰색에서 그만큼만
## 끌어온다(그래서 세기를 0으로 두면 곱이 통째로 1 = 그림 그대로가 된다).
func _chapter_tint() -> Color:
	var c := _chapter.room_ground_color
	return Color(
		_tint_channel(c.r), _tint_channel(c.g), _tint_channel(c.b), 1.0)


func _tint_channel(v: float) -> float:
	return clampf(lerpf(1.0, v / CHAPTER_TINT_REF_LUM, CHAPTER_TINT_STRENGTH),
		CHAPTER_TINT_MIN, CHAPTER_TINT_MAX)


## 🔴🔴 카메라를 방 안으로 묶는다 (세88 — 리드가 MCP 스샷으로 잡았다).
##
## 방을 2400×2200으로 키우자 **입장 순간 화면 아래 절반이 방 밖(엔진 배경색 회색)으로 비었다**:
## 플레이어 스폰(0, 600)이 남쪽 경계(y 700)에서 100px인데 뷰포트 반높이가 270px이라 y 700~870이
## 그대로 화면에 들어왔다. `player.tscn`의 `Camera2D`엔 `limit_*`이 없다 — 마을(2400×1600)에서는
## 플레이어가 경계까지 잘 안 가서 **드러나지 않았을 뿐이다**(설계 부록도 "클램프가 어긋날 자리가
## 없다"고 적었는데, 어긋날 자리가 없던 게 아니라 **클램프 자체가 없었다**).
##
## ⚠ **Ground rect에서 파생한다** — 방 크기를 또 바꾸면 따라온다(좌표를 베끼면 그 순간 갈라진다).
## ⚠ 마을에는 영향이 없다: `player.tscn`은 씬마다 새 인스턴스라 limit도 이 방에서만 산다.
func _clamp_camera_to_room() -> void:
	var cam := _player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var top_left := _ground.global_position
	cam.limit_left = int(top_left.x)
	cam.limit_top = int(top_left.y)
	cam.limit_right = int(top_left.x + _ground.size.x)
	cam.limit_bottom = int(top_left.y + _ground.size.y)


## 🔴 탈출구를 전부 세우고 **한 자리에서** 배선한다 (세99 D1).
##  ⓐ 씬의 남쪽 `$Exit`(세88부터 늘 있던 것) ⓑ `ChapterDef.extract_points`가 적은 자리들.
## 🔴 `extract_points`가 **비면 ⓐ 하나뿐** = 세98까지와 한 톨도 안 다르다(회귀 0).
## ⚠ 출구는 전부 `zone_id = &"exit"`이다 — 씬 파일이 그 값을 쥔다(`exit_zone.tscn`).
##  세99에 포탈이 은퇴하며 **zone_id가 갈릴 이유 자체가 없어졌다** — 다른 값을 새로 만들지 마라.
func _build_exits() -> void:
	_exits.clear()
	var south := get_node_or_null(^"Exit") as InteractZone
	if south != null:
		_exits.append(south)
	else:
		# 침묵 금지 — 출구가 하나도 없으면 상시 귀환이 통째로 사라지는데 화면은 멀쩡하다.
		push_error("boss_room: 씬에 남쪽 출구($Exit)가 없다 — 상시 귀환이 사라진다")
	for point: Vector2 in _chapter.extract_points:
		var zone := ExitZoneScene.instantiate() as InteractZone
		zone.position = point
		add_child(zone)
		_exits.append(zone)
	for zone: InteractZone in _exits:
		_wire_extract_zone(zone)


## 🔴🔴 나가는 길 하나를 **살린다** — 연결과 홀드 스위치가 **같은 함수 안**이어야 한다.
##  • 연결을 빠뜨리면: E가 먹히고 안내도 뜨는데 **아무 일도 안 일어나고 가방이 조용히 증발한다**
##    (창고로 안 가고 자동 저장도 안 돈다 — 에러 0. `_extract` 머리말이 경고한 그 자리다).
##  • 홀드를 빠뜨리면: 그 출구만 즉시 탈출이 돼 **D7의 긴장이 출구 하나로 새 나간다**(역시 에러 0).
## 🔴 부르는 곳은 `_build_exits` **하나뿐**이다 — 세99에 포탈이 은퇴하며 둘째 호출부가 사라졌다.
##  방 안에 나가는 길을 새로 세우는 코드를 또 쓰게 되거든 **여기를 지나게** 해라.
func _wire_extract_zone(zone: InteractZone) -> void:
	zone.hold_sec = HOLD_ON
	if not zone.interacted.is_connected(_extract):
		zone.interacted.connect(_extract)


## 🔴🔴 지점(랜드마크)을 세운다 (세99 D3·D4 단계 3) — **`ChapterDef.landmarks` → `Db.landmarks` →
## `LandmarkDef.scene_path`** 세 걸음이고, **어느 걸음이 끊겨도 화면엔 아무 일도 안 난다.** 그래서
## 걸음마다 짖는다(설계 §7 F1이 지목한 침묵 자리 — 폴더가 없으면 `Db._load_dir`이 경고만 하고
## 빈 배열을 돌려줘 「지점 0개인데 에러 0」이 된다).
##
## 🔴 **「새 지점 = `.tres` 한 장 + 프롭 씬 한 장」이 여기서 성립한다** — 이 함수엔 지점 종류가
##  한 글자도 안 적혀 있다(둥지·폐허·제단을 분기하지 않는다). **세101에 열기가 붙어도 그대로다**:
##  「열렸다」는 `opened` 시그널 하나로 오고, 무엇이 나오는지는 그 지점의 `.tres`가 정한다.
##
## 🔴🔴 **세101 N26 — 여기서 두 가지를 더 한다**(설계 §3 소유권 ⓐⓑ · §10-4 S27):
##  ⓐ **노드에 `landmark_id`를 새긴다**(meta) — 열림·우두머리 해석이 그걸 묻는다.
##  ⓑ **`opened`를 잇는다** — 산출을 굴려 뿌리는 건 **방**이다. 지점이 `src/field/`를 물면
##     preload 방향(field → props 단방향)이 처음으로 뒤집힌다(`LandmarkDef` 머리말).
##
## 🔴 `preload`가 아니라 `load`인 이유 = `boss_scene_path`와 같다(씬끼리 PackedScene을 물면 순환).
## 🔴 그룹 `"landmarks"`는 **방이 붙인다** — 지점 씬마다 붙이면 새 지점 하나가 빠뜨리는 순간
##  「서 있는데 아무도 못 찾는」 물건이 된다(단일 소유자). 그물도 이 그룹으로 센다.
func _spawn_landmarks() -> void:
	_landmarks.clear()
	for slot: LandmarkSlot in _chapter.landmarks:
		if slot == null:
			continue
		var def := Db.get_landmark(slot.landmark_id)
		if def == null:
			push_error("boss_room: landmark_id '%s'가 Db.landmarks에 없다 — 그 자리가 빈 채로 선다"
				% String(slot.landmark_id))
			continue
		if def.scene_path == "":
			push_error("boss_room: 지점 '%s'의 scene_path가 비었다 — 겉모습 없이 자리만 잡는다"
				% String(def.id))
			continue
		var packed := load(def.scene_path) as PackedScene
		if packed == null:
			push_error("boss_room: 지점 '%s'의 scene_path '%s'를 못 읽었다"
				% [String(def.id), def.scene_path])
			continue
		# 🔴 **가드 넷 뒤에 무방비 한 줄이 있었다**(세100 N25 잔가지): 루트가 Node2D가 아니면
		#  `as Node2D`가 null을 내는데 바로 아래에서 `.position`을 만져 **SCRIPT ERROR로 방이 죽는다.**
		#  「새 지점 = 프롭 씬 한 장」이 이 함수의 **선언된 계약**이라 남이 반드시 밟는다 —
		#  Control이나 Node를 루트로 만든 씬 하나면 그 판이 통째로 안 선다.
		var inst := packed.instantiate()
		var node := inst as Node2D
		if node == null:
			push_error("boss_room: 지점 '%s'의 씬 루트가 Node2D가 아니다(%s) — 자리를 못 잡아 안 세운다"
				% [String(def.id), inst.get_class()])
			inst.free()
			continue
		# 🔴 위치는 `add_child` **앞**이다(보스·잡몹과 같은 계약) — 지점 씬이 `_ready`에서 자기
		#  자리로 무언가를 파생시키면 뒤에 옮길 때 한 프레임 어긋난다.
		node.position = slot.position
		node.add_to_group(&"landmarks")
		# 🔴 **노드를 만든 그 줄에서** 새긴다 — 뒤에서 배열 순서로 맞추면 실패한 슬롯 하나에
		#  전부 밀린다(`LANDMARK_ID_META` 머리말).
		node.set_meta(LANDMARK_ID_META, def.id)
		add_child(node)
		_landmarks.append(node)
		# 🔴🔴 열림 배선 — **자식 시그널을 부모가 잇는 조합 루트**라 EventBus 신설이 0이다(설계 §10-7).
		#  ⚠ `has_signal` 가드: 「새 지점 = 프롭 씬 한 장」이라 남이 시그널 없는 씬을 꽂는다.
		#   가드가 없으면 그 한 장이 **판을 통째로 못 세운다**(위 Node2D 가드와 같은 결).
		if node.has_signal(&"opened"):
			node.connect(&"opened", _on_landmark_opened.bind(node))
		elif not def.drops.is_empty():
			# 🔴 침묵 금지 — 산출을 실어 놓고 **밟을 방법이 없는** 지점이다. 화면에선 그냥
			#  「예쁜 이정표」로 보이고 에러가 0이다(설계 §7 진행표가 세99에 실제로 밟은 상태).
			push_warning("boss_room: 지점 '%s'가 산출(drops %d줄)을 들었는데 씬에 `opened` 시그널이 없다 — 밟을 방법이 없다"
				% [String(def.id), def.drops.size()])


## 🔴🔴 **지점을 열었다 — 산출을 굴려 낱개로 뿌린다** (세101 N26 · 설계 §10-2 · D10·D12).
##
## 🔴 **여기가 「무엇이 나오나」의 유일한 소유자다** — 지점 씬은 자기가 무엇을 주는지 **모른다**
##  (`nest.gd`에 `DropEntry`가 한 글자도 없다). 그래야 「새 지점 = `.tres` 한 장」이 성립한다.
## 🔴 **굴림·스폰은 `DropRoll`을 그대로 부른다**(S17) — 적의 `_die`가 부르는 **그 함수**다.
##  자기 굴림을 새로 쓰면 `DropEntry`의 배타 짝 규칙이 두 벌이 되고 **에러가 0이다.**
## 🔴 자리는 **지점의 global_position**(= 접지선) — 낱개가 둥지 발밑에 쏟아지고 걸어가 줍는다.
##  「즉시 열기(D10)로 사라진 무방비는 **낱개를 줍는 동안**으로 옮겨간다」가 그 자리다(D10 ⓒ).
##
## ⚠ **재열기 가드는 여기 없다 — 지점이 진다**(S25 · `nest.gd._on_open_interacted`). 여기에도 두면
##  가드가 두 벌이 되어 한쪽을 지워도 뮤테이션이 안 걸린다(`_spawn_enemy_at`의 보스 가드와 같은 판단).
## ⚠ **연 상태를 `GameState`에 넣지 마라**(S19) — 방은 매 판 새로 서므로 노드가 들면 저절로 다시 찬다.
func _on_landmark_opened(node: Node2D) -> void:
	var id: StringName = node.get_meta(LANDMARK_ID_META, &"")
	var def := Db.get_landmark(id)
	if def == null:
		# 🔴 침묵 금지 — meta가 비었거나 Db에서 사라지면 **열었는데 아무것도 안 나오고 에러가 0**이다.
		push_error("boss_room: 열린 지점의 landmark_id('%s')를 Db에서 못 찾았다 — 산출이 통째로 사라진다"
			% String(id))
		return
	if def.drops.is_empty():
		# 🔴 설계 §10 D12가 「허탕 없음」을 확정했는데 데이터가 비면 **열어도 아무 일이 안 난다.**
		#  데이터는 5단계(사용자 몫)라 여기서 못 채운다 — 대신 **짖는다**(그물 = `test_chapter_auto [1d]`).
		push_warning("boss_room: 지점 '%s'의 drops가 비었다 — 열어도 아무것도 안 나온다 (설계 §10-2 세 층 미기입)"
			% String(def.id))
		return
	var rolled := DropRoll.roll(def.drops, GameState)
	if rolled.is_empty():
		return
	DropRoll.spawn_loose(self, node.global_position, rolled)


## 🔴 이 판에 실제로 **선** 지점 중 이 id인 것들의 자리 — `NamedSpawn.at_landmark`가 쓴다.
##
## 🔴🔴 **「첫 번째」가 아니라 전부를 돌려주는 게 계약이다**(설계 §10-4 **S27**). `LandmarkSlot`이
##  id + 좌표라 **같은 지점 2채가 문법상 가능**한데, 첫 번째만 고르면 **둘째 둥지엔 영영 우두머리가
##  안 뜨고 에러가 0이다.**
## ⚠ `_landmarks`는 **실제로 선 것만** 든다 — 씬 로드가 실패한 슬롯은 여기 없다. 그래서 「자리를
##  못 찾았다」가 곧 「그 지점이 이 판에 안 섰다」이고, 호출부가 그걸 **에러로 승격**한다(S22).
func _landmark_sites(id: StringName) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if id == &"":
		return out
	for node: Node2D in _landmarks:
		if node == null or not is_instance_valid(node):
			continue
		if node.get_meta(LANDMARK_ID_META, &"") == id:
			out.append(node.position)
	return out


## 바닥 타일을 Ground rect에 맞춰 깐다 — 🔴 **세99: 벌판은 풀, 나가는 길은 흙길**이다
## (그전엔 벌판이 거의 검은 슬레이트고 길이 밝은 풀이었는데, 방이 낮이 되며 바탕도 초록이 되자
## 풀길이 **「밝은 초록 네모」로만 읽히고 길로 안 읽혔다** — 리드 스샷 확인).
## 🔴 세99: 출구가 여럿이라 **길도 여럿**이다. 안 깔면 2번째 출구부터 플레이어가 거기 나갈 데가
##  있는 줄 모르고 D1이 통째로 무효가 된다(설계 §6 S12).
## ⚠ 벌판은 **변형 셋을 섞는다** — 한 칸만 반복해 깔면 넓은 바닥이 단조롭다(리드 스샷 확인).
func _fill_tiles() -> void:
	var ts: Vector2i = _tiles.tile_set.tile_size
	var rect := Rect2(_ground.position, _ground.size).grow(-float(ts.x))   # 가장자리 한 칸은 틴트가 보이게
	var from := Vector2i(floori(rect.position.x / ts.x), floori(rect.position.y / ts.y))
	var to := Vector2i(ceili(rect.end.x / ts.x), ceili(rect.end.y / ts.y))
	# 🔴 **필드에 남긴다** — 프롭 회피(ⓓ)가 이 표를 그대로 읽는다(`_spawn_props`). 지역 변수로 두면
	#  「길이 어디 있나」를 두 번 계산하게 되고, 길 규칙을 고치는 날 타일과 프롭이 조용히 갈라진다.
	_road = _road_cells(from, to, ts)
	var road := _road
	for y in range(from.y, to.y):
		for x in range(from.x, to.x):
			var cell := Vector2i(x, y)
			_tiles.set_cell(cell, TILE_SRC_GROUND,
				_road_atlas(cell, road) if road.has(cell) else _grass_atlas(cell))
	# 🔴 **길만 테두리 한 칸 위에도 그린다** — 칠하는 마지막 칸에서 끊으면 그 칸이 「풀로 막힌 끝」
	#  타일이 돼 길이 방 안에서 **막다른 골목**으로 보인다. 「밖으로 이어진다」가 안 읽히면 출구가
	#  겉모습이 없다는 사실과 겹쳐 **나갈 데를 못 찾는다**(설계 §6 S12).
	var outer_from := Vector2i(floori(_ground.position.x / ts.x), floori(_ground.position.y / ts.y))
	var outer_to := Vector2i(ceili((_ground.position.x + _ground.size.x) / ts.x),
		ceili((_ground.position.y + _ground.size.y) / ts.y))
	for cell: Vector2i in road:
		if cell.x >= from.x and cell.x < to.x and cell.y >= from.y and cell.y < to.y:
			continue   # 위 루프가 이미 그렸다
		if cell.x < outer_from.x or cell.x >= outer_to.x or cell.y < outer_from.y or cell.y >= outer_to.y:
			continue   # 방 밖 — 길 계산에만 쓰이고 그려지진 않는다
		_tiles.set_cell(cell, TILE_SRC_GROUND, _road_atlas(cell, road))


## 🔴🔴 **프롭(나무·바위·덤불)을 규칙으로 놓는다** (세101 — 「기둥 밭」을 「숲」으로).
##
## 🔴 **왜 손으로 안 찍나**: 좌표 100개를 씬에 박으면 ⓐ~ⓔ를 사람이 매번 지켜야 하고 **어겨도
##  아무도 모른다**(세100까지가 그 상태였다 — 규칙은 주석으로만 있었고 재는 그물이 0개였다).
##  규칙이 코드에 있으면 **그물이 잴 수 있고**, 방 크기·출구·지점을 옮겨도 배치가 따라온다.
##
## 🔴🔴 **결정적이다 — 판마다 안 바뀐다**(`randf` 대신 `_cell_hash`). 세99 D5가 사용자 확정으로
##  *"지형은 동일하고 나오는 몬스터들이 랜덤"*이라고 못 박았고 **프롭은 지형이다.** 같은 챕터를 다시
##  들어가면 같은 숲이라야 「저 바위 뒤」가 기억이 된다. 챕터마다 다른 건 굴림이 아니라 **회피 조건**이
##  다르기 때문이다(몹 자리·지점·길이 챕터마다 달라 통과하는 칸이 갈린다).
##  ⚠ 그물 = `test_prop_layout_auto [8]`(같은 챕터를 두 번 띄워 좌표 집합을 대조한다).
##
## 🔴 **손으로 놓은 나무 20그루도 같은 목록(`props` 그룹)에 넣는다** — 규칙은 「누가 놓았나」를 안 본다.
##  손으로 놓은 것만 규칙 밖이면 그게 곧 구멍이고, 겹침 검사도 그것들을 봐야 나무가 나무에 겹친다.
##  🔴 그룹은 **방이 붙인다**(지점의 `landmarks`와 같은 결) — 프롭 씬마다 붙이면 새 프롭 한 장이
##   빠뜨리는 순간 「서 있는데 아무도 못 세는」 물건이 된다.
##
## ⚠ **좌우 반전(`flip_h`)으로 변화를 주지 않는다** — ART_SPEC의 광원이 **왼쪽 위 고정**이라
##  뒤집으면 하이라이트가 오른쪽 위로 가서 그 프롭만 다른 해를 받는다(공짜로 보이지만 아트를 깬다).
##  변화는 나무처럼 **컷을 여러 장 두는 것**으로 준다(`tree.gd`가 이미 그렇게 한다).
func _spawn_props() -> void:
	var holder := Node2D.new()
	holder.name = PROP_HOLDER
	add_child(holder)
	# 🔴 **타일 바로 뒤**로 옮긴다 — `add_child`는 맨 뒤에 붙는데, 그러면 잔돌·덤불이 적·플레이어
	#  **위에** 그려진다(둘 다 z 0이라 순서가 곧 앞뒤다). 나무가 씬에서 Player보다 앞에 있는 것과 같은 이유.
	move_child(holder, _tiles.get_index() + 1)

	var placed: Array[Vector2] = []
	var radii: Array[float] = []
	for child: Node in _tree_holder.get_children():
		var tree := child as Node2D
		if tree == null:
			continue
		tree.add_to_group(&"props")
		placed.append(tree.position)
		radii.append(float(PROP_TABLE[PROP_TREE_KIND]["sep"]))

	var area := Rect2(_ground.position, _ground.size).grow(-PROP_EDGE_MARGIN)
	for kind in PROP_TABLE.size():
		var packed := load(String(PROP_TABLE[kind]["scene"])) as PackedScene
		if packed == null:
			# 침묵 금지 — 씬 하나를 못 읽으면 그 층이 통째로 사라지는데 화면은 「그냥 휑한 숲」이다.
			push_error("boss_room: 프롭 씬 '%s'를 못 읽었다 — 그 층이 통째로 안 선다"
				% String(PROP_TABLE[kind]["scene"]))
			continue
		for at: Vector2 in _prop_spots(area, kind):
			if not _prop_spot_ok(at, kind, placed, radii):
				continue
			var node := packed.instantiate() as Node2D
			if node == null:
				continue
			node.position = at
			node.add_to_group(&"props")
			# 🔴 나무는 씬의 `Trees`로 — 손으로 놓은 20그루와 같은 물건이라 홀더를 안 가른다.
			(_tree_holder if kind == PROP_TREE_KIND else holder).add_child(node)
			placed.append(at)
			radii.append(float(PROP_TABLE[kind]["sep"]))


## ⚠ **세107: 여기 있던 `_mark_occluder()`가 은퇴했다** — 프롭에 `occluders` 그룹과 `occlude_r` meta를
##  새겨 시선을 끊던 물건이다(세105). 판정·화면(셰이더 그늘)·그물을 **셋 같이** 걷었으니
##  🔴 되살릴 땐 셋을 같이 열어라. 경위 = `src/core/vision.gd` 머리말 · `git show`(세105~107).


## 이 종류가 노려 볼 **자리 후보**들 — 지터를 준 격자에서 뽑는다.
## 🔴 격자 칸마다 종류가 **하나로 정해진다**(`_prop_kind_at`) — 그래서 종류를 바꿔 가며 네 번 훑어도
##  같은 칸이 두 번 쓰이지 않는다. 순서(큰 것 → 작은 것)만으로 「작은 것이 사이를 채운다」가 나온다.
func _prop_spots(area: Rect2, kind: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var cols := int(area.size.x / PROP_GRID)
	var rows := int(area.size.y / PROP_GRID)
	for j in rows + 1:
		for i in cols + 1:
			var cell := Vector2i(i, j)
			if _prop_kind_at(cell) != kind:
				continue
			var jx := (float(_cell_hash(cell, 41)) / 50.0 - 1.0) * PROP_JITTER
			var jy := (float(_cell_hash(cell, 47)) / 50.0 - 1.0) * PROP_JITTER
			var at := area.position + Vector2(float(i), float(j)) * PROP_GRID + Vector2(jx, jy)
			if not area.has_point(at):
				continue
			out.append(at)
	return out


## 격자 칸 하나가 무슨 종류인가 — `share`를 누적해 자른다. 합이 100에 못 미치면 나머지는 **빈칸**이다
## (그게 「듬성듬성」을 만든다 — 전부 채우면 벽지가 된다).
func _prop_kind_at(cell: Vector2i) -> int:
	var h := _cell_hash(cell, 53)
	var acc := 0
	for kind in PROP_TABLE.size():
		acc += int(PROP_TABLE[kind]["share"])
		if h < acc:
			return kind
	return -1


## 🔴🔴 **규칙 ⓐ~ⓔ가 전부 여기 있다** — 한 자리에 모아 둬야 새 규칙을 더할 때 빠뜨릴 문이 없다.
## 🔴 좌표를 하나도 안 박는다: 스폰은 `ChapterDef`에서 · 입구는 `Player` 노드에서 · 출구는 `_exits`에서 ·
##  지점은 `_landmarks`에서 · 길은 `_road`에서 파생한다. **방을 바꾸면 배치가 따라온다.**
func _prop_spot_ok(at: Vector2, kind: int, placed: Array[Vector2], radii: Array[float]) -> bool:
	# ⓓ 흙길 위 금지 — 출구는 겉모습이 없어서 **보이는 안내가 그 길뿐**이다(설계 §6 S12).
	if _prop_touches_road(at, float(PROP_TABLE[kind]["road"])):
		return false
	# ⓐ 잡몹·네임드·보스 자리 — 적이 프롭에 파묻히면 「보이는 몸에 쏜다」가 깨진다.
	if at.distance_to(_chapter.boss_spawn) < PROP_CLEAR_BOSS:
		return false
	for spawn: MobSpawn in _chapter.mob_spawns:
		if spawn != null and at.distance_to(spawn.position) < PROP_CLEAR_SPAWN:
			return false
	# ⚠ 네임드는 **뜰 수도 안 뜰 수도** 있지만 자리는 데이터에 있다 — 뜬 판에서만 파묻히면
	#  「어떤 판은 네임드가 안 보인다」가 돼서 오히려 더 나쁘다. 그래서 굴림과 무관하게 비운다.
	for named: NamedSpawn in _chapter.named_pool:
		if named != null and at.distance_to(named.position) < PROP_CLEAR_SPAWN:
			return false
	# ⓑ 입구(플레이어 스폰)·**모든 탈출구**
	if at.distance_to(_player.position) < PROP_CLEAR_GATE:
		return false
	for zone: InteractZone in _exits:
		if zone != null and is_instance_valid(zone) and at.distance_to(zone.position) < PROP_CLEAR_GATE:
			return false
	# ⓔ 지점(둥지) 둘레
	for landmark: Node2D in _landmarks:
		if landmark != null and is_instance_valid(landmark) \
			and at.distance_to(landmark.position) < PROP_CLEAR_LANDMARK:
			return false
	# 이웃과 겹치지 않는다 — 문턱은 **두 반지름의 합**이라 나무끼리는 멀고 잔돌끼리는 붙어도 된다.
	var sep := float(PROP_TABLE[kind]["sep"])
	for i in placed.size():
		if at.distance_to(placed[i]) < sep + radii[i]:
			return false
	return true


## ⓓ 이 자리의 **밑동이 흙길 칸을 밟는가** — 가로는 밑동 반폭(`road`), 세로는 얇은 띠다.
## 🔴 원점이 접지선이라(프롭 씬 계약) 이 검사가 곧 「길 위에 서 있나」다. 그림 전체가 아니라 밑동을
##  보는 이유는 `PROP_TABLE` 머리말에 있다(가지가 길가에 걸치는 건 숲답다).
func _prop_touches_road(at: Vector2, pad: float) -> bool:
	var ts: Vector2i = _tiles.tile_set.tile_size
	var x0 := floori((at.x - pad) / float(ts.x))
	var x1 := floori((at.x + pad) / float(ts.x))
	var y0 := floori((at.y - PROP_ROAD_BAND) / float(ts.y))
	var y1 := floori((at.y + PROP_ROAD_BAND) / float(ts.y))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if _road.has(Vector2i(x, y)):
				return true
	return false


## 흙길 칸 전부 — **줄기가 두 종류다**:
##  ⓐ **나가는 길** — 출구마다 「자기 자리 → 가장 가까운 방 가장자리」(세99 D1).
##  ⓑ **들어가는 길** — 입구에서 지점까지(세99 D3·D4 단계 3).
## 🔴 **좌표는 노드에서 파생한다**(여기 베끼면 출구·지점을 옮길 때 길만 제자리에 남는다).
## ⚠ 둘이 만나도 손댈 게 없다 — 9분할 오토타일이 이웃을 보고 이음매를 고른다(폭이 같아야 한다는
##  전제만 지키면 된다. 그래서 ⓑ도 `EXIT_PATH_WIDTH_CELLS`를 그대로 쓴다 — §`_road_between` 참조).
## `from`은 포함·`to`는 배타 = `_fill_tiles`의 루프 범위 그대로.
func _road_cells(from: Vector2i, to: Vector2i, ts: Vector2i) -> Dictionary:
	var out: Dictionary = {}
	var half: int = (EXIT_PATH_WIDTH_CELLS - 1) / 2
	if EXIT_PATH_ROWS > 0:   # 끄는 손잡이 (연출값) — ⓐ만 끈다
		for zone: InteractZone in _exits:
			if zone == null or not is_instance_valid(zone):
				continue
			var cell := Vector2i(floori(zone.position.x / float(ts.x)), floori(zone.position.y / float(ts.y)))
			var ends := _exit_road_ends(cell, from, to)
			_road_between(ends[0], ends[1], half, out)
	_landmark_road_cells(half, ts, out)
	return out


## 🔴🔴 **들어가는 길 — 입구에서 지점까지** (세99 목표: *"랜드마크 1개에 입구부터 거기로 이어져있는거임"*).
##
## 🔴 **길이 없으면 지점은 없는 것과 같다.** 방이 2400×2200 열린 숲이라 「저쪽에 뭔가 있다」를
##  알려 주는 건 **바닥 그림뿐**이다(출구가 흙길로만 읽히는 것과 정확히 같은 문제 — 설계 §6 S12).
##  세99 전반의 길은 가장자리에서 안쪽으로 튀어나온 **토막**이었다 — **목적지가 생겨야 동선이 된다.**
##
## 🔴🔴 **인자 순서가 길의 모양을 정한다 — `(지점, 입구)`다.** `_road_between`이 `(b.x, a.y)`에서
##  꺾으므로 이 순서라야 「입구에서 **북쪽으로 곧게 들어가다가** 지점 쪽으로 꺾인다」가 된다.
##  뒤집으면(`(입구, 지점)`) 먼저 **남쪽 가장자리를 따라 가로로** 달리다 꺾여서, 나가는 길과 겹쳐
##  방 아래쪽이 통째로 흙 밭이 된다(에러 0 · 화면만 망가진다).
##
## 🔴 시작점은 **플레이어 스폰 노드**다 — 「입구」의 정의가 거기고, 좌표를 여기 적으면 스폰을 옮길 때
##  길만 제자리에 남는다. ✅ 남쪽 출구의 길과 자연히 한 줄기로 이어진다(스폰이 그 길 위에 서 있다).
## ⚠ 경로탐색이 아니다 — 나무·몹을 안 피한다(방이 열린 숲이라 필요가 없다. 자리를 겹치지 않게 놓는
##  건 데이터의 몫이고 `data/chapters/*.tres`에 그 판단이 적혀 있다).
func _landmark_road_cells(half: int, ts: Vector2i, out: Dictionary) -> void:
	if _landmarks.is_empty():
		return
	var entrance := Vector2i(floori(_player.position.x / float(ts.x)),
		floori(_player.position.y / float(ts.y)))
	for node: Node2D in _landmarks:
		if node == null or not is_instance_valid(node):
			continue
		var cell := Vector2i(floori(node.position.x / float(ts.x)), floori(node.position.y / float(ts.y)))
		_road_between(cell, entrance, half, out)


## 🔴🔴 **임의의 두 칸을 흙길로 잇는다** — 가로 다리 → 세로 다리(ㄱ자), 폭 `half * 2 + 1`.
##
## 🔴 부르는 곳이 **둘**이다(세99): 출구 길(`_road_cells`)과 **입구→지점 길**(`_landmark_road_cells`).
##  출구 길은 두 끝이 한 축에 있어 직선이 되고, 지점 길은 실제로 **ㄱ자로 꺾인다**(꺾인 자리의
##  안쪽 모서리 nub·바깥 모서리는 오토타일이 알아서 고른다 — 세99 단계 1b에 표만 세워 뒀던 칸들이
##  여기서 처음 화면에 나온다). 출구 전용으로 짰다면 지금 같은 기계를 두 벌 갖게 됐다(감사 T5).
## ⚠ 경로탐색은 아니다 — 장애물을 안 본다(방이 열린 숲이라 필요가 없다). 필요해지면 그때 얹어라.
## ⚠ 폭은 **한 줄기 안에서 일정해야 한다** — 시트의 9분할 칸과 오솔길 칸은 변의 풀 두께가 달라
##  (실측 12px ↔ 24px) 한 줄기에 섞으면 이음매가 어긋난다.
func _road_between(a: Vector2i, b: Vector2i, half: int, out: Dictionary) -> void:
	var corner := Vector2i(b.x, a.y)
	var drew := false
	if corner != a:
		_road_segment(a, corner, half, out)
		drew = true
	if corner != b:
		_road_segment(corner, b, half, out)
		drew = true
	if not drew:
		# 두 끝이 같은 칸 — 다리가 없으니 폭만 한 덩어리로 남긴다.
		for y in range(b.y - half, b.y + half + 1):
			for x in range(b.x - half, b.x + half + 1):
				out[Vector2i(x, y)] = true


## 다리 한 토막 — 🔴 **진행 방향과 직각으로만** `half`만큼 넓힌다. 양쪽으로 넓히면 꺾이지 않는
## 길에도 시작·끝에 혹이 붙어 세88 남쪽 길과 칸 수가 어긋난다(회귀).
func _road_segment(a: Vector2i, b: Vector2i, half: int, out: Dictionary) -> void:
	var x0 := mini(a.x, b.x)
	var x1 := maxi(a.x, b.x)
	var y0 := mini(a.y, b.y)
	var y1 := maxi(a.y, b.y)
	if a.y == b.y:
		y0 -= half
		y1 += half
	else:
		x0 -= half
		x1 += half
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			out[Vector2i(x, y)] = true


## 출구 한 칸 → 「가장 가까운 방 가장자리로 나가는 한 줄기」의 **두 끝**.
##
## 🔴 **세88의 남쪽 출구에 대해 그려지는 칸이 하나까지 같다**(회귀 0): 출구 셀 y=10 · 채우는 마지막
## 줄 y=9 · `EXIT_PATH_ROWS=3` → 두 끝이 y 7과 y 10인데 루프가 10을 안 도니 실제로 깔리는 건
## {7,8,9}, 즉 옛 `y >= to.y - EXIT_PATH_ROWS`와 **같은 세 줄**이다. x도 `cell.x ± half`로 동일하다.
## 🔴 일반화가 필요한 이유: 늘린 출구는 남쪽이 아닐 수 있다. 「마지막 세 줄」로 두면 **동·서·북
## 출구엔 길이 자기 자리가 아닌 남쪽 끝에 깔린다**(에러 0 · 화면만 거짓말).
## 🔴 바깥 끝은 **가장자리에서 한 칸 더 나간다** — 마지막 칸에서 멈추면 그 칸이 「풀로 막힌 끝」이 돼
##  길이 방 안에서 끊겨 보인다. 그 한 칸은 테두리 위에 그려진다(`_fill_tiles` 둘째 루프).
## ⚠ 방 한복판에 출구를 두면 통로가 **출구에서 가장자리까지 통째로** 깔린다 — 의도한 동작이다
##  (짧은 표시보다 「걸어 나가는 길」이 D1의 판단을 만든다).
func _exit_road_ends(cell: Vector2i, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var last := Vector2i(to.x - 1, to.y - 1)   # 실제로 칠하는 마지막 칸(포함)
	var d_left := cell.x - from.x
	var d_right := last.x - cell.x
	var d_top := cell.y - from.y
	var d_bottom := last.y - cell.y
	var best := mini(mini(d_left, d_right), mini(d_top, d_bottom))
	if best == d_bottom or best == d_top:
		var out_y := to.y if best == d_bottom else from.y - 1
		var in_y := last.y - (EXIT_PATH_ROWS - 1) if best == d_bottom else from.y + (EXIT_PATH_ROWS - 1)
		return [Vector2i(cell.x, mini(cell.y, mini(out_y, in_y))),
			Vector2i(cell.x, maxi(cell.y, maxi(out_y, in_y)))]
	var out_x := to.x if best == d_right else from.x - 1
	var in_x := last.x - (EXIT_PATH_ROWS - 1) if best == d_right else from.x + (EXIT_PATH_ROWS - 1)
	return [Vector2i(mini(cell.x, mini(out_x, in_x)), cell.y),
		Vector2i(maxi(cell.x, maxi(out_x, in_x)), cell.y)]


## 🔴🔴 흙길 한 칸의 아틀라스 좌표 — **이웃이 고른다**(9분할 오토타일).
## `cons` = 흙이 **아닌** 변 · `nub` = 두 변은 흙인데 그 사이 대각이 풀인 모서리(= 길이 ㄱ자로 꺾일 때 안쪽).
## ⚠ cons와 nub가 같이 있으면 **cons가 이긴다** — 시트가 그 조합을 안 들어서(40칸 중 29종) 안쪽
##  모서리가 살짝 각져 보일 뿐 **깨지지 않는다**(`docs/_reports/tile_dirt.md` §3 마지막 문단).
func _road_atlas(cell: Vector2i, road: Dictionary) -> Vector2i:
	var cons := 0
	if not road.has(cell + Vector2i(0, -1)):
		cons |= DIR_T
	if not road.has(cell + Vector2i(0, 1)):
		cons |= DIR_B
	if not road.has(cell + Vector2i(-1, 0)):
		cons |= DIR_L
	if not road.has(cell + Vector2i(1, 0)):
		cons |= DIR_R
	if not _road_is_thick(cell, road):
		# 폭 1칸 오솔길 — 「어느 쪽으로 이어지나」로 고른다(9분할과 키의 뜻이 반대다).
		return _road_narrow_atlas((~cons) & 15, cell)
	if cons != 0:
		return _road_edge_atlas(cons, cell)
	var nub := _road_nub(cell, road)
	if nub != 0:
		return ROAD_NUB[nub]
	return _road_center_atlas(cell)


## 이 칸이 **폭 2칸 이상**인가 — 자기를 품는 2×2 흙 덩어리가 하나라도 있으면 그렇다.
## 🔴 넓은 길(9분할)과 오솔길은 변의 풀 두께가 달라 **한 칸이라도 잘못 고르면 이음매가 튄다.**
func _road_is_thick(cell: Vector2i, road: Dictionary) -> bool:
	for oy in [-1, 0]:
		for ox in [-1, 0]:
			if road.has(cell + Vector2i(ox, oy)) and road.has(cell + Vector2i(ox + 1, oy)) \
				and road.has(cell + Vector2i(ox, oy + 1)) and road.has(cell + Vector2i(ox + 1, oy + 1)):
				return true
	return false


## 안쪽 모서리 비트 — 없으면 0. 🔴 **`cons == 0`일 때만 불러라** — 「두 변이 다 흙」이 nub의 전제인데
## 그 검사를 여기서 다시 안 한다(호출부가 이미 네 변이 다 흙임을 확인한 뒤다).
## ⚠ 둘 이상이면 **먼저 찾은 것**을 쓴다(3칸 폭 길에선 한 번에 하나만 생긴다).
func _road_nub(cell: Vector2i, road: Dictionary) -> int:
	for pair: Array in [[DIR_T | DIR_L, Vector2i(-1, -1)], [DIR_T | DIR_R, Vector2i(1, -1)],
		[DIR_B | DIR_L, Vector2i(-1, 1)], [DIR_B | DIR_R, Vector2i(1, 1)]]:
		if not road.has(cell + (pair[1] as Vector2i)):
			return pair[0]
	return 0


## 변 칸 — 상·하변만 A/B를 번갈아 깐다(좌·우변은 시트에 한 판뿐이다).
func _road_edge_atlas(cons: int, cell: Vector2i) -> Vector2i:
	if cons == DIR_T and _cell_hash(cell, 11) < 50:
		return ROAD_TOP_B
	if cons == DIR_B and _cell_hash(cell, 11) < 50:
		return ROAD_BOTTOM_B
	return ROAD_EDGE.get(cons, ROAD_EDGE[0])


## 길 한복판 — 🔴 **잔풀 난 흙을 섞는 게 이 칸의 핵심**이다(가장 많이 반복되는 면이라 여기가
## 단조로우면 길 전체가 벽지가 된다 — art 손질 6회차의 결론).
func _road_center_atlas(cell: Vector2i) -> Vector2i:
	var h := _cell_hash(cell, 3)
	if h < 8:
		return ROAD_GRAVEL
	if h < 38:
		return ROAD_WEEDY
	if h < 65:
		return ROAD_CENTER_B
	return ROAD_EDGE[0]


func _road_narrow_atlas(conn: int, cell: Vector2i) -> Vector2i:
	if conn == (DIR_T | DIR_B) and _cell_hash(cell, 11) < 50:
		return ROAD_NARROW_VERT_B
	if conn == (DIR_L | DIR_R) and _cell_hash(cell, 11) < 50:
		return ROAD_NARROW_HORZ_B
	return ROAD_NARROW.get(conn, ROAD_NARROW[0])


## 벌판 한 칸 — 풀 변형 셋(비율은 `docs/_reports/tile_dirt.md` §3 행4: 볕에 마른 ~25% · 새순 ~8%).
func _grass_atlas(cell: Vector2i) -> Vector2i:
	var h := _cell_hash(cell, 0)
	if h < 8:
		return GRASS_SPROUT
	if h < 33:
		return GRASS_SUN
	return GRASS_PLAIN


## 칸 좌표 → 0~99. 🔴 **규칙적이면 안 된다** — 모듈로로 고르면 무늬가 주기로 반복돼 벌판이 벽지가
## 된다(art 손질 3회차가 정확히 그걸로 걸렸다). 해시 상수는 `base.gd _grass_variant`의 선례를 따랐다
## (표는 시트마다 다르니 파생이 아니라 같은 관용구다). `salt`로 굴림을 갈라 둔다 — 같은 값을 쓰면
## 풀 변형과 길 변형이 **같은 자리에서 같이 튀어** 무늬가 눈에 띈다.
func _cell_hash(cell: Vector2i, salt: int) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663) ^ (salt * 83492791)) % 100


## 보스 동적 스폰 — 두 경로 (ChapterDef 계약):
##  • boss_scene_path가 있으면 그 전용 씬 (snake_boss.tscn — enemy_id는 씬이 이미 품고 있다)
##  • 비면 forest_enemy.tscn 범용 스폰 — 🔴 **add_child 전에 enemy_id 대입** (forest.tscn이
##    인스턴스 오버라이드로 하던 것을 코드로. _ready가 이 id로 .tres를 물기 때문에 순서가 계약이다).
##
## 🔴 반환 = **계속 진행해도 되는가**. `boss_scene_path`는 「새 챕터 = .tres 한 장」에서 실제로
## 편집되는 자리라 오타가 나기 쉽고, 실패하면 `_ready`의 나머지(잡몹·목표 안내)를 **건너뛰어야 한다**.
## ⚠ **보스 노드를 필드로 들지 않는다** — 세99에 포탈이 은퇴하며 유일한 독자(`_spawn_return_portal`이
##  죽은 자리를 읽던 것)가 사라졌다. 아무도 안 읽는 필드를 남기면 **거짓 손잡이**가 된다(감사 T3).
##  보스를 찾아야 하면 그룹 `"enemies"` + `enemy_id`로 집어라(그물이 이미 그렇게 한다).
func _spawn_boss() -> bool:
	var boss: Node2D = null
	if _chapter.boss_scene_path != "":
		var packed := load(_chapter.boss_scene_path) as PackedScene
		if packed == null:
			push_error("boss_room: boss_scene_path '%s'를 못 읽었다 — 베이스로 되돌아간다"
				% _chapter.boss_scene_path)
			_leaving = true
			_to_base.call_deferred()
			return false
		boss = packed.instantiate() as Node2D
	else:
		var enemy := EnemyScene.instantiate() as Node2D
		enemy.set(&"enemy_id", _chapter.boss_enemy_id)
		boss = enemy
	# 🔴 위치도 add_child **앞**이 계약이다 (enemy_id와 같은 이유) — snake_body가 _ready에서
	# 부모의 그 시점 위치로 자취를 프리시드하므로, 뒤에 옮기면 ch3 입장 첫 프레임에 마디 12개가
	# 원점→boss_spawn으로 끌려간다(세54 「정지 뭉침」 재림). 루트가 원점이라 position == global.
	boss.position = _chapter.boss_spawn
	add_child(boss)
	return true


## 잡몹 길 (세66 도파민 — 즉시 보상 무대) — 방 앞쪽에 잡몹을 깐다. 플레이어가 뚫고 보스에 닿는다.
## 🔴 잡몹은 forest_enemy 범용 계약(그룹 enemies·layer4·take_hit·_die→coin 드롭). 신규 씬 0.
##  클리어 판정은 안 건드린다 — 잡몹 죽음은 _on_enemy_died에서 boss_enemy_id가 아니라 무시된다
##  (잡몹=돈·손맛 1층, 보스=clear 2·3층). 웨이브 게이팅 없이 배치만(v1).
##
## 🔴🔴 **세99 D5 — 자리는 고정, 정체만 굴린다**(사용자 확정 *"지형은 동일하고 나오는 몬스터들이 랜덤"*).
##  좌표는 **언제나** `MobSpawn.position` 그대로다 — 굴리는 건 「거기 뭐가 서 있나」뿐이다.
##  `pool_tag`가 비면 `enemy_id` 그대로 = **세98까지와 한 톨도 안 다르다**(회귀 0).
## 🔴 후보가 0이면 그 자리가 **빈 채로 선다** — 에러가 0이라(설계 §6 S1) `push_warning`으로 짖는다.
##  ⚠ 태그당 한 번만 짖는다: 자리 9곳이 같은 태그를 가리키면 같은 경고가 9줄 나와 로그가 죽는다.
func _spawn_mobs() -> void:
	var warned := {}
	for spawn: MobSpawn in _chapter.mob_spawns:
		if spawn == null:
			continue
		var id := spawn.enemy_id
		if spawn.pool_tag != &"":
			id = _roll_pool_id(spawn.pool_tag)
			if id == &"" and not warned.has(spawn.pool_tag):
				warned[spawn.pool_tag] = true
				push_warning("boss_room: %s의 mob_pool에 태그 '%s' 후보가 없다 — 그 자리들이 빈 채로 선다"
					% [String(_chapter.id), String(spawn.pool_tag)])
		_spawn_enemy_at(id, spawn.position)


## 🔴 D5 굴림 — `pool_tag`가 같은 `MobWeight`를 **weight 비례**로 하나 뽑는다. 후보가 없으면 `&""`.
##
## 🔴 **`weight <= 0`은 안 뽑는다** — `MobWeight.weight` 주석이 *"임시로 빼려면 지우지 말고 0으로"*라고
##  약속한 손잡이다. 안 지키면 **거짓 손잡이**(감사 T3)가 되고, 0으로 빼 둔 적이 그대로 나온다.
## ⚠ **시드를 고정하지 않는다** — 이 리포의 랜덤은 전역 `randf()`/`randi_range()` 하나뿐이라
##  테스트가 전역 `seed()`를 잡으면 `drop_roll.spawn_loose`의 각도 굴림 등이 **같은 스트림을 소비**해
##  순서가 조금만 바뀌어도 어긋난다(= flake). 그래서 그물은 **확률·가중치의 양끝을 주입해** 잰다.
func _roll_pool_id(tag: StringName) -> StringName:
	var ids: Array[StringName] = []
	var weights: Array[int] = []
	var total := 0
	for mw: MobWeight in _chapter.mob_pool:
		if mw == null or mw.pool_tag != tag or mw.enemy_id == &"":
			continue
		if mw.weight <= 0:   # 🔴 0 이하 = 「지금은 빼 둔다」 (지우지 않고 끄는 손잡이)
			continue
		ids.append(mw.enemy_id)
		weights.append(mw.weight)
		total += mw.weight
	if total <= 0:
		return &""
	var pick := randi_range(1, total)
	for i in ids.size():
		pick -= weights[i]
		if pick <= 0:
			return ids[i]
	return ids[ids.size() - 1]   # 부동소수 없는 정수 누적이라 도달할 일이 없다 — 방어선


## 🔴 D6 네임드 — `named_pool`의 **각 항목을 독립으로** 굴린다. **「하나도 안 뜸」이 정상 결과다**
##  (사용자 원문 *"네임드가 있을 수도 없을 수도 있음"* — 그게 「오늘 뭔가 있다」를 만든다).
##
## 🔴🔴 **표시는 생김새다 — 빛나게 하지 않는다**(세99 사용자 확정: *"몸에서 빛이나는거 까진 별로임"*).
##  덩치(`EnemyDef.params.size` = 루트 scale이라 히트박스·그림자가 공짜로 따라온다)와 전용 스프라이트로
##  구별한다. **오라·HUD 알림·입장 문구는 각하됐다 — 만들지 마라.**
## 🔴🔴 **세101 N26 4단계 — `at_landmark` 해석**(D13). 채워져 있으면 **그 지점 자리에** 선다
##  (세100까지는 `push_warning` 후 건너뛰었다 — 데이터를 채워도 조용히 안 서던 자리).
##
## 🔴 **우두머리는 잠금이 아니다**(D10-b) — 잡든 말든 [E]로 열린다. 「잡아야 열린다」를 만들지 마라.
##  그런데도 *"먼저 치우고 여는 편이 낫다"*가 **저절로** 생긴다 — 낱개를 걸어가 줍는 시간 때문이다.
## 🔴 **확률은 그대로다**(D13 = D6) — 자리만 지점에서 온다. 「지점엔 항상 우두머리」는 각하됐다
##  (사용자 확정 *"랜드마크는 랜덤임 챕터보스 랜드마크에는 항시있고"* — **보스의 「항상」은
##  `boss_spawn`이 진다**. `named_pool`에 `boss_enemy_id`를 넣으면 `_spawn_enemy_at`이 막는다).
##
## 🔴🔴 **자리마다 따로 굴린다 — 「하나 굴려 전부에 세우기」가 아니다**(설계 §10-4 **S27**).
##  같은 `landmark_id` 슬롯이 둘일 때 한 번만 굴리면 **두 둥지의 우두머리 유무가 늘 붙어 다닌다**
##  (둘 다 있거나 둘 다 없다). D6가 만들려는 건 *"이 둥지엔 뭔가 있나"*라는 **자리별** 긴장이라
##  자리마다 독립이 맞다. ⚠ 지점이 하나면 두 해석이 **같은 결과**다 — 지금 ch1이 그 상태다.
## 🔴 **미등록 id는 에러로 승격**한다(S22) — 세울 자리를 못 찾으면 **원점에 서거나 통째로 안 서는데**
##  둘 다 화면에서 *"오늘은 네임드가 안 떴네"*로 읽힌다. 데이터 쪽 짝은 `test_chapter_auto [1c]`다.
func _spawn_named() -> void:
	for named: NamedSpawn in _chapter.named_pool:
		if named == null or named.enemy_id == &"":
			continue
		if named.at_landmark == &"":
			# 🔴 `randf()`는 [0,1) — chance 0.0이면 절대 안 뜨고 1.0이면 반드시 뜬다(양끝이 그물의 손잡이).
			if randf() >= named.chance:
				continue
			_spawn_enemy_at(named.enemy_id, named.position)
			continue
		var sites := _landmark_sites(named.at_landmark)
		if sites.is_empty():
			push_error("boss_room: 네임드 '%s'의 at_landmark('%s')가 이 판에 선 지점에 없다 — 아무 데도 안 선다 (설계 §10-4 S22)"
				% [String(named.enemy_id), String(named.at_landmark)])
			continue
		for at: Vector2 in sites:
			if randf() >= named.chance:
				continue
			_spawn_enemy_at(named.enemy_id, at)


## 🔴🔴 적 하나를 세운다 — **잡몹·네임드가 지나는 유일한 문**이고 **보스 id 제외 가드가 여기 한 줄**이다.
##
## 왜 한 곳인가 (설계 §6 S9): `_on_enemy_died`의 클리어 판정이 **`enemy_id` 일치 한 줄**이라
## 풀·네임드에 `boss_enemy_id`가 섞이면 **잡몹 한 마리를 잡았을 뿐인데 `chapter_clear_*` + 보상 룬이
## 전부 조용히 나간다(에러 0)**. 세98까지 안 겹친 건 `mob_spawns`를 손으로 박아 **우연히 보장**되던 것뿐이다.
## 🔴 가드를 굴림 함수에 두지 않은 이유 = 문이 둘(잡몹·네임드)이면 **가드도 둘**이 되고 한쪽만 지워도
##  다른 쪽이 그린이라 뮤테이션이 안 걸린다. 여기 한 줄을 지우면 **두 경로가 같이 빨개진다.**
## 🔴 `enemy_id`·위치 대입은 `add_child` **앞**이 계약이다 (보스와 같은 이유 — `_ready`가 그 id로 .tres를 문다).
func _spawn_enemy_at(id: StringName, at: Vector2) -> bool:
	if id == &"":
		return false
	if _is_boss_id(id):
		push_warning("boss_room: 잡몹/네임드 자리에 보스 id('%s')가 들어왔다 — 세우지 않는다 (설계 §6 S9)"
			% String(id))
		return false
	var mob := EnemyScene.instantiate() as Node2D
	mob.set(&"enemy_id", id)
	mob.position = at
	add_child(mob)
	return true


## 🔴 클리어를 여는 id인가 — `_on_enemy_died`의 판정식과 **같은 비교**를 쓴다(사본이 아니라 파생).
func _is_boss_id(id: StringName) -> bool:
	return _chapter != null and id == _chapter.boss_enemy_id


## 🔴 클리어 판정 = **보스 처치 순간** (루팅·귀환과 무관 — 죽어서 가방을 잃어도 클리어는 남는다.
## "이기면 열림"이 순수해서 억울함이 없다). 키는 `Db.chapter_clear_id` 파생 한 곳 — 여기서 문자열을
## 조립하지 않는다(세50 계열 오타 함정). codex_unlocked 한 발로 codex 심기 + UNLOCK 퀘스트 진행 +
## Audio unlock음이 전부 따라온다 (세37 station_* 패턴).
func _on_enemy_died(enemy_id: StringName) -> void:
	if _cleared or _chapter == null or enemy_id != _chapter.boss_enemy_id:
		return
	_cleared = true
	var clear_id := Db.chapter_clear_id(_chapter)
	# ⚠ 재입장(파밍 재방문)이면 codex가 이미 있다 — 다시 쏘면 UNLOCK 퀘스트·해금음이 중복으로
	# 반응하므로 첫 클리어에만 쏜다. ✅ **나가는 길은 이 함수와 무관하다** — 출구는 처음부터 서 있어서
	# 세99 이전의 「포탈이 안 뜨면 재방문 소프트락」이라는 위험 자체가 사라졌다.
	if not GameState.is_unlocked(clear_id):
		EventBus.codex_unlocked.emit(clear_id)
	# 🔴 클리어 보상 해금 (세71 첫 스테이지) — ChapterDef.reward_unlock가 있으면 codex에 심는다.
	# chapter_clear와 **별도 축**이다(clear_id는 챕터 게이트, reward_unlock은 획득물=문양 링/룬/진).
	# 첫 처치에만: 재방문 파밍 때 다시 쏘면 Audio 해금음·UNLOCK 퀘스트가 중복 반응한다(clear 가드와 같은 결).
	# codex_unlocked 한 발로 codex 심기 + 해금음 + UNLOCK 퀘스트 진행이 전부 따라온다(세37 station_* 패턴).
	var reward_line := ""
	if _chapter.reward_unlock != &"" and not GameState.is_unlocked(_chapter.reward_unlock):
		EventBus.codex_unlocked.emit(_chapter.reward_unlock)
		# 🔴 문구는 `CodexText`가 낸다 — 룬·진·고리마다 「어디에 쓰는지」가 다르고(중심·바탕·밴드)
		# 발신처가 셋이라, 여기서 조회를 조립하면 그게 곧 사본이다(감사 T5). 세88에 보상이 고리에서
		# **룬**으로 바뀌며 옛 `Db.get_glyph_ring` 한 줄이 원시 id + 거짓 안내를 찍고 있었다.
		var reward_label := CodexText.label_of(_chapter.reward_unlock)
		if reward_label != "":
			reward_line = " 보상: %s" % reward_label
	# 🔴 세84 #36: `sticky` — 클리어 뒤에도 **아직 할 일이 남아 있다**(살아서 나가야 한다). 그게
	# 이 줄이 sticky인 이유이자, 세99에 포탈을 없앤 이유이기도 하다 — 처치가 곧 끝이 아니다.
	# ⚠ **「포탈」을 다시 적지 마라**(T4: 없는 물건을 가리키는 안내는 그대로 거짓 지시가 된다).
	_hud.say("%s 클리어!%s 이제 살아서 나가라 — 출구에서 [E] 꾹" % [_chapter.title, reward_line],
		false, true)


## 🔴 귀환 성공 — `extraction_success`가 **가방(루팅분 포함)을 창고로 옮기고 자동 저장**한다
## (GameState·SaveManager가 이미 이 시그널에 연결돼 있다). 안 쏘면 루팅한 게 다음 사망 때 증발하고
## q02(EXTRACT)가 영영 안 찬다 — forest._extract 계약 그대로.
## ⚠ **부르는 곳이 여럿이다** — 출구 전부(`_build_exits`)가 `_wire_extract_zone` 한 문을 지난다.
## 새 길을 뚫으면 거기로 이어라 (세99에 포탈이 은퇴해 지금 발신원은 출구뿐이다).
## ✅ **이중 전환 방어는 이미 서 있다** — `_leaving` 가드가 길이 몇 개든 한 번으로 묶는다
##  (출구를 늘리며 새로 짜지 마라 — 세47 「이미 있는 배선」의 결).
func _extract() -> void:
	if _leaving:
		return
	_leaving = true
	EventBus.extraction_success.emit()
	_to_base()


func _on_hp_changed(hp: float, _hp_max: float) -> void:
	if hp <= 0.0:
		_die()


## 쓰러졌다 — `bag_lost`가 가방을 비우고 자동 저장한다(세이브스컴 방지). 클리어 codex는 처치 순간
## 이미 심겼으므로(§클리어 판정) 죽어도 다음 챕터는 열려 있다. forest._die 계약 그대로.
##
## 🔴 **사망 후 HP 복구를 쥐는 건 이 함수다** (세84 감사 #37). HP는 오토로드(GameState)가 쥐고
## 세이브에 없어서, 예전엔 되돌리는 경로가 **어디에도 없었다** — 베이스로 걸어 나가는 몸이 HP 0이었다
## (마을에 피해원이 0곳이라 표시 문제로만 보였지, 피해원이 하나 생기는 날 즉사 버그가 된다).
## ⚠ **「출격 = 만HP」의 단일 소스는 `_ready`**(`base._open_chapter_panel` 위 주석이 *"출격이 HP를
## 되돌리지 않는다 — 그건 보스방이 한다"*고 선언한다). 그래서 복구도 베이스가 아니라 **여기**가 쥔다 — 베이스에 두면
## 「베이스를 거쳐 들어올 때만」 맞고 다른 진입 경로에선 조용히 달라진다(그 주석이 경고한 그 함정).
## 🔴 복구는 **연출(DEATH_BEAT_SEC) 뒤**다: 먼저 되돌리면 「쓰러졌다」를 띄운 채 HP 막대가 꽉 차
## "안 죽었다"로 읽힌다. 되돌리는 emit이 `_on_hp_changed`를 다시 태우지만 `_leaving` 가드가 막는다.
func _die() -> void:
	if _leaving:
		return
	_leaving = true
	_player.caster.enabled = false
	_player.set_physics_process(false)
	_hud.say("쓰러졌다 — 베이스로 돌아온다", true)
	EventBus.bag_lost.emit()
	await get_tree().create_timer(DEATH_BEAT_SEC).timeout
	GameState.reset_player_hp()
	_to_base()


func _to_base() -> void:
	get_tree().change_scene_to_file(base_scene_path)


## 목표 하나를 달성했다 — 아직 완료 아님. 마을 **문**으로 돌아가 정산하라고 HUD로 민다 (forest 선례).
## 🔴🔴 세95: 옛 문구는 *"길잡이에게 돌아가 정산하라 [?]"*였는데 **길잡이가 은퇴해 없는 사람을 가리켰다**
##   (끝의 `[?]`도 그 머리 위 마크였다 — 지금은 문 위에 뜬다, `base.gd _refresh_gate_mark`).
## ⚠ 이 줄은 **원정 중에 실제로 화면에 뜨는 안내**다. `base.gd _on_quest_ready`와 **일부러 문구가 다르다**:
##   여긴 원정 중이라 「마을로 돌아가」가 붙고, 마을에선 이미 문 앞이라 안 붙는다.
##   (세95 전엔 두 줄이 **한 글자도 안 달라** 감사 T5 「파생 대신 복제」의 표본이었다 — 지금은 뜻이 갈렸다.)
func _on_quest_ready(quest_id: StringName) -> void:
	var q := Db.get_quest(quest_id)
	if q != null:
		_hud.say("목표 달성: %s — 마을로 돌아가 문에서 [E]로 정산하라 [?]" % q.title)
