# SpeechBubble.gd - Enhanced with better debug
extends Node2D

@onready var label = $Label
@onready var background = $Background
@onready var timer = $Timer

func _ready():
	# Force black text and visible background
	label.modulate = Color.BLACK
	background.color = Color.WHITE
	hide_bubble()
	print("SpeechBubble ready - Label visible: ", label.visible)

func show_message(text: String, duration: float = 3.0):
	print("SpeechBubble showing text: '", text, "'")
	
	# Set text and make sure it's visible
	label.text = text
	label.visible = true
	background.visible = true
	
	# Wait a frame for label to calculate size
	await get_tree().process_frame
	
	# Adjust size to fit text
	var text_size = label.get_minimum_size()
	print("Text size: ", text_size)
	background.size = text_size + Vector2(40, 20)  # Add padding
	label.size = text_size
	
	# Center label on background
	label.position = Vector2(20, 10)
	
	show()
	timer.wait_time = duration
	timer.start()

func hide_bubble():
	hide()
	print("SpeechBubble hidden")

func _on_timer_timeout():
	hide_bubble()
