extends AcceptDialog
class_name PasswordResetDialog

# --- UI References ---
@onready var email_label: Label = $VBoxContainer/EmailLabel
@onready var code_field: LineEdit = $VBoxContainer/CodeField
@onready var new_password_field: LineEdit = $VBoxContainer/NewPasswordField
@onready var confirm_password_field: LineEdit = $VBoxContainer/ConfirmPasswordField

# --- Signals ---
signal password_reset_requested(email: String, code: String, new_password: String)
signal dialog_cancelled()

# --- State ---
var _email: String = ""

func _ready():
	# Setup buttons
	get_ok_button().text = "🔑 Reset Password"
	add_button("Cancel", false, "cancel")
	
	# Connect signals
	confirmed.connect(_on_confirmed)
	close_requested.connect(_on_cancelled)
	custom_action.connect(_on_custom_action)

func show_dialog(email: String):
	_email = email
	email_label.text = "Email: " + email
	code_field.text = ""
	new_password_field.text = ""
	confirm_password_field.text = ""
	
	# Set explicit size to prevent stretching
	size = Vector2i(400, 300)
	min_size = Vector2i(400, 300)
	max_size = Vector2i(400, 300)
	
	popup_centered()
	grab_focus()
	code_field.grab_focus()

func _on_confirmed():
	var code = code_field.text.strip_edges()
	var new_password = new_password_field.text
	var confirm_password = confirm_password_field.text
	
	# Validate inputs
	if code.is_empty() or new_password.is_empty():
		_show_error("Please fill in all fields")
		return
	
	if new_password != confirm_password:
		_show_error("Passwords do not match")
		return
	
	if new_password.length() < 6:
		_show_error("Password must be at least 6 characters long")
		return
	
	# Emit signal with validated data
	password_reset_requested.emit(_email, code, new_password)

func _on_cancelled():
	dialog_cancelled.emit()

func _on_custom_action(action: String):
	if action == "cancel":
		dialog_cancelled.emit()

func _show_error(message: String):
	# Simple error display - could be enhanced with a proper error label
	print("Password Reset Error: ", message)
	# For now, just show in console - could add error label to UI
