# TENVYQA AI Orchestrator

Supabase Edge Function that connects TENVYQA conversations to the OpenAI Responses API.

## Required Supabase secrets

- `OPENAI_API_KEY`
- `OPENAI_MODEL` (optional; defaults to `gpt-5.4-mini`)
- `TENVYQA_INTERNAL_SECRET`
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

The function is intentionally server-to-server. Do not call it directly from the browser and never expose these secrets through `VITE_*` variables.

## Flow

1. Trusted webhook/backend supplies `conversation_id` and the inbound message.
2. Function verifies conversation is still in AI mode.
3. Recent history and barbershop AI settings are loaded.
4. OpenAI can request only the declared TENVYQA tools.
5. Tool inputs are validated again by database-backed actions.
6. Appointment creation uses collision-safe server-side SQL.
7. Final AI reply is persisted to `messages`.
8. WhatsApp delivery will be handled by the WhatsApp webhook/send layer.
