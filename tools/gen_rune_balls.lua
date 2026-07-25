-- 번개·흙·풀 원소 볼 시트 생성 (세84 · takbon-art)
-- 세78 파이어볼/워터볼/윈드볼과 **같은 92×48 혜성 지오메트리**를 쓴다.
-- 실측 결과: 세 시트는 필드(실루엣+프레임별 노이즈)가 비트 동일하고 8밴드 색 램프 + 밴드별
-- 알파 배수만 다르다. → 파이어볼 PNG에서 필드를 읽어 램프만 갈고, 그 위에 원소별 질감을 얹는다.
--   번개 = 지그재그 아크 + 튀는 스파크 / 흙 = 자갈 파편(좌상단 광원) / 풀 = 잎날·덩굴손
-- 🔴 파이어볼 PNG는 **읽기만** 한다(재익스포트 금지 — 세69 relight 원복 함정).
--
-- 🔴 램프는 **불·물의 명도 곡선(≈59,73,93,119,160,205,239,247)을 따라간다** — 색조만 갈고 명도
-- 곡선을 지키는 게 「같은 발사체 계열」의 정체다. 초안이 명도를 통째로 올렸다가 몸통이 납작한
-- 단색 덩어리로 읽혔다(밝은 밴드 4개가 구분이 안 갔다).
-- 최상단은 원소마다 갈린다: 번개 250(백열 — 실제로 빛이다) · 흙 225(무광 흙덩이) · 풀 234(수액빛).

local ROOT = "C:/Users/djgnf/Desktop/godot_games/tockbon/"
local SRC  = ROOT .. "assets/sprites/effects/fireball_sheet.png"
local ASE  = ROOT .. "assets/aseprite/"
local PNG  = ROOT .. "assets/sprites/effects/"
local FW, FH, NF = 92, 48, 6
local CX, CY = 72, 24    -- 코어 중심 (파이어볼 실측)

local FIRE_BANDS = {
	{110,34,54}, {150,44,48}, {190,64,45}, {214,102,48},
	{232,150,58}, {245,200,96}, {253,236,170}, {255,250,228},
}

local _seed = 0
local function srnd(s) _seed = s % 2147483648 end
local function rnd()
	_seed = (1103515245 * _seed + 12345) % 2147483648
	return _seed / 2147483648
end
local function rndi(a, b) return a + math.floor(rnd() * (b - a + 1)) end

local pc = app.pixelColor

-- 룬 색 정본 = data/runes/*.tres 의 ui_color (볼·트레일·상태 틴트가 같은 마법으로 읽히게):
--   번개 (199,179,56) · 흙 (115,87,51) · 풀 (92,168,66)
-- 노랑·초록은 색조 자체가 밝아 ui_color가 밴드 2가 아니라 4쯤에 앉는다(윈드볼도 그렇다) —
-- 색조는 같고 명도만 곡선을 따른다.
local ELEMS = {
	{
		id = "boltball",
		ramp = { {72,62,22},{92,78,26},{115,98,30},{150,128,40},
		         {190,168,56},{235,210,105},{253,242,180},{255,252,232} },
		amul = {0.68,0.80,0.92,1.00,1.00,1.00,1.00,1.00},   -- 바깥 연무를 눌러 「스파크」로
		overlay = "bolt",
	},
	{
		id = "earthball",
		-- 🔴 최상단이 207에서 멈춘다(불은 249) — **흙은 빛나지 않는다**. 초안이 불과 같은 곡선까지
		-- 올렸다가 머리가 「모래 먼지 구름」으로 읽혔다. 무광 흙덩이 = 위쪽 밴드를 눌러 갈색을 지킨다.
		ramp = { {70,52,36},{92,68,45},{115,87,51},{146,112,68},
		         {178,141,92},{200,166,118},{216,187,142},{230,203,164} },
		amul = {0.90,1.00,1.00,1.00,1.00,1.00,1.00,1.00},
		overlay = "earth",
	},
	{
		id = "grassball",
		ramp = { {38,64,36},{48,86,44},{62,112,52},{80,140,62},
		         {105,180,78},{150,212,112},{196,235,158},{225,246,196} },
		amul = {0.80,0.92,1.00,1.00,1.00,1.00,1.00,1.00},
		overlay = "grass",
	},
}

-- ── 소스 필드 읽기 ─────────────────────────────────────────────
local key = {}
for i, c in ipairs(FIRE_BANDS) do key[c[1] * 65536 + c[2] * 256 + c[3]] = i end

local src = app.open(SRC)
assert(src ~= nil, "소스 PNG 열기 실패: " .. SRC)
assert(src.width == FW * NF and src.height == FH,
	"소스 크기가 예상과 다르다: " .. src.width .. "x" .. src.height)
local flat = Image(src.width, src.height, ColorMode.RGB)
flat:drawSprite(src, 1, Point(0, 0))

local band, alph = {}, {}
local unknown = 0
for f = 0, NF - 1 do
	band[f], alph[f] = {}, {}
	for y = 0, FH - 1 do
		band[f][y], alph[f][y] = {}, {}
		for x = 0, FW - 1 do
			local v = flat:getPixel(f * FW + x, y)
			local a, b = pc.rgbaA(v), 0
			if a > 0 then
				b = key[pc.rgbaR(v) * 65536 + pc.rgbaG(v) * 256 + pc.rgbaB(v)] or 0
				if b == 0 then unknown = unknown + 1 end
			else
				a = 0
			end
			band[f][y][x], alph[f][y][x] = b, a
		end
	end
end
src:close()
print("필드 읽기 완료 — 미분류 픽셀: " .. unknown .. " (0이어야 정상)")

-- ── 그리기 헬퍼 ────────────────────────────────────────────────
local function put(img, x, y, c, a)
	if x < 0 or y < 0 or x >= FW or y >= FH or a <= 0 then return end
	local r, g, b = c[1], c[2], c[3]
	local old = img:getPixel(x, y)
	local oa = pc.rgbaA(old)
	if a >= 255 or oa == 0 then
		img:drawPixel(x, y, pc.rgba(r, g, b, a))
		return
	end
	local t = a / 255
	local orr, og, ob = pc.rgbaR(old), pc.rgbaG(old), pc.rgbaB(old)
	local na = math.min(255, math.floor(oa + a * (255 - oa) / 255 + 0.5))
	img:drawPixel(x, y, pc.rgba(
		math.floor(orr + (r - orr) * t + 0.5),
		math.floor(og + (g - og) * t + 0.5),
		math.floor(ob + (b - ob) * t + 0.5), na))
end

local function seg(x0, y0, x1, y1, fn)
	local dx, dy = math.abs(x1 - x0), math.abs(y1 - y0)
	local sx = x0 < x1 and 1 or -1
	local sy = y0 < y1 and 1 or -1
	local err = dx - dy
	while true do
		fn(x0, y0)
		if x0 == x1 and y0 == y1 then break end
		local e2 = 2 * err
		if e2 > -dy then err = err - dy; x0 = x0 + sx end
		if e2 < dx then err = err + dx; y0 = y0 + sy end
	end
end

-- ── 번개 ───────────────────────────────────────────────────────
-- 실루엣 안에서만 그어 아크가 끊기며 「크래클」로 읽힌다. 아크는 프레임마다 완전히 새로
-- 뽑는다 — 번개는 궤적이 이어지는 물건이 아니라 매 순간 다시 치는 물건이다.
local function ov_bolt(img, f, A, R)
	local wht, hot, halo = R[8], R[7], R[6]
	local function arc(x0, y0, x1lim, thick)
		local px, py = x0, y0
		while px > x1lim do
			local nx = math.max(x1lim, px - rndi(5, 9))
			local ny = math.max(7, math.min(40, py + rndi(-9, 9)))
			seg(px, py, nx, ny, function(cx, cy)
				if A(cx, cy) >= 16 then
					put(img, cx, cy, wht, 255)
					if thick then put(img, cx, cy - 1, hot, 235) end
					put(img, cx, cy - (thick and 2 or 1), halo, 120)
					put(img, cx, cy + (thick and 2 or 1), halo, 120)
				end
			end)
			px, py = nx, ny
			-- 갈래 — 본줄에서 짧게 튄다
			if rnd() < 0.32 then
				local bx = math.max(16, px - rndi(4, 7))
				local by = math.max(7, math.min(40, py + (rnd() < 0.5 and -1 or 1) * rndi(5, 10)))
				seg(px, py, bx, by, function(cx, cy)
					if A(cx, cy) >= 16 then put(img, cx, cy, hot, 215) end
				end)
			end
		end
	end
	-- 굵은 본줄 1개(코어에서 출발) + 얇은 곁줄 1~2개
	arc(CX - 2, CY + rndi(-3, 3), 21, true)
	for _ = 1, 1 + (f % 2) do
		arc(CX - rndi(4, 12), CY + rndi(-8, 8), rndi(26, 38), false)
	end
	-- 튀는 스파크 — 전기는 실루엣 밖으로 조금 새어나간다
	for _ = 1, 6 do
		local sx, sy = rndi(18, 88), rndi(9, 38)
		if A(sx, sy) >= 8 then
			local dx = rnd() < 0.5 and 1 or -1
			local dy = rnd() < 0.5 and 1 or -1
			put(img, sx, sy, wht, 245)
			put(img, sx + dx, sy + dy, wht, 200)
			put(img, sx + dx * 2, sy + dy * 2, halo, 135)
		end
	end
end

-- ── 흙 ────────────────────────────────────────────────────────
-- 자갈·파편. 🔴 좌상단 광원 = 밝은 윗면 + 우하단 짙은 그늘 (매끈하지 않은 입체).
-- 파편은 프레임마다 코어를 **궤도로 돈다** — 무작위로 튀면 깜빡임이 되고, 돌면 「뭉쳐 굴러가는
-- 흙덩이」로 읽힌다.
local ROCKS = nil
local function ov_earth(img, f, A, R)
	-- 🔴 돌 몸통은 밴드 2·4, 그늘만 밴드 1이다. 몸통을 밴드 1로 하면 밝은 머리 위에서 **검은
	-- 구멍**으로 읽힌다(x8 검수에서 「짙은 대시」로 보였다) — 3단 명암이라야 돌로 선다.
	local dk, md, lt, hi, sh = R[2], R[4], R[6], R[7], R[1]
	if ROCKS == nil then
		ROCKS = {}
		srnd(4471)
		-- 🔴 초안은 3×2 파편 24개였는데 「밝은 덩어리에 뚫린 검은 점」으로 읽혔다 —
		-- 크게(4~5×3~4) · 적게(10개) · 윗면을 확실히 밝혀야 「빛 받은 돌」이 된다.
		for i = 1, 10 do
			ROCKS[i] = {
				rx = rndi(4, 19), ry = rndi(3, 10),
				ph = rnd() * 6.2832, sp = (rnd() < 0.5 and -1 or 1) * (0.7 + rnd() * 0.7),
				w = rndi(4, 5), h = rndi(3, 4), dark = rnd() < 0.5,
			}
		end
		-- 꼬리로 흩날리는 잔 파편
		for i = 11, 17 do
			ROCKS[i] = { tail = true, x0 = rndi(22, 66), y = rndi(13, 35), w = rndi(2, 3),
				h = 2, dark = rnd() < 0.6 }
		end
	end
	local function chunk(cx, cy, w, h, dark)
		if A(cx + math.floor(w / 2), cy + math.floor(h / 2)) < 60 then return end
		local base = dark and dk or md
		for yy = 0, h - 1 do
			for xx = 0, w - 1 do put(img, cx + xx, cy + yy, base, 255) end
		end
		-- 윗면(좌상단 광원) — 위 한 줄 + 왼쪽 모서리를 가장 밝게
		for xx = 0, w - 1 do put(img, cx + xx, cy, xx <= 1 and hi or lt, 255) end
		if h > 2 then put(img, cx, cy + 1, lt, 235) end
		-- 우하단 그늘 — 얇은 돌(h=3)은 아래 줄을 통째로 먹으면 몸통이 한 줄만 남아 대시가 된다
		if h >= 4 then
			for xx = 1, w - 1 do put(img, cx + xx, cy + h - 1, sh, 245) end
		else
			for xx = math.max(1, w - 2), w - 1 do put(img, cx + xx, cy + h - 1, sh, 245) end
		end
	end
	for _, r in ipairs(ROCKS) do
		if r.tail then
			local x = r.x0 - f * 4
			if x < 16 then x = x + 52 end
			chunk(x, r.y, r.w, r.h, r.dark)
		else
			local a = r.ph + f * 0.42 * r.sp
			chunk(CX - 4 + math.floor(math.cos(a) * r.rx),
				CY - 1 + math.floor(math.sin(a) * r.ry), r.w, r.h, r.dark)
		end
	end
end

-- ── 풀 ────────────────────────────────────────────────────────
-- 잎날 + 덩굴손. 잎은 코어를 감돌며(프레임 위상) 꼬리로 흩어진다.
-- 초안은 잎을 1px 폭으로 그려 **낙서 선**으로 읽혔다 → 폭 2(가운데 5px)로 키우고 짙은 잎몸 +
-- 위 가장자리 하이라이트 + 아래 가장자리 어두운 림으로 잎 모양을 세운다.
local LEAVES = nil
local function ov_grass(img, f, A, R)
	local rim, body, hi, vein = R[1], R[2], R[5], R[3]
	local function leaf(cx, cy, ang, len, wid)
		local ca, sa = math.cos(ang), math.sin(ang)
		for t = 0, len do
			local u = t / len
			local hw = math.floor(wid * math.sin(math.pi * u) + 0.55)
			for k = -hw, hw do
				local px = math.floor(cx + ca * t - sa * k + 0.5)
				local py = math.floor(cy + sa * t + ca * k + 0.5)
				if A(px, py) >= 36 then
					local c = body
					if hw > 0 and k == -hw then c = hi          -- 위 가장자리 = 빛
					elseif hw > 0 and k == hw then c = rim      -- 아래 가장자리 = 림
					elseif k == 0 and hw > 0 then c = vein end  -- 잎맥
					put(img, px, py, c, 242)
				end
			end
		end
	end
	if LEAVES == nil then
		LEAVES = {}
		srnd(8823)
		-- 길고 얇게 = 잎 「날」. 짧고 넓으면 얼룩으로 읽힌다(초안이 그랬다).
		for i = 1, 6 do
			LEAVES[i] = { rx = rndi(6, 17), ry = rndi(4, 11), ph = rnd() * 6.2832,
				len = rndi(8, 10), wid = 2, tw = 1.6 + rnd() * 1.2 }
		end
		for i = 7, 13 do
			LEAVES[i] = { tail = true, x0 = rndi(24, 62), y = rndi(14, 34),
				ang = rnd() * 6.2832, len = rndi(5, 7), wid = 1 }
		end
	end
	for _, l in ipairs(LEAVES) do
		if l.tail then
			local x = l.x0 - f * 3
			if x < 18 then x = x + 42 end
			leaf(x, l.y, l.ang + f * 0.25, l.len, l.wid)
		else
			local a = l.ph + f * 0.40
			leaf(CX - 4 + math.floor(math.cos(a) * l.rx),
				CY + math.floor(math.sin(a) * l.ry), a + l.tw, l.len, l.wid)
		end
	end
	-- 덩굴손 — 꼬리에서 감기며 풀리는 짧은 나선 2개(전체를 가로지르지 않는다)
	for v = 0, 1 do
		local sx = 40 - v * 12
		local sy = CY + (v == 0 and -7 or 7)
		local a0 = (f / NF) * 6.2832 + v * 3.1416
		local px, py = nil, nil
		for i = 0, 16 do
			local t = i / 16.0
			local rr = 3.0 + t * 5.0
			local a = a0 + t * 4.2 * (v == 0 and 1 or -1)
			local x = math.floor(sx - t * 9 + math.cos(a) * rr + 0.5)
			local y = math.floor(sy + math.sin(a) * rr * 0.7 + 0.5)
			if px ~= nil then
				seg(px, py, x, y, function(cx, cy)
					if A(cx, cy) >= 30 then put(img, cx, cy, vein, 195) end
				end)
			end
			px, py = x, y
		end
	end
end

local OVS = { bolt = ov_bolt, earth = ov_earth, grass = ov_grass }

-- ── 생성 ───────────────────────────────────────────────────────
for _, e in ipairs(ELEMS) do
	ROCKS, LEAVES = nil, nil   -- 원소마다 파티클 재생성
	local frames = {}
	for f = 0, NF - 1 do
		local img = Image(FW, FH, ColorMode.RGB)
		-- ① 램프 재색칠 — 지오메트리(실루엣·프레임 노이즈)는 파이어볼 그대로
		for y = 0, FH - 1 do
			for x = 0, FW - 1 do
				local b = band[f][y][x]
				if b > 0 then
					local c = e.ramp[b]
					local a = math.floor(alph[f][y][x] * e.amul[b] + 0.5)
					if a > 0 then img:drawPixel(x, y, pc.rgba(c[1], c[2], c[3], math.min(255, a))) end
				end
			end
		end
		-- ② 원소 질감
		local A = function(x, y)
			if x < 0 or y < 0 or x >= FW or y >= FH then return 0 end
			return alph[f][y][x]
		end
		srnd(9173 + f * 811 + #e.id * 37)
		OVS[e.overlay](img, f, A, e.ramp)
		frames[f + 1] = img
	end

	-- .aseprite (6프레임 · 60ms · loop 태그 — 기존 볼 시트와 같은 규격)
	local spr = Sprite(FW, FH)
	while #spr.frames < NF do spr:newFrame() end
	for i = 1, NF do
		spr:newCel(spr.layers[1], i, frames[i], Point(0, 0))
		spr.frames[i].duration = 0.06
	end
	local tag = spr:newTag(1, NF)
	tag.name = "loop"
	spr:saveAs(ASE .. e.id .. "_sheet.aseprite")
	spr:close()

	-- 가로 스트립 PNG (552×48) — ring_carrier.tscn의 AtlasTexture 규약
	local sheet = Sprite(FW * NF, FH)
	local simg = Image(FW * NF, FH, ColorMode.RGB)
	for f = 0, NF - 1 do
		for y = 0, FH - 1 do
			for x = 0, FW - 1 do
				simg:drawPixel(f * FW + x, y, frames[f + 1]:getPixel(x, y))
			end
		end
	end
	sheet:newCel(sheet.layers[1], 1, simg, Point(0, 0))
	sheet:saveAs(PNG .. e.id .. "_sheet.png")
	sheet:close()
	print("생성: " .. e.id .. "_sheet (" .. (FW * NF) .. "x" .. FH .. ")")
end
print("DONE")
