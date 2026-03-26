class_name JuicyEffects
extends RefCounted

## Статичні утиліти для premium тактильних анімацій.
## Використовується з будь-якого контексту — ігри, UI, меню.
## Кожен метод перевіряє reduced_motion першим рядком.


## Тактильний squish при натисканні кнопки — elastic bounce.
## Підключається до pressed сигналу, працює автоматично.
static func button_press_squish(btn: BaseButton, scene_root: Node) -> void:
	if not is_instance_valid(btn) or not is_instance_valid(scene_root):
		return
	btn.pressed.connect(func() -> void:
		if SettingsManager and SettingsManager.reduced_motion:
			return
		if not is_instance_valid(btn):
			return
		btn.pivot_offset = btn.size / 2.0
		var tw: Tween = scene_root.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.92, 0.92), 0.04)
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.08)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.06)
		## Rotation wobble ±2° для тактильності
		var tw_rot: Tween = scene_root.create_tween()
		tw_rot.tween_property(btn, "rotation", deg_to_rad(2.0), 0.04)
		tw_rot.tween_property(btn, "rotation", deg_to_rad(-1.5), 0.06)
		tw_rot.tween_property(btn, "rotation", 0.0, 0.08)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		## Brightness flash
		var tw_mod: Tween = scene_root.create_tween()
		tw_mod.tween_property(btn, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.05)
		tw_mod.tween_property(btn, "modulate", Color.WHITE, 0.1)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)


## Пульс посадки — коли предмет приземляється на ціль.
## Швидкий scale bounce + snap_pulse VFX.
static func arrival_pulse(node: CanvasItem, scene_root: Node) -> void:
	if SettingsManager and SettingsManager.reduced_motion:
		return
	if not is_instance_valid(node) or not is_instance_valid(scene_root):
		return
	var original: Vector2 = node.scale
	var tw: Tween = scene_root.create_tween()
	## 3-stage: squash → stretch → settle
	tw.tween_property(node, "scale", original * Vector2(0.9, 1.18), 0.06)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", original * Vector2(1.12, 0.92), 0.07)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", original, 0.12)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	## Snap pulse VFX
	if node is Node2D:
		VFXManager.spawn_snap_pulse((node as Node2D).global_position)


## Combo escalation — прогресивне святкування серії правильних відповідей.
## streak 3: tap_stars, streak 5: golden_burst, streak 8+: rainbow_ring.
static func combo_vfx(pos: Vector2, streak: int) -> void:
	if SettingsManager and SettingsManager.reduced_motion:
		return
	if streak >= 8:
		VFXManager.spawn_rainbow_ring(pos)
	elif streak >= 5:
		VFXManager.spawn_golden_burst(pos)
	elif streak >= 3:
		VFXManager.spawn_tap_stars(pos)


## Subtle screen shake — тільки для перемог (streak, finish). 2-4px, 0.2s.
## Позитивний feedback only (LAW 16: жодного harsh shake на помилки).
static func screen_shake(scene_root: CanvasItem, intensity: float = 3.0) -> void:
	if SettingsManager and SettingsManager.reduced_motion:
		return
	if not is_instance_valid(scene_root):
		return
	var original: Vector2 = scene_root.position
	var tw: Tween = scene_root.create_tween()
	for i: int in 4:
		var offset: Vector2 = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity))
		tw.tween_property(scene_root, "position", original + offset, 0.04)
	tw.tween_property(scene_root, "position", original, 0.04)


## Статичний staggered entrance — для контекстів без BaseMiniGame.
## Каскадна поява з elastic bounce.
static func stagger_entrance(scene_root: Node, nodes: Array,
		delay_per_item: float = 0.08) -> void:
	if SettingsManager and SettingsManager.reduced_motion:
		return
	for i: int in nodes.size():
		var node: CanvasItem = nodes[i] as CanvasItem
		if not is_instance_valid(node):
			continue
		node.scale = Vector2.ZERO
		node.modulate.a = 0.0
		node.rotation = deg_to_rad(randf_range(-4.0, 4.0))
		var tw: Tween = scene_root.create_tween().set_parallel(true)
		var d: float = float(i) * delay_per_item
		tw.tween_property(node, "scale", Vector2(1.12, 1.12), 0.2)\
			.set_delay(d).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "modulate:a", 1.0, 0.15).set_delay(d)
		tw.tween_property(node, "rotation", 0.0, 0.2)\
			.set_delay(d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(node, "scale", Vector2.ONE, 0.08)


## Jelly wobble — squash-stretch при дотику до будь-якого елемента.
## intensity 1.0 = стандартний, 0.4 = м'який (proximity), 0.6 = drop target.
static func touch_wobble(node: CanvasItem, scene_root: Node,
		intensity: float = 1.0) -> void:
	if SettingsManager and SettingsManager.reduced_motion:
		return
	if not is_instance_valid(node) or not is_instance_valid(scene_root):
		return
	var s: Vector2 = node.scale
	var tw: Tween = scene_root.create_tween()
	var m: float = intensity * 0.15
	tw.tween_property(node, "scale", s * Vector2(1.0 + m, 1.0 - m), 0.04)
	tw.tween_property(node, "scale", s * Vector2(1.0 - m * 0.6, 1.0 + m * 0.8), 0.06)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", s * Vector2(1.0 + m * 0.3, 1.0 - m * 0.3), 0.04)
	tw.tween_property(node, "scale", s * Vector2(1.0 - m * 0.1, 1.0 + m * 0.15), 0.04)
	tw.tween_property(node, "scale", s, 0.06)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Text reveal — typewriter effect через visible_ratio.
## Текст з'являється поступово з TRANS_CUBIC easing.
static func text_reveal(label: Label, text: String, scene_root: Node,
		chars_per_sec: float = 30.0) -> void:
	if not is_instance_valid(label) or not is_instance_valid(scene_root):
		return
	label.text = text
	if SettingsManager and SettingsManager.reduced_motion:
		return
	label.visible_ratio = 0.0
	var duration: float = clampf(float(text.length()) / chars_per_sec, 0.3, 1.5)
	scene_root.create_tween().tween_property(label, "visible_ratio", 1.0, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Desktop hover — subtle scale на наведення миші.
## Підключається до mouse_entered/exited, працює автоматично.
static func button_hover_scale(btn: BaseButton, scene_root: Node) -> void:
	if not is_instance_valid(btn) or not is_instance_valid(scene_root):
		return
	btn.mouse_entered.connect(func() -> void:
		if SettingsManager and SettingsManager.reduced_motion:
			return
		if not is_instance_valid(btn):
			return
		btn.pivot_offset = btn.size / 2.0
		scene_root.create_tween().tween_property(
			btn, "scale", Vector2(1.06, 1.06), 0.12)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	btn.mouse_exited.connect(func() -> void:
		if not is_instance_valid(btn):
			return
		scene_root.create_tween().tween_property(
			btn, "scale", Vector2.ONE, 0.12)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)


## Victory zoom pulse — scale 1.3 + brightness flash для перемоги/level complete.
static func victory_zoom_pulse(node: CanvasItem, scene_root: Node) -> void:
	if SettingsManager and SettingsManager.reduced_motion:
		return
	if not is_instance_valid(node) or not is_instance_valid(scene_root):
		return
	var original: Vector2 = node.scale
	var tw: Tween = scene_root.create_tween()
	tw.tween_property(node, "scale", original * 1.3, 0.12)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", original, 0.2)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	## White flash overlay
	var tw_mod: Tween = scene_root.create_tween()
	tw_mod.tween_property(node, "modulate", Color(1.35, 1.35, 1.35, 1.0), 0.06)
	tw_mod.tween_property(node, "modulate", Color.WHITE, 0.18)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Combo flash — швидкий brightness pulse для streak feedback.
static func combo_flash(node: CanvasItem, scene_root: Node) -> void:
	if SettingsManager and SettingsManager.reduced_motion:
		return
	if not is_instance_valid(node) or not is_instance_valid(scene_root):
		return
	var tw: Tween = scene_root.create_tween()
	tw.tween_property(node, "modulate", Color(1.3, 1.3, 1.3, 1.0), 0.06)
	tw.tween_property(node, "modulate", Color.WHITE, 0.12)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
