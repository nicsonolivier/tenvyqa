# TENVYQA AI Orchestrator

Supabase Edge Function server-to-server que conecta conversas TENVYQA à OpenAI Responses API.

## Secrets
- OPENAI_API_KEY
- OPENAI_MODEL (opcional)
- TENVYQA_INTERNAL_SECRET
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY

## Fluxo
1. O webhook persiste o inbound.
2. Chama o orquestrador com `conversation_id` e `inbound_message_id`.
3. O orquestrador valida que a mensagem pertence à conversa e é inbound do cliente.
4. Carrega histórico, configurações e FAQ.
5. A OpenAI pode solicitar somente as tools declaradas.
6. Ações operacionais são revalidadas no backend/banco.
7. A resposta final é persistida uma vez em `messages`.
8. O transporte WhatsApp é feito por `whatsapp-send`.

Nunca chame esta função diretamente do browser.
