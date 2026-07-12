extends RefCounted
## 모듈 D 레시피 원장 — 정제·종이 제작·연구 프로젝트.
## 아이템 id는 data/items/*.tres 와 일치해야 한다 (모듈 C와 합의된 규약).
## 시간·비율 등 밸런스 수치는 data/balance.tres 를 쓴다 — 여기는 조합표만.

## 정제 (작업대): cost 재료 → output 잉크
const REFINE: Dictionary = {
	&"refine_ink_basic_vine": {
		"name": "덩굴 먹물 정제",
		"cost": {&"mat_vine": 3},
		"output": {&"ink_basic": 2},
	},
	&"refine_ink_basic_slime": {
		"name": "슬라임 핵 정제",
		"cost": {&"mat_slime_core": 2, &"mat_hound_fang": 1},
		"output": {&"ink_basic": 3},
	},
	&"refine_ink_mid": {
		"name": "밤꽃 먹물 정제",
		"cost": {&"mat_night_bloom": 2, &"mat_vine": 2},
		"output": {&"ink_mid": 2},
	},
	&"refine_ink_high": {
		"name": "달빛 먹물 정제",
		"cost": {&"mat_moon_sap": 2, &"mat_mist_essence": 2},
		"output": {&"ink_high": 1},
	},
}

## 종이 제작 (작업대): unlock == &"" 이면 연구 없이 제작 가능
const PAPER: Dictionary = {
	&"craft_paper_1": {
		"name": "기본 종이 뜨기",
		"unlock": &"",
		"cost": {&"mat_vine": 2, &"mat_beetle_shell": 1},
		"output": {&"paper_1": 2},
	},
	&"craft_paper_2": {
		"name": "중급 종이 뜨기",
		"unlock": &"recipe_paper_2",
		"cost": {&"paper_1": 1, &"mat_beetle_shell": 2, &"mat_night_bloom": 1},
		"output": {&"paper_2": 1},
	},
	&"craft_paper_3": {
		"name": "상급 종이 뜨기",
		"unlock": &"recipe_paper_3",
		"cost": {&"paper_2": 1, &"mat_moon_sap": 1, &"mat_mist_essence": 2},
		"output": {&"paper_3": 1},
	},
}

## 연구 (연구소): 키 = research_completed 로 발신되는 unlock_id.
## cost 는 창고(GameState.inventory)에서 소모, 소요 시간은 balance.research_time_sec.
const RESEARCH: Dictionary = {
	&"rune_water": {
		"name": "물 룬 해독",
		"cost": {&"fragment_water": 1},
		"prereq": &"",
	},
	&"rune_wind": {
		"name": "바람 룬 해독",
		"cost": {&"fragment_wind": 1},
		"prereq": &"",
	},
	&"recipe_paper_2": {
		"name": "중급 종이 제법 연구",
		"cost": {&"mat_night_bloom": 2, &"mat_beetle_shell": 2},
		"prereq": &"",
	},
	&"recipe_paper_3": {
		"name": "상급 종이 제법 연구",
		"cost": {&"mat_moon_sap": 2, &"mat_mist_essence": 2},
		"prereq": &"recipe_paper_2",
	},
}
