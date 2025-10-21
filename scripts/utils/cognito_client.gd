extends RefCounted
class_name CognitoClient

var http: HTTPRequest
var region: String
var client_id: String

func _init(http_request: HTTPRequest, aws_region: String, app_client_id: String):
	http = http_request
	region = aws_region
	client_id = app_client_id

# Make API call to AWS Cognito
func call_api(target: String, body: Dictionary) -> Dictionary:
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

	var resp: Array = await http.request_completed
	var result_code: int = int(resp[0])
	var response_code: int = int(resp[1])
	var _resp_headers: PackedStringArray = resp[2]
	var raw_body: PackedByteArray = resp[3]
	var txt: String = raw_body.get_string_from_utf8()

	# Success path
	if response_code >= 200 and response_code < 300:
		if txt == "":
			return {}
		var parsed: Variant = JSON.parse_string(txt)
		if typeof(parsed) == TYPE_DICTIONARY:
			return parsed as Dictionary
		else:
			var wrapped_result: Dictionary = {"raw": parsed}
			return wrapped_result

	# Error path
	var obj: Dictionary = {}
	if txt != "":
		var parsed_err: Variant = JSON.parse_string(txt)
		if typeof(parsed_err) == TYPE_DICTIONARY:
			obj = parsed_err as Dictionary
		else:
			obj = {"raw_text": txt}
	return {"__error__": true, "status_code": response_code, "raw": obj, "result": result_code}

# Sign up user
func sign_up(email: String, password: String, username: String) -> Dictionary:
	return await call_api("SignUp", {
		"ClientId": client_id,
		"Username": email,
		"Password": password,
		"UserAttributes": [
			{"Name": "email", "Value": email},
			{"Name": "preferred_username", "Value": username}
		]
	})

# Confirm sign up
func confirm_sign_up(email: String, code: String) -> Dictionary:
	return await call_api("ConfirmSignUp", {
		"ClientId": client_id,
		"Username": email,
		"ConfirmationCode": code
	})

# Sign in user
func sign_in(email: String, password: String) -> Dictionary:
	return await call_api("InitiateAuth", {
		"AuthFlow": "USER_PASSWORD_AUTH",
		"ClientId": client_id,
		"AuthParameters": {
			"USERNAME": email,
			"PASSWORD": password
		}
	})

# Resend confirmation code
func resend_confirmation_code(email: String) -> Dictionary:
	return await call_api("ResendConfirmationCode", {
		"ClientId": client_id,
		"Username": email
	})

# Global sign out (invalidates all tokens on server)
func global_sign_out(access_token: String) -> Dictionary:
	return await call_api("GlobalSignOut", {
		"AccessToken": access_token
	})

# Forgot password - initiate password reset
func forgot_password(email: String) -> Dictionary:
	return await call_api("ForgotPassword", {
		"ClientId": client_id,
		"Username": email
	})

# Confirm forgot password - set new password
func confirm_forgot_password(email: String, confirmation_code: String, new_password: String) -> Dictionary:
	return await call_api("ConfirmForgotPassword", {
		"ClientId": client_id,
		"Username": email,
		"ConfirmationCode": confirmation_code,
		"Password": new_password
	})
