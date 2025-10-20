extends Control

# UI References
@onready var sign_in_tab: Button = $AuthPanel/VBoxContainer/ModeToggle/SignInTab
@onready var sign_up_tab: Button = $AuthPanel/VBoxContainer/ModeToggle/SignUpTab
@onready var form_container: VBoxContainer = $AuthPanel/VBoxContainer/FormContainer
@onready var email_field: LineEdit = $AuthPanel/VBoxContainer/FormContainer/Email
@onready var password_field: LineEdit = $AuthPanel/VBoxContainer/FormContainer/Password
@onready var confirm_password_field: LineEdit = $AuthPanel/VBoxContainer/FormContainer/ConfirmPassword
@onready var username_field: LineEdit = $AuthPanel/VBoxContainer/FormContainer/Username
@onready var confirm_password_label: Label = $AuthPanel/VBoxContainer/FormContainer/ConfirmPasswordLabel
@onready var confirm_password_field_node: LineEdit = $AuthPanel/VBoxContainer/FormContainer/ConfirmPassword
@onready var username_label: Label = $AuthPanel/VBoxContainer/FormContainer/UsernameLabel
@onready var username_field_node: LineEdit = $AuthPanel/VBoxContainer/FormContainer/Username
@onready var error_label: Label = $AuthPanel/VBoxContainer/ErrorLabel
@onready var submit_button: Button = $AuthPanel/VBoxContainer/ButtonContainer/SubmitButton
@onready var cancel_button: Button = $AuthPanel/VBoxContainer/ButtonContainer/CancelButton
@onready var loading_label: Label = $AuthPanel/VBoxContainer/LoadingLabel

# State
var is_sign_up_mode: bool = false
var is_loading: bool = false

# Signals
signal authentication_success(user_data: Dictionary)
signal authentication_failed(error_message: String)

func _ready():
	# Connect signals
	sign_in_tab.pressed.connect(_on_sign_in_tab_pressed)
	sign_up_tab.pressed.connect(_on_sign_up_tab_pressed)
	submit_button.pressed.connect(_on_submit_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	
	# Set initial state
	_update_ui_for_mode()

func _on_sign_in_tab_pressed():
	if not is_loading:
		is_sign_up_mode = false
		_update_ui_for_mode()

func _on_sign_up_tab_pressed():
	if not is_loading:
		is_sign_up_mode = true
		_update_ui_for_mode()

func _update_ui_for_mode():
	# Update tab states
	sign_in_tab.button_pressed = not is_sign_up_mode
	sign_up_tab.button_pressed = is_sign_up_mode
	
	# Show/hide sign up specific fields
	confirm_password_label.visible = is_sign_up_mode
	confirm_password_field_node.visible = is_sign_up_mode
	username_label.visible = is_sign_up_mode
	username_field_node.visible = is_sign_up_mode
	
	# Update button text
	submit_button.text = "Sign Up" if is_sign_up_mode else "Sign In"
	
	# Clear error message
	_clear_error()

func _on_submit_pressed():
	if is_loading:
		return
		
	_clear_error()
	
	# Validate inputs
	var validation_result = _validate_inputs()
	if not validation_result.valid:
		_show_error(validation_result.message)
		return
	
	# Start authentication process
	_start_authentication()

func _validate_inputs() -> Dictionary:
	var email = email_field.text.strip_edges()
	var password = password_field.text
	var username = username_field.text.strip_edges() if is_sign_up_mode else ""
	var confirm_password = confirm_password_field.text if is_sign_up_mode else ""
	
	# Email validation
	if email.is_empty():
		return {"valid": false, "message": "Email is required"}
	
	if not _is_valid_email(email):
		return {"valid": false, "message": "Please enter a valid email address"}
	
	# Password validation
	if password.is_empty():
		return {"valid": false, "message": "Password is required"}
	
	if password.length() < 6:
		return {"valid": false, "message": "Password must be at least 6 characters long"}
	
	# Sign up specific validations
	if is_sign_up_mode:
		if username.is_empty():
			return {"valid": false, "message": "Username is required"}
		
		if username.length() < 3:
			return {"valid": false, "message": "Username must be at least 3 characters long"}
		
		if not _is_valid_username(username):
			return {"valid": false, "message": "Username can only contain letters, numbers, and underscores"}
		
		if confirm_password != password:
			return {"valid": false, "message": "Passwords do not match"}
	
	return {"valid": true, "message": ""}

func _is_valid_email(email: String) -> bool:
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
	return regex.search(email) != null

func _is_valid_username(username: String) -> bool:
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9_]+$")
	return regex.search(username) != null

func _start_authentication():
	is_loading = true
	_set_loading_state(true)
	
	# Get AWS configuration from environment
	var region = Env.get_var("COGNITO_REGION", "us-west-2")
	var user_pool_id = Env.get_var("COGNITO_USER_POOL_ID")
	var client_id = Env.get_var("COGNITO_APP_CLIENT_ID")
	
	# Display authentication status
	_show_auth_status("Starting authentication...")
	print("=== Authentication Started ===")
	print("Region: ", region)
	print("User Pool ID: ", user_pool_id)
	print("Client ID: ", client_id)
	
	if user_pool_id.is_empty() or client_id.is_empty():
		_show_error("AWS configuration not found. Please check your .env file.")
		_set_loading_state(false)
		is_loading = false
		return
	
	# Simulate authentication process (replace with actual AWS Cognito calls)
	await _simulate_authentication()

func _simulate_authentication():
	# This is a placeholder - replace with actual AWS Cognito integration
	_show_auth_status("Connecting to AWS Cognito...")
	print("Connecting to AWS Cognito...")
	await get_tree().create_timer(0.5).timeout
	
	_show_auth_status("Validating credentials...")
	print("Validating credentials...")
	await get_tree().create_timer(0.5).timeout
	
	_show_auth_status("Processing authentication...")
	print("Processing authentication...")
	await get_tree().create_timer(1.0).timeout
	
	var email = email_field.text.strip_edges()
	var password = password_field.text
	
	# Simulate success/failure
	var success = randf() > 0.3  # 70% success rate for demo
	
	if success:
		_show_auth_status("Authentication successful!")
		print("Authentication successful!")
		var user_data = {
			"email": email,
			"username": username_field.text.strip_edges() if is_sign_up_mode else email.split("@")[0],
			"authenticated": true
		}
		authentication_success.emit(user_data)
	else:
		var error_msg = "Authentication failed. Please check your credentials."
		if is_sign_up_mode:
			error_msg = "Sign up failed. Email might already be in use."
		_show_error(error_msg)
		print("Authentication failed: ", error_msg)
	
	_set_loading_state(false)
	is_loading = false

func _on_cancel_pressed():
	# Clear form
	email_field.text = ""
	password_field.text = ""
	confirm_password_field.text = ""
	username_field.text = ""
	_clear_error()
	
	# Switch to sign in mode
	is_sign_up_mode = false
	_update_ui_for_mode()

func _set_loading_state(loading: bool):
	loading_label.visible = loading
	submit_button.disabled = loading
	cancel_button.disabled = loading
	sign_in_tab.disabled = loading
	sign_up_tab.disabled = loading

func _show_error(message: String):
	error_label.text = message
	error_label.visible = true
	error_label.modulate = Color(1, 0.5, 0.5, 1)  # Red color for errors

func _show_auth_status(message: String):
	error_label.text = message
	error_label.visible = true
	error_label.modulate = Color(0.5, 0.5, 1, 1)  # Blue color for status

func _clear_error():
	error_label.text = ""
	error_label.visible = false

# Public methods for external access
func set_error(message: String):
	_show_error(message)

func clear_form():
	_on_cancel_pressed()
