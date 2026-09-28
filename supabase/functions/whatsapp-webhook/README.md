# TENVYQA WhatsApp Webhook

Server-side Supabase Edge Function for Meta WhatsApp Business Cloud API inbound events.

Required secrets:
- WHATSAPP_VERIFY_TOKEN
- META_APP_SECRET
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY

The function verifies GET subscription challenges and validates POST x-hub-signature-256 before processing. Tenant routing uses metadata.phone_number_id. Text inbound messages are idempotent through messages.external_message_id.

This function intentionally does not contain a WhatsApp access token and does not send outbound messages yet. Outbound transport is a separate server-side layer.

Non-text messages are acknowledged but not persisted as chat text in this first transport phase.