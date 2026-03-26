extends Node

## Менеджер переходів між сценами — circle wipe шейдер (LAW 18: GLES3).

var _overlay: ColorRect = null
var _wipe_material: ShaderMaterial = null
var _loading_label: Label = null
var _transitioning: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	_overlay = ColorRect.new()
	_overlay.color = Color.WHITE
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	## Circle wipe шейдер — premium перехід замість чорного fade
	var shader: Shader = load("res://assets/shaders/circle_wipe.gdshader") if \
		ResourceLoader.exists("res://assets/shaders/circle_wipe.gdshader") else null
	if shader:
		_wipe_material = ShaderMaterial.new()
		_wipe_material.shader = shader
		_wipe_material.set_shader_parameter("progress", 0.0)
		_wipe_material.set_shader_parameter("edge_glow_color", Color(1.0, 0.85, 0.4, 0.6))
		_wipe_material.set_shader_parameter("edge_glow_width", 0.06)
		_overlay.material = _wipe_material
		_overlay.color = Color(1, 1, 1, 1)
	else:
		## Fallback — звичайний чорний fade
		_overlay.color = Color.BLACK
		_overlay.modulate.a = 0.0
	canvas.add_child(_overlay)

	## UX-13: Індикатор завантаження
	_loading_label = Label.new()
	_loading_label.text = "..."
	_loading_label.add_theme_font_size_override("font_size", 32)
	_loading_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_loading_label.offset_left = -60.0
	_loading_label.offset_right = 60.0
	_loading_label.visible = false
	_overlay.add_child(_loading_label)


func goto_scene(path: String) -> void:
	if _transitioning:
		push_warning("SceneManager: перехід вже виконується, ігноруємо '%s'" % path)
		return
	_transitioning = true
	get_tree().paused = false  ## Завжди розпаузити перед переходом
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	## Wipe out — круг згортається до центру
	if _wipe_material:
		var fade_out: Tween = create_tween()
		fade_out.tween_method(_set_wipe_progress, 0.0, 1.0, 0.3)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await fade_out.finished
	else:
		## Fallback — звичайний fade
		var fade_out: Tween = create_tween()
		fade_out.tween_property(_overlay, "modulate:a", 1.0, 0.25)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await fade_out.finished

	_loading_label.visible = true
	if not ResourceLoader.exists(path):
		push_error("SceneManager: сцена '%s' не знайдена, скасовуємо перехід" % path)
		_loading_label.visible = false
		_reset_overlay()
		_transitioning = false
		return
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	if not is_instance_valid(_loading_label):
		return
	_loading_label.visible = false

	## Wipe in — круг розкривається від центру
	if _wipe_material:
		var fade_in: Tween = create_tween()
		fade_in.tween_method(_set_wipe_progress, 1.0, 0.0, 0.4)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await fade_in.finished
	else:
		var fade_in: Tween = create_tween()
		fade_in.tween_property(_overlay, "modulate:a", 0.0, 0.35)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await fade_in.finished

	_reset_overlay()
	_transitioning = false


func _set_wipe_progress(val: float) -> void:
	if _wipe_material:
		_wipe_material.set_shader_parameter("progress", val)


func _reset_overlay() -> void:
	if _wipe_material:
		_wipe_material.set_shader_parameter("progress", 0.0)
	else:
		_overlay.modulate.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
