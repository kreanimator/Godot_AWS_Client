extends RefCounted
class_name ValidationUtils

# Email validation
static func is_valid_email(email: String) -> bool:
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
	return regex.search(email) != null

# Username validation
static func is_valid_username(username: String) -> bool:
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9_]+$")
	return regex.search(username) != null

# Validate sign up inputs
static func validate_signup(email: String, password: String, username: String, confirm_password: String) -> Dictionary:
	if email.is_empty():
		return {"valid": false, "message": "Email is required"}
	if not is_valid_email(email):
		return {"valid": false, "message": "Please enter a valid email address"}
	if password.is_empty():
		return {"valid": false, "message": "Password is required"}
	if password.length() < 6:
		return {"valid": false, "message": "Password must be at least 6 characters long"}
	if username.is_empty():
		return {"valid": false, "message": "Username is required"}
	if username.length() < 3:
		return {"valid": false, "message": "Username must be at least 3 characters long"}
	if not is_valid_username(username):
		return {"valid": false, "message": "Username can only contain letters, numbers, and underscores"}
	if confirm_password != password:
		return {"valid": false, "message": "Passwords do not match"}
	return {"valid": true, "message": ""}

# Validate sign in inputs
static func validate_signin(email: String, password: String) -> Dictionary:
	if email.is_empty():
		return {"valid": false, "message": "Email is required"}
	if not is_valid_email(email):
		return {"valid": false, "message": "Please enter a valid email address"}
	if password.is_empty():
		return {"valid": false, "message": "Password is required"}
	if password.length() < 6:
		return {"valid": false, "message": "Password must be at least 6 characters long"}
	return {"valid": true, "message": ""}
