extends Node

# --- User Data Storage ---
var user_id: String = ""
var username: String = ""
var email: String = ""
var id_token: String = ""
var access_token: String = ""
var refresh_token: String = ""

# --- Session State ---
var is_logged_in: bool = false

# --- Signals ---
signal user_logged_in(user_data: Dictionary)
signal user_logged_out()

# =====================
# = Session Management =
# =====================
func set_user_data(user_data: Dictionary):
	user_id = user_data.get("user_id", "")
	username = user_data.get("username", "")
	email = user_data.get("email", "")
	id_token = user_data.get("id_token", "")
	access_token = user_data.get("access_token", "")
	refresh_token = user_data.get("refresh_token", "")
	
	is_logged_in = true
	
	# Debug: Print user data
	print("=== User Session Data ===")
	print("User ID: ", user_id)
	print("Username: ", username)
	print("Email: ", email)
	print("ID Token (first 30 chars): ", id_token.substr(0, 30) + "..." if id_token.length() > 30 else id_token)
	print("Access Token (first 30 chars): ", access_token.substr(0, 30) + "..." if access_token.length() > 30 else access_token)
	print("Refresh Token (first 30 chars): ", refresh_token.substr(0, 30) + "..." if refresh_token.length() > 30 else refresh_token)
	print("Is Logged In: ", is_logged_in)
	
	user_logged_in.emit(user_data)

func clear_session():
	user_id = ""
	username = ""
	email = ""
	id_token = ""
	access_token = ""
	refresh_token = ""
	is_logged_in = false
	
	print("=== User Session Cleared ===")
	user_logged_out.emit()

func get_user_display_name() -> String:
	if username != "":
		return username
	elif email != "":
		return email.split("@")[0]
	else:
		return "User"

func get_user_info() -> Dictionary:
	return {
		"user_id": user_id,
		"username": username,
		"email": email,
		"is_logged_in": is_logged_in
	}
