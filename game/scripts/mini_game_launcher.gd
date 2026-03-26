class_name MiniGameLauncher
extends RefCounted

## Launches the food mini-game and handles cleanup when it finishes.
##
## Usage from parent app:
##   var instance: Node2D = MiniGameLauncher.launch_food_game(self)
##   # Optionally connect to instance.finished for custom logic

const FOOD_GAME_SCENE: PackedScene = preload("res://scenes/main/food_game.tscn")
const CLEANUP_DELAY: float = 2.0


static func launch_food_game(parent_node: Node) -> Node2D:
	if not parent_node or not parent_node.is_inside_tree():
		push_error("MiniGameLauncher: parent_node is null or not in tree")
		return null

	var instance: Node2D = FOOD_GAME_SCENE.instantiate()
	parent_node.add_child(instance)

	instance.finished.connect(func(_stats: Dictionary) -> void:
		instance.get_tree().create_timer(CLEANUP_DELAY).timeout.connect(instance.queue_free)
	)

	return instance
