extends Control

# --- UI References ---
@onready var sign_in_tab: Button = $AuthPanel/VBoxContainer/ModeToggle/SignInTab
@onready var sign_up_tab: Button = $AuthPanel/VBoxContainer/ModeToggle/SignUpTab
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
@onready var confirm_dialog: AcceptDialog = preload("uid://b8x70a02a1c3").instantiate()

# --- Components ---
var http: HTTPRequest
var cognito_client: CognitoClient

# --- State ---
var is_sign_up_mode: bool = false
var is_loading: bool = false

# --- Dialog State ---
var _current_email: String = ""
var _confirmation_result: String = ""
var _confirmation_waiting: bool = false

# --- Signals ---
signal authentication_success(user_data: Dictionary)
signal authentication_failed(error_message: String)

# =====================
# = Lifecycle / UI  ==
# =====================
func _ready():
	_setup_components()
	_setup_ui()
	_setup_testing()

func _setup_components():
	# Setup HTTP client
	http = HTTPRequest.new()
	http.request_completed.connect(_on_request_completed)
	add_child(http)
	
	# Setup Cognito client
	var region = Env.get_var("COGNITO_REGION", "us-west-2")
	var client_id = Env.get_var("COGNITO_APP_CLIENT_ID")
	cognito_client = CognitoClient.new(http, region, client_id)
	
	# Setup confirmation dialog
	add_child(confirm_dialog)
	confirm_dialog.code_confirmed.connect(_on_code_confirmed)
	confirm_dialog.dialog_cancelled.connect(_on_dialog_cancelled)
	confirm_dialog.resend_requested.connect(_on_resend_requested)

func _setup_ui():
	# Connect UI signals
	sign_in_tab.pressed.connect(_on_sign_in_tab_pressed)
	sign_up_tab.pressed.connect(_on_sign_up_tab_pressed)
	submit_button.pressed.connect(_on_submit_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	_update_ui_for_mode()

func _setup_testing():
	# Default values for testing
	email_field.text = "vltndev@gmail.com"
	password_field.text = "VlTn1234!"
	confirm_password_field.text = "VlTn1234!"
	username_field.text = "vall"
	
	# For testing: switch to sign-in mode since user already exists
	is_sign_up_mode = false
	print("=== Testing Mode: Switched to Sign In (user already exists) ===")

func _on_sign_in_tab_pressed():
	if not is_loading:
		is_sign_up_mode = false
		_update_ui_for_mode()

func _on_sign_up_tab_pressed():
	if not is_loading:
		is_sign_up_mode = true
		_update_ui_for_mode()

func _update_ui_for_mode():
	sign_in_tab.button_pressed = not is_sign_up_mode
	sign_up_tab.button_pressed = is_sign_up_mode

	confirm_password_label.visible = is_sign_up_mode
	confirm_password_field_node.visible = is_sign_up_mode
	username_label.visible = is_sign_up_mode
	username_field_node.visible = is_sign_up_mode

	submit_button.text = "Sign Up" if is_sign_up_mode else "Sign In"
	_clear_error()

# =====================
# = Submit / Validate =
# =====================
func _on_submit_pressed():
	if is_loading: return
	_clear_error()

	var validation_result = _validate_inputs()
	if not validation_result.valid:
		_show_error(validation_result.message)
		return

	await _start_authentication()

func _validate_inputs() -> Dictionary:
	var email = email_field.text.strip_edges()
	var password = password_field.text
	var username = username_field.text.strip_edges() if is_sign_up_mode else ""
	var confirm_password = confirm_password_field.text if is_sign_up_mode else ""

	if is_sign_up_mode:
		return ValidationUtils.validate_signup(email, password, username, confirm_password)
	else:
		return ValidationUtils.validate_signin(email, password)

# =====================
# = Auth (real calls) =
# =====================
func _start_authentication() -> void:
	_set_loading_state(true)
	
	if is_sign_up_mode:
		await _handle_signup()
	else:
		await _handle_signin()
	
	_set_loading_state(false)

func _handle_signup():
	var email = email_field.text.strip_edges()
	var password = password_field.text
	var username = username_field.text.strip_edges()

	_show_auth_status("Creating account…")
	var res = await cognito_client.sign_up(email, password, username)
	
	if res.get("__error__", false):
		_show_error(ErrorHandler.get_friendly_error(res))
		authentication_failed.emit(error_label.text)
		return

	# Handle email confirmation
	_show_auth_status("Please check your email for the verification code.")
	var code = await _prompt_confirm_code(email)
	if code == "":
		_show_error("Email confirmation cancelled. Please check your email and use the Sign In tab to confirm later.")
		is_sign_up_mode = false
		_update_ui_for_mode()
		authentication_failed.emit("Email confirmation cancelled")
		return

	_show_auth_status("Confirming…")
	var conf = await cognito_client.confirm_sign_up(email, code)
	
	if conf.get("__error__", false):
		_show_error(ErrorHandler.get_friendly_error(conf))
		authentication_failed.emit(error_label.text)
		return

	_show_auth_status("Email confirmed. Signing you in…")
	await _handle_signin()

func _handle_signin():
	var email = email_field.text.strip_edges()
	var password = password_field.text

	_show_auth_status("Signing in…")
	var res = await cognito_client.sign_in(email, password)

	# Handle unconfirmed user
	if res.get("__error__", false):
		var typ = str(res.get("raw", {}).get("__type", ""))
		if typ.findn("UserNotConfirmedException") != -1:
			_show_auth_status("Your email is not confirmed. Please enter the code.")
			var code = await _prompt_confirm_code(email)
			if code == "":
				_show_error("Email not confirmed.")
				authentication_failed.emit(error_label.text)
				return
			
			var conf = await cognito_client.confirm_sign_up(email, code)
			if conf.get("__error__", false):
				_show_error(ErrorHandler.get_friendly_error(conf))
				authentication_failed.emit(error_label.text)
				return
			
			# Retry login after confirmation
			res = await cognito_client.sign_in(email, password)

	# Handle other errors
	if res.get("__error__", false):
		_show_error(ErrorHandler.get_friendly_error(res))
		authentication_failed.emit(error_label.text)
		return

	# Handle challenges
	if res.has("ChallengeName"):
		_show_error("Challenge required: %s" % res["ChallengeName"])
		authentication_failed.emit(error_label.text)
		return

	# Extract tokens
	var auth: Dictionary = res.get("AuthenticationResult", {})
	var id_token: String = auth.get("IdToken", "")
	var access_token: String = auth.get("AccessToken", "")
	var refresh_token: String = auth.get("RefreshToken", "")
	
	if id_token == "":
		_show_error("Login failed: empty token.")
		authentication_failed.emit(error_label.text)
		return

	_show_auth_status("Success!")
	authentication_success.emit({
		"email": email,
		"username": username_field.text.strip_edges() if is_sign_up_mode else email.split("@")[0],
		"id_token": id_token,
		"access_token": access_token,
		"refresh_token": refresh_token
	})

# =====================
# = Dialog Handling  =
# =====================

func _prompt_confirm_code(email: String) -> String:
	_current_email = email
	_confirmation_result = ""
	_confirmation_waiting = true
	
	confirm_dialog.show_dialog(email)
	
	while _confirmation_waiting:
		await get_tree().process_frame
	
	return _confirmation_result

func _on_code_confirmed(code: String):
	_confirmation_result = code
	_confirmation_waiting = false

func _on_dialog_cancelled():
	_confirmation_result = ""
	_confirmation_waiting = false

func _on_resend_requested():
	_show_auth_status("Resending code…")
	var r = await cognito_client.resend_confirmation_code(_current_email)
	if r.get("__error__", false):
		_show_error(ErrorHandler.get_friendly_error(r))
	else:
		_show_auth_status("Verification code sent.")

# =====================
# = UI Helpers        =
# =====================
func _on_cancel_pressed():
	email_field.text = ""
	password_field.text = ""
	confirm_password_field.text = ""
	username_field.text = ""
	_clear_error()
	is_sign_up_mode = false
	_update_ui_for_mode()

func _set_loading_state(loading: bool):
	is_loading = loading
	loading_label.visible = loading
	submit_button.disabled = loading
	cancel_button.disabled = loading
	sign_in_tab.disabled = loading
	sign_up_tab.disabled = loading

func _show_error(message: String):
	error_label.text = message
	error_label.visible = true
	error_label.modulate = Color(1, 0.5, 0.5, 1)

func _show_auth_status(message: String):
	error_label.text = message
	error_label.visible = true
	error_label.modulate = Color(0.5, 0.5, 1, 1)

func _clear_error():
	error_label.text = ""
	error_label.visible = false

func _on_request_completed(_result, _response_code, _headers, _body): 
	pass  # Handled by CognitoClient
