# TENVYQA — Production Deployment Runbook

Este documento descreve o deploy do MVP sem armazenar credenciais no Git.

## 1. Pré-requisitos
- Projeto Supabase criado e vinculado ao repositório.
- Aplicação Meta com WhatsApp Business Cloud API e número configurado.
- Chave OpenAI criada para o backend.
- Templates necessários aprovados na Meta antes de ativar confirmações/lembretes.

## 2. Banco de dados
Aplique as migrations de `supabase/migrations` em ordem de nome. Não pule migrations. Depois valide:
- RLS habilitado nas tabelas tenant.
- `conversations` e `messages` na publication `supabase_realtime`.
- RPCs internos executáveis por `service_role`, mas não por `anon`/`authenticated` quando marcados internos.
- constraint de colisão de agenda ativa.

## 3. Edge Functions
Deploy:
- whatsapp-webhook
- ai-orchestrator
- whatsapp-send
- whatsapp-human-send
- whatsapp-verify
- whatsapp-template-sync
- whatsapp-retry-worker
- appointment-notification-worker

O comportamento de JWT está versionado em `supabase/config.toml`. Webhook e funções internas usam autenticação própria; funções de usuário exigem JWT.

## 4. Secrets do backend
Configure no ambiente Supabase, nunca no frontend:
- OPENAI_API_KEY
- OPENAI_MODEL (opcional)
- WHATSAPP_ACCESS_TOKEN
- WHATSAPP_VERIFY_TOKEN
- META_APP_SECRET
- META_GRAPH_API_VERSION
- TENVYQA_INTERNAL_SECRET

`SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY` devem seguir o mecanismo de secrets/runtime do Supabase. Nunca use service role em variável `VITE_*`.

## 5. Frontend
Variáveis públicas:
- VITE_SUPABASE_URL
- VITE_SUPABASE_ANON_KEY

Execute build antes de publicar e trate qualquer erro como bloqueador.

## 6. Meta WhatsApp
Configure a callback para a função `whatsapp-webhook` e use o mesmo `WHATSAPP_VERIFY_TOKEN` do backend. Assine os eventos necessários de mensagens. A assinatura HMAC dos POSTs é validada com `META_APP_SECRET`.

No TENVYQA, Owner/Manager informa Phone Number ID e WABA ID, verifica a conexão no servidor e sincroniza templates. O status `connected` não é definido manualmente pelo browser.

## 7. Workers
`whatsapp-retry-worker` e `appointment-notification-worker` precisam ser invocados periodicamente por um scheduler autenticado com `TENVYQA_INTERNAL_SECRET`. O repositório contém os workers, mas a existência de um cron hospedado deve ser verificada no ambiente antes do go-live.

Nunca marque o sistema como pronto para produção se os workers não estiverem efetivamente agendados.

### Cadência recomendada

No projeto hospedado, habilite Supabase Cron e configure chamadas HTTP POST autenticadas para:
- `whatsapp-retry-worker`: a cada 1 minuto;
- `appointment-notification-worker`: a cada 1 minuto.

Use a autenticação interna já definida para os workers e mantenha as credenciais somente no ambiente hospedado. Não versione valores de autenticação em migrations, SQL, documentação ou frontend.

Após ativar os jobs, valide no histórico do Cron:
1. execuções recorrentes dos dois workers;
2. ausência de falhas persistentes;
3. retry real de uma mensagem temporariamente falha;
4. processamento de confirmação/lembrete em uma barbearia de teste.

A presença destas instruções no repositório não significa que o scheduler esteja ativo; confirme o estado no ambiente hospedado antes do go-live.

## 8. Teste end-to-end obrigatório
Em uma barbearia de teste:
1. criar serviço e barbeiro;
2. associar serviço ao barbeiro e cadastrar horário;
3. cadastrar/verificar WhatsApp e sincronizar templates;
4. enviar mensagem real do cliente;
5. confirmar criação única de customer/conversation/message;
6. confirmar uma única chamada lógica da IA para o inbound;
7. consultar disponibilidade real;
8. criar agendamento;
9. confirmar ausência de sobreposição;
10. receber resposta no WhatsApp;
11. conferir callbacks sent/delivered/read;
12. testar takeover humano e devolução para IA;
13. testar cancelamento/reagendamento;
14. testar confirmação/lembrete com template aprovado;
15. simular falha temporária e confirmar retry;
16. repetir o mesmo webhook e confirmar idempotência.

## 9. Critérios de go-live
Não liberar clientes pagantes enquanto houver falha em: isolamento multi-tenant, RLS, colisão de agenda, idempotência inbound, envio outbound, janela de atendimento, templates, takeover humano, workers ou secrets.

## 10. Limitações conhecidas do MVP
- inbound inicial é texto; mídia exige implementação adicional;
- templates com parâmetros/componentes dinâmicos ainda exigem modelo estruturado antes de serem usados;
- o token Meta atual é configurado no backend e o onboarding multi-tenant completo de credenciais Meta ainda precisa de estratégia própria;
- exatamente-uma-vez após aceitação pela Meta não pode ser garantido se houver queda entre a resposta do provedor e a persistência do wamid; a fila reduz duplicações, mas esse cenário deve ser monitorado.
