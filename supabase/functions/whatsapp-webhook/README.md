# TENVYQA WhatsApp Webhook

Edge Function para eventos inbound/status da Meta WhatsApp Business Cloud API.

## Secrets
- WHATSAPP_VERIFY_TOKEN
- META_APP_SECRET
- TENVYQA_INTERNAL_SECRET
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY

A função valida o challenge GET e a assinatura HMAC `x-hub-signature-256` dos POSTs. O tenant é resolvido por `metadata.phone_number_id`.

Mensagens de texto entram pelo RPC transacional `ingest_whatsapp_text_message_internal`, que trata idempotência, customer, conversation, unread e persistência do inbound. Quando a conversa está em modo IA, o webhook chama `ai-orchestrator` usando o ID persistido e, havendo resposta, encaminha o message ID para `whatsapp-send`.

Callbacks de status atualizam sent/delivered/read/failed. Mensagens não-texto ainda não são persistidas como chat no MVP.
