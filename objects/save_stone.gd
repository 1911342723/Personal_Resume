extends Interactable

#@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D


func interact() -> void:
	super()
	
	animated_sprite_2d.play("")
	Game.save_game()
