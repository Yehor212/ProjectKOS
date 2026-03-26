@tool
extends EditorScript

## Одноразовий скрипт: конвертує Sprite2D .tscn у AnimatedSprite2D
## якщо існує відповідний *_idle.png спрайт-шит.
## Запуск: Script → Run в Godot Editor.


func _run() -> void:
	var converted: int = 0
	var skipped: int = 0

	for pair: Dictionary in GameData.ANIMALS_AND_FOOD:
		var animal_name: String = pair.name
		var strip_path: String = "res://assets/sprites/animals/%s_idle.png" % animal_name

		if not ResourceLoader.exists(strip_path):
			print("[SKIP] %s -- no sprite strip found" % animal_name)
			skipped += 1
			continue

		var frames: SpriteFrames = GameData.create_sprite_frames_from_strip(strip_path)
		if not frames:
			print("[ERR] %s — не вдалося створити SpriteFrames" % animal_name)
			skipped += 1
			continue

		var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
		sprite.name = animal_name
		sprite.sprite_frames = frames
		sprite.scale = Vector2(0.45, 0.45)
		sprite.play("idle")

		var scene: PackedScene = PackedScene.new()
		scene.pack(sprite)

		var save_path: String = "res://scenes/animals/%s.tscn" % animal_name
		var err: Error = ResourceSaver.save(scene, save_path)
		if err == OK:
			print("[OK] %s -> AnimatedSprite2D" % animal_name)
			converted += 1
		else:
			print("[ERR] %s -- save error: %d" % [animal_name, err])
			skipped += 1

		sprite.queue_free()

	print("\nГотово! Конвертовано: %d, Пропущено: %d" % [converted, skipped])
