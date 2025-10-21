extends Control

# --- UI References ---
@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var profile_button: Button = $VBoxContainer/ProfileButton
@onready var logout_button: Button = $VBoxContainer/LogoutButton

# --- User Info Panel References ---
@onready var user_display_name: Label = $UserInfoPanel/UserInfoVBox/UserDisplayName
@onready var user_id_label: Label = $UserInfoPanel/UserInfoVBox/UserIDLabel
@onready var user_email_label: Label = $UserInfoPanel/UserInfoVBox/UserEmailLabel

# --- Signals ---
# (No signals needed - handling scene transition directly)

# =====================
# = Lifecycle         =
# =====================
func _ready():
	_setup_ui()
	_connect_signals()
	
	# Debug: Check if nodes are found
	print("=== Main Menu Node Debug ===")
	print("user_display_name: ", user_display_name)
	print("user_id_label: ", user_id_label)
	print("user_email_label: ", user_email_label)
	
	_update_user_display_from_session()

func _setup_ui():
	# Set up button styling
	play_button.custom_minimum_size = Vector2(200, 40)
	settings_button.custom_minimum_size = Vector2(200, 40)
	profile_button.custom_minimum_size = Vector2(200, 40)
	logout_button.custom_minimum_size = Vector2(200, 40)

func _connect_signals():
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	profile_button.pressed.connect(_on_profile_pressed)
	logout_button.pressed.connect(_on_logout_pressed)

# =====================
# = Public Methods   =
# =====================
func set_user_data(data: Dictionary):
	# This method is kept for compatibility but now uses global session
	UserSession.set_user_data(data)
	_update_user_display_from_session()

func _update_user_display_from_session():
	# Update user info panel in top right (with safety checks)
	if user_display_name:
		user_display_name.text = "Welcome, %s!" % UserSession.get_user_display_name()
	else:
		print("Warning: user_display_name not found")
	
	if user_id_label:
		user_id_label.text = "ID: %s" % UserSession.user_id
	else:
		print("Warning: user_id_label not found")
	
	if user_email_label:
		user_email_label.text = "Email: %s" % UserSession.email
	else:
		print("Warning: user_email_label not found")
	
	# Debug: Print session info
	print("=== Main Menu User Display ===")
	print("Display Name: ", UserSession.get_user_display_name())
	print("User ID: ", UserSession.user_id)
	print("Username: ", UserSession.username)
	print("Email: ", UserSession.email)
	print("Is Logged In: ", UserSession.is_logged_in)

# =====================
# = Button Handlers  =
# =====================
func _on_play_pressed():
	print("Play button pressed - Game functionality not implemented yet")
	# TODO: Implement game start logic
	# get_tree().change_scene_to_file("res://scenes/game/game_scene.tscn")

func _on_settings_pressed():
	print("Settings button pressed - Settings functionality not implemented yet")
	# TODO: Implement settings dialog
	# _show_settings_dialog()

func _on_profile_pressed():
	print("Profile button pressed - Profile functionality not implemented yet")
	# TODO: Implement profile view
	# _show_profile_dialog()

func _on_logout_pressed():
	print("Logout requested")
	# Call Cognito GlobalSignOut API to invalidate tokens on server
	await _perform_cognito_logout()
	# Clear the global session
	UserSession.clear_session()
	# Switch back to auth screen
	_switch_to_auth_screen()

# =====================
# = Cognito Logout    =
# =====================
func _perform_cognito_logout():
	if not UserSession.is_logged_in:
		print("No active session to logout from")
		return
	
	if UserSession.access_token == "":
		print("No access token available for logout")
		return
	
	print("Performing Cognito GlobalSignOut...")
	
	# Create a temporary CognitoClient for logout
	var region = Env.get_var("COGNITO_REGION", "us-west-2")
	var client_id = Env.get_var("COGNITO_APP_CLIENT_ID")
	
	if client_id.is_empty():
		print("Warning: No Cognito client ID found for logout")
		return
	
	# Create HTTP request for logout
	var http = HTTPRequest.new()
	add_child(http)
	
	var cognito_client = CognitoClient.new(http, region, client_id)
	var result = await cognito_client.global_sign_out(UserSession.access_token)
	
	# Clean up HTTP request
	http.queue_free()
	
	if result.get("__error__", false):
		print("Cognito logout failed: ", ErrorHandler.get_friendly_error(result))
		# Continue with local logout even if server logout fails
	else:
		print("Successfully logged out from Cognito server")

# =====================
# = Scene Management  =
# =====================
func _switch_to_auth_screen():
	print("Switching back to auth screen...")
	get_tree().change_scene_to_file("res://scenes/UI/auth_screen.tscn")

# =====================
# = Future Features  =
# =====================
# These methods can be implemented later for additional functionality

func _show_settings_dialog():
	# TODO: Create settings dialog
	pass

func _show_profile_dialog():
	# TODO: Create profile dialog showing user info
	pass

func _start_game():
	# TODO: Implement game start logic
	pass
