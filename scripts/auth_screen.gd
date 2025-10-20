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

	# Set default values for testing
	_set_default_values()
	_update_ui_for_mode()

func _set_default_values():
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

# -------- Sign Up with Email Confirmation --------
func _do_signup_and_optional_confirm(region: String, client_id: String) -> void:
	var email := email_field.text.strip_edges()
	var password := password_field.text
	var username := username_field.text.strip_edges()

	_show_auth_status("Creating account…")
	print("=== Sign Up Request ===")
	print("Email: ", email)
	print("Username: ", username)
	print("Client ID: ", client_id)
	
	var res := await _cognito_call(region, "SignUp", {
		"ClientId": client_id,
		"Username": email,
		"Password": password,
		"UserAttributes": [
			{"Name": "email", "Value": email},
			{"Name": "preferred_username", "Value": username}
		]
	})
	
	print("Sign Up response: ", res)
	
	if res.get("__error__", false):
		_show_error(_friendly_cognito_error(res))
		authentication_failed.emit(error_label.text)
		return

	# Ask for code immediately (since your pool requires confirmation)
	_show_auth_status("Please check your email for the verification code.")
	
	while true:
		var code := await _prompt_confirm_code(email, region, client_id)
		if code == "":
			# User cancelled the dialog - show helpful message and switch to sign in
			_show_error("Email confirmation cancelled. Please check your email and use the Sign In tab to confirm later.")
			is_sign_up_mode = false
			_update_ui_for_mode()
			authentication_failed.emit("Email confirmation cancelled")
			return
			
		_show_auth_status("Confirming…")
		print("=== Confirming Sign Up ===")
		print("Email: ", email)
		print("Code: ", code)
		print("Client ID: ", client_id)
		print("Region: ", region)
		
		var conf := await _cognito_call(region, "ConfirmSignUp", {
			"ClientId": client_id,
			"Username": email,
			"ConfirmationCode": code
		})
		
		print("Confirmation response: ", conf)
		print("Has error: ", conf.get("__error__", false))
		
		if conf.get("__error__", false):
			var error_msg = _friendly_cognito_error(conf)
			print("Error message: ", error_msg)
			_show_error(error_msg)
			continue  # let user try again or resend
		else:
			# Success! Break out of the loop
			print("Email confirmed successfully!")
			print("Breaking out of confirmation loop")
			break

	_show_auth_status("Email confirmed. Signing you in…")
	await _do_login(region, client_id)  # proceed

# ---------------------------- Sign In with Unconfirmed User Handling --------
func _do_login(region: String, client_id: String) -> void:
	var email := email_field.text.strip_edges()
	var password := password_field.text

	_show_auth_status("Signing in…")
	var res := await _cognito_call(region, "InitiateAuth", {
		"AuthFlow": "USER_PASSWORD_AUTH",
		"ClientId": client_id,
		"AuthParameters": {
			"USERNAME": email,
			"PASSWORD": password
		}
	})

	# If user not confirmed, run confirmation flow and retry login
	if res.get("__error__", false):
		var typ := str(res.get("raw", {}).get("__type", ""))
		if typ.findn("UserNotConfirmedException") != -1:
			_show_auth_status("Your email is not confirmed. Please enter the code.")
			while true:
				var code := await _prompt_confirm_code(email, region, client_id)
				if code == "":
					_show_error("Email not confirmed.")
					authentication_failed.emit(error_label.text)
					return
				var conf := await _cognito_call(region, "ConfirmSignUp", {
					"ClientId": client_id,
					"Username": email,
					"ConfirmationCode": code
				})
				if conf.get("__error__", false):
					_show_error(_friendly_cognito_error(conf))
					continue
				break
			# try login again after successful confirm
			res = await _cognito_call(region, "InitiateAuth", {
				"AuthFlow": "USER_PASSWORD_AUTH",
				"ClientId": client_id,
				"AuthParameters": {
					"USERNAME": email,
					"PASSWORD": password
				}
			})
	# If still error (not due to confirmation), fail out
	if res.get("__error__", false):
		var msg = _friendly_cognito_error(res)
		_show_error(msg)
		authentication_failed.emit(msg)
		return

	# Challenges (MFA/NEW_PASSWORD_REQUIRED) can be handled here if you enable them
	if res.has("ChallengeName"):
		_show_error("Challenge required: %s" % res["ChallengeName"])
		authentication_failed.emit(error_label.text)
		return

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
	if typ.findn("LimitExceededException") != -1:
		return "Too many attempts. Please wait a few minutes before trying again."
	return (msg if msg != "" else "Authentication error (%s)" % typ)

# =====================
# = Email Confirmation Modal =
# =====================
# Show a modal asking for the confirmation code. Returns code (String) or "" if canceled.
func _prompt_confirm_code(email: String, region: String, client_id: String) -> String:
	var dlg := AcceptDialog.new()
	dlg.title = "Confirm your email"
	dlg.size = Vector2(400, 200)
	dlg.min_size = Vector2(400, 200)
	dlg.max_size = Vector2(400, 200)

	# Layout
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 10)
	
	var lbl := Label.new()
	lbl.text = "Enter the verification code sent to:\n" + email
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var code := LineEdit.new()
	code.placeholder_text = "Enter 6-digit code here"
	code.max_length = 12
	code.text = ""
	code.custom_minimum_size = Vector2(200, 30)
	
	box.add_child(lbl)
	box.add_child(code)
	dlg.add_child(box)

	# Buttons: OK + Resend
	dlg.get_ok_button().text = "Confirm"
	dlg.add_button("Resend code", false, "resend")
	
	# Handle resend button
	dlg.custom_action.connect(func(action):
		if action == "resend":
			_show_auth_status("Resending code…")
			var r := await _cognito_call(region, "ResendConfirmationCode", {
				"ClientId": client_id,
				"Username": email
			})
			if r.get("__error__", false):
				_show_error(_friendly_cognito_error(r))
			else:
				_show_auth_status("Verification code sent.")
	)

	add_child(dlg)
	dlg.popup_centered(Vector2i(400, 200))
	dlg.move_to_foreground()
	await get_tree().process_frame
	code.grab_focus()

	print("=== Dialog opened, waiting for user input ===")
	
	# Use a different approach - wait for the dialog to be closed
	var result = ""
	var dialog_closed = false
	
	# Connect to the confirmed signal properly
	dlg.confirmed.connect(func():
		result = code.text.strip_edges()
		dialog_closed = true
		print("=== Dialog confirmed ===")
		print("Code entered: ", result)
	)
	
	# Also handle dialog close
	dlg.close_requested.connect(func():
		dialog_closed = true
		print("=== Dialog closed without confirm ===")
	)
	
	# Wait for dialog to be closed
	while not dialog_closed:
		await get_tree().process_frame
	
	dlg.queue_free()
	return result

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
