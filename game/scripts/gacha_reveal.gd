extends CanvasLayer

## Оверлей розкриття гача — показує нову тваринку з фанфарами.

signal reveal_closed


func _ready() -> void:
	## Grain overlay на gacha reveal (LAW 28)
	$Overlay.material = GameData.create_premium_material(0.02, 2.0, 0.04, 0.08, 0.04, 0.05, 0.12, "", 0.0, 0.08, 0.18, 0.15)
	## Juicy button squish
	JuicyEffects.button_press_squish($ContinueButton, self)

const REVEAL_DURATION: float = 0.8
const SPIN_DURATION: float = 0.5

var _animal_name: String = ""


func reveal_animal(animal_name: String) -> void:
	_animal_name = animal_name
	## Завантажити текстуру тварини
	var tex_path: String = "res://assets/sprites/animals/%s.png" % animal_name
	if ResourceLoader.exists(tex_path):
		$AnimalSprite.texture = load(tex_path)
	else:
		push_warning("GachaReveal: текстура '%s' не знайдена" % tex_path)
	## Ім'я тварини через переклад
	$NameLabel.text = tr("MSG_UNLOCKED") % animal_name
	## Кнопка «Далі»
	var cont_btn: Button = $ContinueButton
	cont_btn.text = tr("BTN_CONTINUE")
	cont_btn.disabled = true
	cont_btn.modulate.a = 0.0
	## Запуск анімації
	_animate_reveal()


func _animate_reveal() -> void:
	## Затемнення фону
	$Overlay.modulate.a = 0.0
	var tw: Tween = create_tween()
	tw.tween_property($Overlay, "modulate:a", 1.0, 0.3)

	## Тваринка: масштаб з нуля + обертання
	$AnimalSprite.pivot_offset = $AnimalSprite.size / 2.0
	$AnimalSprite.scale = Vector2.ZERO
	$AnimalSprite.modulate.a = 0.0
	tw.tween_property($AnimalSprite, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property($AnimalSprite, "scale", Vector2(1.2, 1.2),
		REVEAL_DURATION).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property($AnimalSprite, "rotation", TAU,
		SPIN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property($AnimalSprite, "scale", Vector2.ONE, 0.15)

	## Lightburst — плавна поява + повільне обертання
	tw.parallel().tween_property($Lightburst, "modulate:a", 0.6, 0.4)
	var spin_tw: Tween = create_tween().set_loops()
	$Lightburst.pivot_offset = $Lightburst.size / 2.0
	spin_tw.tween_property($Lightburst, "rotation", TAU, 8.0)

	## Ім'я — плавна поява
	$NameLabel.modulate.a = 0.0
	tw.tween_property($NameLabel, "modulate:a", 1.0, 0.3)

	## Звук розблокування + конфетті + блиск
	tw.tween_callback(func() -> void:
		AudioManager.play_sfx("success")
		HapticsManager.vibrate_success()
		var center: Vector2 = $AnimalSprite.global_position + $AnimalSprite.size / 2.0
		VFXManager.spawn_premium_celebration(center)
	)

	## Кнопка «Далі» — затримана поява
	tw.tween_interval(1.0)
	tw.tween_property($ContinueButton, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func() -> void: $ContinueButton.disabled = false)


func _on_continue_pressed() -> void:
	AudioManager.play_sfx("click")
	reveal_closed.emit()
	queue_free()
