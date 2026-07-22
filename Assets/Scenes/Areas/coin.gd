extends Area2D

signal collected

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if body.name == "Player":
		$PickupSound.play()
		emit_signal("collected")
		# Wait for sound to finish before removing coin
		await $PickupSound.finished
		queue_free()
