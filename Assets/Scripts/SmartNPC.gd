extends CharacterBody2D

@export var npc_name = "Wise Wizard"

var player_in_range = false
var is_talking = false
var is_generating_quote = false

@onready var speech_bubble = $SpeechBubble

# Gemini API Configuration
const GEMINI_API_KEY = ""
const GEMINI_MODEL = "gemini-2.5-flash"
const GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/"

# NPC personality/context
var npc_personality = """
You are a wise wizard in a fantasy adventure game. 
You give short, mystical advice to travelers who interact with you.
Keep responses brief (10-15 words maximum).
Be mysterious but helpful.
"""

# Fallback quotes in case API fails
var fallback_quotes = [
	"The ancient magic whispers through the trees.",
	"Your path is written in the stars, traveler.",
	"Even the longest journey begins with a single step.",
	"Seek wisdom in unexpected places.",
	"Magic flows where belief follows."
]

func _ready():
	print("Gemini-powered NPC loaded: ", npc_name)
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.flip_h = true
	speech_bubble.hide_bubble()

func _process(_delta):
	if player_in_range and Input.is_action_just_pressed("interact") and not is_talking and not is_generating_quote:
		start_conversation()

func _on_interaction_area_body_entered(body):
	if body.name == "Player":
		player_in_range = true
		if not is_talking and not is_generating_quote:
			speech_bubble.show_message("Press E to talk", 2.0)

func _on_interaction_area_body_exited(body):
	if body.name == "Player":
		player_in_range = false
		if not is_talking and not is_generating_quote:
			speech_bubble.hide_bubble()

func start_conversation():
	if is_talking or is_generating_quote:
		return
	
	is_talking = true
	speech_bubble.hide_bubble()
	
	# Show thinking message
	speech_bubble.show_message("The wizard consults the stars...", 999)
	# Generate AI quote
	generate_gemini_quote()

func generate_gemini_quote():
	is_generating_quote = true
	
	# IMPORTANT: For Gemini 2.5, we need to explicitly disable thinking
	# and ensure we have enough output tokens
	var request_data = {
		"contents": [{
			"parts": [{
				"text": npc_personality + "\n\nGive me a short, mystical piece of advice for a traveler (10-15 words)."
			}]
		}],
		"generationConfig": {
			"maxOutputTokens": 100,  # Increased from 60
			"temperature": 0.8,
			"topP": 0.95,
			"topK": 40,
			"stopSequences": [],  # Explicitly empty
			"responseMimeType": "text/plain"  # Request plain text response
		},
		# Disable thinking feature for simple responses
		"systemInstruction": {
			"parts": [{
				"text": "You are a fantasy wizard. Respond concisely with only the advice, no explanations."
			}]
		}
	}
	
	# Convert to JSON
	var json_data = JSON.stringify(request_data)
	
	# Create HTTP request
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	# Connect signal
	http_request.request_completed.connect(_on_gemini_response.bind(http_request))
	
	# Make the request
	var headers = ["Content-Type: application/json"]
	var full_url = GEMINI_URL + GEMINI_MODEL + ":generateContent?key=" + GEMINI_API_KEY
	print("Making request to: ", full_url)
	print("Request data: ", json_data)
	var error = http_request.request(full_url, headers, HTTPClient.METHOD_POST, json_data)
	
	if error != OK:
		print("Error creating HTTP request: ", error)
		is_generating_quote = false
		http_request.queue_free()
		show_fallback_quote()

func _on_gemini_response(result, response_code, headers, body, http_request):
	is_generating_quote = false
	http_request.queue_free()  # Clean up
	
	print("API Response Code: ", response_code)
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("HTTP request failed. Result: ", result)
		show_fallback_quote()
		return
	
	var response_text = body.get_string_from_utf8()
	print("Raw Response: ", response_text)
	
	var json = JSON.new()
	
	if json.parse(response_text) != OK:
		print("Failed to parse JSON response")
		show_fallback_quote()
		return
	
	var response_data = json.get_data()
	
	# Check for API errors
	if response_data.has("error"):
		print("API Error: ", response_data["error"]["message"])
		show_fallback_quote()
		return
	
	# DEBUG: Print entire structure
	print("Full response structure: ", JSON.stringify(response_data))
	
	# Try to extract quote - Gemini 2.5 might have different structure
	var ai_quote = extract_quote_gemini_2_5(response_data)
	
	# If we got a quote, show it
	if ai_quote != "":
		print("Successfully extracted quote: ", ai_quote)
		show_ai_quote(ai_quote)
	else:
		print("Could not extract quote")
		print("Response keys: ", response_data.keys())
		show_fallback_quote()

func extract_quote_gemini_2_5(response_data):
	# Method 1: Standard extraction
	if response_data.has("candidates") and response_data["candidates"].size() > 0:
		var candidate = response_data["candidates"][0]
		print("Candidate keys: ", candidate.keys())
		
		if candidate.has("content"):
			var content = candidate["content"]
			print("Content keys: ", content.keys())
			
			if content.has("parts") and content["parts"].size() > 0:
				for part in content["parts"]:
					print("Part keys: ", part.keys())
					if part.has("text"):
						var text = str(part["text"]).strip_edges()
						if text != "":
							return text
	
	# Method 2: Try different path for thinking models
	if response_data.has("candidates") and response_data["candidates"].size() > 0:
		var candidate = response_data["candidates"][0]
		# Some models return text directly in candidate
		if candidate.has("text"):
			return str(candidate["text"]).strip_edges()
	
	# Method 3: Search for any text in the JSON
	var json_str = JSON.stringify(response_data)
	var regex = RegEx.new()
	regex.compile('"text":\\s*"([^"]+)"')
	var result = regex.search(json_str)
	if result:
		return result.get_string(1).strip_edges()
	
	return ""

func show_ai_quote(quote):
	# Clean up the quote
	quote = quote.replace('"', '').replace('\n', ' ').strip_edges()
	
	# Remove any thinking markers if present
	quote = quote.replace("**", "").replace("*", "")
	
	# Truncate if too long
	if quote.length() > 120:
		quote = quote.substr(0, 117) + "..."
	
	speech_bubble.show_message(quote, 4.0)
	print(">>> AI Wizard says: ", quote)
	
	await get_tree().create_timer(4.0).timeout
	end_conversation()

func show_fallback_quote():
	var random_quote = fallback_quotes[randi() % fallback_quotes.size()]
	speech_bubble.show_message(random_quote, 3.0)
	print(">>> Fallback: ", random_quote)
	
	await get_tree().create_timer(3.0).timeout
	end_conversation()

func end_conversation():
	is_talking = false
	
	if player_in_range:
		await get_tree().create_timer(0.5).timeout
		if player_in_range:
			speech_bubble.show_message("Press E to talk", 2.0)
