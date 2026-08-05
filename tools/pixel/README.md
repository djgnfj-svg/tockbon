# 에셋 생성 — 로컬 ComfyUI

pixellab 크레딧을 안 쓰고 **이 PC의 GPU로** 마법진 UI · 문양 · 룬 · 진을 뽑는다.

## 어디에 무엇이 있나

| 무엇 | 어디 | 왜 |
|---|---|---|
| 스크립트 (이 폴더) | `tools/pixel/` | 리포에 커밋된다 |
| ComfyUI 본체 · 모델 12GB | `config.json` 의 `comfy_root` | 🔴 **리포에 안 들어온다.** 기계가 바뀌면 그 한 줄만 고친다 |
| 뽑은 후보 | `tools/pixel/out/` | gitignore. 🔴 **고른 것만** `assets/` 로 옮긴다 |

원본 파이프라인은 `CompyUI_2DPixel/pixel_pipeline/` 이고 **캐릭터 4방향 걷기 시트 전용**이다.
여기는 그 모델만 빌려 쓰고 워크플로우를 새로 잡았다.

## 쓰는 법

```powershell
powershell -File tools\pixel\serve.ps1          # 서버 (한 번만, 켜 두면 됨)

$py = "C:\Users\djgnf\Desktop\window_project\CompyUI_2DPixel\ComfyUI_windows_portable\python_embeded\python.exe"
& $py tools\pixel\gen.py "eight straight rays radiating from a center point inside a hexagon" `
    --name glyph_spread --preset glyph --batch 8

& $py tools\pixel\sheet.py tools\pixel\out\glyph_spread --cols 4 --zoom 3
```

`_sheet.png` 한 장이 나오고, 거기서 골라 `assets/` 로 옮긴다.

## 프리셋 — 스타일이 갈리는 것을 막는 자리

`gen.py` 의 `PRESETS` 하나가 스타일 문구 · LoRA 강도 · 크기를 같이 들고 있다.

| 프리셋 | 무엇 | 생성 → 최종 |
|---|---|---|
| `glyph` | 층에 끼우는 기하학 무늬 | 512 → 64px |
| `frame` | 진 — 층이 갈리는 동심 틀 | 512 → 256px |
| `rune` | 룬 — 🔴 기하학일 필요 없다 | 512 → 96px |
| `ui` | 조립창 (펼친 마도서) | 512 → 그대로 |
| `raw` | 스타일 문구 없이 | 512 → 그대로 |

🔴🔴 **`--lora` 는 전부 0이다.** 4-walk LoRA를 켜면 UI 프롬프트에도 **사람 스프라이트시트가 나온다**
(원본 `PROMPTS.md` 의 실측). 캐릭터를 뽑을 때만 1.0이고, 그건 원본 파이프라인의 몫이다.

## 🔴 크기 — 뽑기 전에 본다

🔴🔴 **기준 문서는 `docs/design/마법진-그림.md` 다.** 왜 이 크기인지, 무엇이 안 풀렸는지가 거기 있다.
여기는 뽑을 때 쓰는 **숫자만** 든다.

| 무엇 | 파일 크기 | 생성 → 내림 |
|---|---|---|
| 문양 1층 (2층 진) | **112** | 768 → 112 |
| 문양 2층 (2층 진) | **224** | 768 → 224 |
| 룬 (진 테두리) | **96** | 768 → 96 |
| 진 | **560** | **1120 → 560** |
| 조립창 | 864×372 | 864×376 로 뽑아 4px 자른다 |

🔴🔴 **비정수 축소를 피해라.** 1024 → 560 은 1.83배라 **선이 깨져 자글자글해진다**(실측).
**1120 → 560(정확히 2배)** 로 뽑으면 안 깨진다.

⚠ **문양은 「층에 붙는 점」이 아니라 「층을 채우는 링」이다.** 도넛으로 뽑고, 층마다
안쪽 구멍 비율이 다르므로(1층 0 · 2층 1/2 · 3층 2/3) **띠 밖을 잘라내서** 얹는다.

🔴 **지형은 여기 없다.** 4px 셀 단위로 파괴돼서 셰이더가 셀마다 색을 칠한다
(`cell_materials.DEFS`) — 타일 그림이 들어갈 자리가 없다.

## 함정 — 원본 파이프라인이 실측으로 남긴 것

`CompyUI_2DPixel/pixel_pipeline/PROMPTS.md` 가 기준이다. 옮겨 적지 않고 요점만 가리킨다.

- **버튼 상태(normal/hover/pressed)는 안 나온다.** 다섯이 거의 같게 나온다 — 하나 뽑고 손으로 만든다
- **9-slice 로 늘리면 모서리가 어긋난다.** 네 모서리 장식이 제각각이다
- **참조 이미지는 그림 자체를 거의 복제한다.** 남의 그림을 스타일 참조로 넣지 마라
- **아이콘은 `no slots no frames` · `evenly spaced apart` 를 넣어야** 낱장으로 갈린다
