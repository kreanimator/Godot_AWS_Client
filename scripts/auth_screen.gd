extends Control

# --- UI refs (unchanged) ---
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

# --- Networking ---
var http: HTTPRequest

# --- State ---
var is_sign_up_mode: bool = false
var is_loading: bool = false

# --- Signals ---
signal authentication_success(user_data: Dictionary)
signal authentication_failed(error_message: String)

# =====================
# = Lifecycle / UI  ==
# =====================
func _ready():
	# Make sure we have an HTTPRequest child
	http = HTTPRequest.new()
	http.request_completed.connect(_on_request_completed) # not used directly, we await per-call
	add_child(http)

	# Connect signals
	sign_in_tab.pressed.connect(_on_sign_in_tab_pressed)
	sign_up_tab.pressed.connect(_on_sign_up_tab_pressed)
	submit_button.pressed.connect(_on_submit_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

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

	if email.is_empty():
		return {"valid": false, "message": "Email is required"}
	if not _is_valid_email(email):
		return {"valid": false, "message": "Please enter a valid email address"}
	if password.is_empty():
		return {"valid": false, "message": "Password is required"}
	if password.length() < 6:
		return {"valid": false, "message": "Password must be at least 6 characters long"}

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

# =====================
# = Auth (real calls) =
# =====================
func _start_authentication() -> void:
	is_loading = true
	_set_loading_state(true)

	var region = Env.get_var("COGNITO_REGION", "eu-west-1")
	var user_pool_id = Env.get_var("COGNITO_USER_POOL_ID")
	var client_id = Env.get_var("COGNITO_APP_CLIENT_ID")

	if user_pool_id.is_empty() or client_id.is_empty():
		_show_error("AWS config missing. Check .env (USER_POOL_ID / APP_CLIENT_ID).")
		_set_loading_state(false)
		is_loading = false
		return

	if is_sign_up_mode:
		await _do_signup_and_optional_confirm(region, client_id)
	else:
		await _do_login(region, client_id)

	_set_loading_state(false)
	is_loading = false

# -------- Sign Up (+ optional immediate confirm if you add code UI) --------
func _do_signup_and_optional_confirm(region: String, client_id: String) -> void:
	var email := email_field.text.strip_edges()
	var password := password_field.text
	var username := username_field.text.strip_edges()

	_show_auth_status("Creating account…")
	var res = await _cognito_call(region, "SignUp", {
		"ClientId": client_id,
		"Username": email,           # using email as username
		"Password": password,
		"UserAttributes": [
			{"Name": "email", "Value": email},
			{"Name": "preferred_username", "Value": username}
		]
	})

	if res.get("__error__", false):
		_show_error(_friendly_cognito_error(res))
		authentication_failed.emit(error_label.text)
		return

	# If your pool requires email confirmation, Cognito sends a code.
	# OPTIONAL: if you add a field for the confirmation code, confirm here.
	# Example (uncomment if you add a code input called confirm_code_field):
	# var code = confirm_code_field.text.strip_edges()
	# if code != "":
	#     _show_auth_status("Confirming email…")
	#     var conf = await _cognito_call(region, "ConfirmSignUp", {
	#         "ClientId": client_id,
	#         "Username": email,
	#         "ConfirmationCode": code
	#     })
	#     if conf.get("__error__", false):
	#         _show_error(_friendly_cognito_error(conf))
	#         authentication_failed.emit(error_label.text)
	#         return

	_show_auth_status("Account created. Signing you in…")
	await _do_login(region, client_id)  # attempt immediate login

# ---------------------------- Sign In --------------------------------------
func _do_login(region: String, client_id: String) -> void:
	var email := email_field.text.strip_edges()
	var password := password_field.text

	_show_auth_status("Signing in…")
	var res = await _cognito_call(region, "InitiateAuth", {
		"AuthFlow": "USER_PASSWORD_AUTH",
		"ClientId": client_id,
		"AuthParameters": {
			"USERNAME": email,
			"PASSWORD": password
		}
	})

	if res.get("__error__", false):
		var msg = _friendly_cognito_error(res)
		_show_error(msg)
		authentication_failed.emit(msg)
		return

	# Handle challenges (MFA / NEW_PASSWORD_REQUIRED) if your pool enforces them.
	if res.has("ChallengeName"):
		_show_error("Challenge required: %s" % res["ChallengeName"])
		authentication_failed.emit(error_label.text)
		return

	var auth = res.get("AuthenticationResult", {})
	var id_token = auth.get("IdToken", "")
	var access_token = auth.get("AccessToken", "")
	var refresh_token = auth.get("RefreshToken", "")

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

# ======================
# = Low-level Cognito  =
# ======================
func _cognito_call(region: String, target: String, body: Dictionary) -> Dictionary:
	var url: String = "https://cognito-idp.%s.amazonaws.com/" % region
	var headers: PackedStringArray = [
		"Content-Type: application/x-amz-json-1.1",
		"X-Amz-Target: AWSCognitoIdentityProviderService.%s" % target
	]

	var err: int = http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		return {
			"__error__": true,
			"status_code": -1,
			"raw": {"__type": "ClientError", "message": "HTTPRequest error %s" % err}
		}

	# Godot 4: await returns [result (int), response_code (int), headers (PackedStringArray), body (PackedByteArray)]
	var resp: Array = await http.request_completed
	var result_code: int = int(resp[0])
	var response_code: int = int(resp[1])
	var resp_headers: PackedStringArray = resp[2]
	var raw_body: PackedByteArray = resp[3]
	var txt: String = raw_body.get_string_from_utf8()

	# --- success path ---
	if response_code >= 200 and response_code < 300:
		if txt == "":
			return {}
		var parsed: Variant = JSON.parse_string(txt)
		if typeof(parsed) == TYPE_DICTIONARY:
			return parsed as Dictionary
		else:
			# ensure Dictionary return type even if service returns non-dict JSON
			var wrap: Dictionary = {"raw": parsed}
			return wrap

	# --- error path ---
	var obj: Dictionary = {}
	if txt != "":
		var parsed_err: Variant = JSON.parse_string(txt)
		if typeof(parsed_err) == TYPE_DICTIONARY:
			obj = parsed_err as Dictionary
		else:
			obj = {"raw_text": txt}
	return {"__error__": true, "status_code": response_code, "raw": obj, "result": result_code}




func _friendly_cognito_error(res: Dictionary) -> String:
	var typ = str(res.get("raw", {}).get("__type", ""))
	var msg = str(res.get("raw", {}).get("message", ""))
	# Some common friendly mappings
	if typ.findn("UserNotConfirmedException") != -1:
		return "Your email is not confirmed yet. Check your inbox for the verification code."
	if typ.findn("NotAuthorizedException") != -1:
		return "Incorrect email or password."
	if typ.findn("UsernameExistsException") != -1:
		return "An account with this email already exists."
	if typ.findn("CodeMismatchException") != -1:
		return "Invalid confirmation code."
	if typ.findn("ExpiredCodeException") != -1:
		return "Confirmation code expired. Request a new one."
	return (msg if msg != "" else "Authentication error (%s)" % typ)

# =====================
# = Cancel / Helpers  =
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

# (optional) connected but unused; kept to avoid warnings
func _on_request_completed(_result, _response_code, _headers, _body): pass
