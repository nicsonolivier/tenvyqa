# TENVYQA WhatsApp Sender

Internal server-to-server Edge Function for outbound WhatsApp text messages.

Required secrets:
- WHATSAPP_ACCESS_TOKEN
- META_GRAPH_API_VERSION
- TENVYQA_INTERNAL_SECRET
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY

Input: message_id for an already-persisted outbound TENVYQA message.

The sender resolves the tenant phone_number_id and customer phone server-side, posts to the Meta Graph /{phone-number-id}/messages endpoint, stores the returned WhatsApp message ID (wamid) in messages.external_message_id, and lets the webhook update sent/delivered/read/failed states.

Never expose this function or its secrets directly to the browser.