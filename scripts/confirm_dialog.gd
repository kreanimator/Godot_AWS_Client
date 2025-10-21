extends AcceptDialog

@onready var email_label: Label = $VBoxContainer/EmailLabel
@onready var code_input: LineEdit = $VBoxContainer/CodeInput

signal code_confirmed(code: String)
signal dialog_cancelled
signal resend_requested

func _ready():
	visible = false
	get_ok_button().text = "Confirm"
	add_button("Resend code", false, "resend")
	
	confirmed.connect(_on_confirmed)
	close_requested.connect(_on_cancelled)
	custom_action.connect(_on_custom_action)

func show_dialog(email: String):
	email_label.text = email
	code_input.text = ""
	code_input.grab_focus()
	popup_centered(Vector2i(400, 200))
	move_to_foreground()

func _on_confirmed():
	var code = code_input.text.strip_edges()
	code_confirmed.emit(code)

func _on_cancelled():
	dialog_cancelled.emit()

func _on_custom_action(action: String):
	if action == "resend":
		resend_requested.emit()
