extends RefCounted
class_name ErrorHandler

# Convert AWS Cognito errors to user-friendly messages
static func get_friendly_error(res: Dictionary) -> String:
	var typ = str(res.get("raw", {}).get("__type", ""))
	var msg = str(res.get("raw", {}).get("message", ""))
	
	# Common friendly mappings
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
