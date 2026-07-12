extends RefCounted
## 가로 스트립 스프라이트시트 → SpriteFrames 빌더 (core 공용 — 모듈 B·C가 사용).
## class_name 없음 — `const SheetLib := preload("res://src/core/sheet_lib.gd")`로 참조.
## anims: { 애니 이름: [시작 프레임, 프레임 수, fps] } — ART_SPEC 파일 규칙(가로 스트립) 전제.

static func build_sprite_frames(tex: Texture2D, anims: Dictionary, frame_size: int) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for anim_name: String in anims:
		var d: Array = anims[anim_name]
		var sn := StringName(anim_name)
		frames.add_animation(sn)
		frames.set_animation_speed(sn, float(d[2]))
		frames.set_animation_loop(sn, true)
		for i in range(int(d[1])):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2((int(d[0]) + i) * frame_size, 0, frame_size, frame_size)
			frames.add_frame(sn, at)
	return frames
