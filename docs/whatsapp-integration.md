# WhatsApp Business Cloud API integration

TENVYQA will receive WhatsApp events through a server-side Supabase Edge Function.

## Tenant metadata

The `whatsapp_settings` table stores only non-secret routing metadata:
- barbershop_id
- phone_number_id
- business_account_id
- display_phone
- connection status

## Server-side secrets

The deployment environment must provide the WhatsApp access token, webhook verification token, Meta Graph API version, Supabase service credential, and the internal TENVYQA orchestration secret.

Never expose these values through `VITE_*` variables or browser code.

## Message flow

Customer -> WhatsApp -> Meta webhook -> identify phone_number_id -> barbershop -> customer -> conversation -> persist inbound message -> check AI/Human mode -> AI orchestrator -> validated actions -> outbound WhatsApp response.

If the conversation is in Human mode, automatic AI replies stop.

## Production requirement

Webhook request authenticity must be verified before processing production events. API versioning remains deployment-configurable rather than hard-coded into the product domain model.
