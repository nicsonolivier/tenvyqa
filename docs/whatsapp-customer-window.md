# WhatsApp customer-service window and templates

TENVYQA records the timestamp of the latest inbound customer message on each conversation. Free-form outbound text is claimable only while that customer-service window remains valid. If the window has expired, the transport marks the free-form message failed and returns requires_template.

Template messages use a separate message_type=template path. A template reference must exist for the tenant and be marked approved before create_template_message can enqueue it. The application must not infer approval: production synchronization with Meta remains required.

The current sender supports templates without parameter components. Variable/header/button template components require a later structured parameter model and must not be approximated with free-form text.