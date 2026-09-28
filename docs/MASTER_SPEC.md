# TENVYQA — Master Specification V1

## Produto

**TENVYQA Business** é um SaaS exclusivo para barbearias.

**Tagline:** Atendimento inteligente. Sua barbearia nunca para.

Plataformas:
- Web
- iOS
- Android

Idioma: pt-BR  
Moeda: BRL (R$)  
Data: DD/MM/YYYY  
Hora: 24h

## Arquitetura

As três plataformas devem usar um único backend, banco, autenticação, motor de agendamentos, orquestração de IA e integração WhatsApp.

Tecnologias planejadas:
- React
- TypeScript
- Supabase
- PostgreSQL
- Supabase Authentication
- Edge/server functions
- OpenAI API
- Meta WhatsApp Business Cloud API

Credenciais e chaves devem existir somente no backend/secrets.

## SaaS multi-tenant

Cada barbearia é um tenant independente. Registros relevantes usam `barbershop_id` e políticas RLS. Dados de uma barbearia jamais podem ser acessados por outra.

Cada barbearia possui seus próprios usuários, barbeiros, clientes, serviços, preços, horários, agendamentos, conversas, mensagens, configurações de IA e WhatsApp.

## Perfis e permissões

- **Owner:** acesso completo.
- **Manager:** gestão operacional.
- **Receptionist:** conversas, clientes, agenda e agendamentos.
- **Barber:** própria agenda, próprios atendimentos e informações necessárias do cliente.

Permissões devem ser validadas no servidor.

## Onboarding

1. Dados da barbearia.
2. Endereço.
3. Horário de funcionamento.
4. Serviços.
5. Barbeiros.
6. Agenda individual dos barbeiros.
7. Assistente IA.
8. Conexão WhatsApp.
9. Teste do atendimento.
10. Dashboard.

## Navegação Web

Dashboard · Conversas · Agenda · Clientes · Serviços · Barbeiros · Assistente IA · Configurações

A web é otimizada para administração e operação da barbearia.

## Navegação Mobile

Início · Conversas · Agenda · Clientes · Mais

O mobile deve ter UX própria para toque, e não ser apenas o desktop reduzido.

## Dashboard

Exibir somente métricas derivadas de dados reais:
- agendamentos hoje;
- agendamentos no mês;
- conversas hoje;
- novos clientes;
- cancelamentos;
- próximos atendimentos;
- conversas recentes;
- serviços mais agendados;
- barbeiros mais ocupados.

## Conversas

Inbox estilo WhatsApp com histórico, mensagens recebidas/enviadas, cliente, agendamento e origem da resposta.

### Controle humano

**Assumir conversa:** pausa respostas automáticas da IA.

**Devolver para IA:** reativa o atendimento automático.

Registrar remetente, conteúdo, horário, direção, status e origem IA/Humano.

## Serviços

Campos:
- nome;
- descrição;
- preço;
- duração;
- ativo/inativo.

Exemplos: Corte, Barba, Corte + Barba, Corte Infantil, Pezinho, Sobrancelha.

A IA nunca pode inventar preço ou serviço.

## Barbeiros

Campos:
- foto;
- nome;
- descrição;
- especialidades;
- serviços;
- dias e horários de trabalho;
- intervalos;
- ativo/inativo.

Cada barbeiro possui agenda individual.

## Agenda e agendamentos

Visualizações dia, semana e mês, com filtro por barbeiro.

Agendamento:
- cliente;
- barbeiro;
- serviço;
- início;
- fim;
- preço;
- status.

Status: `pending`, `confirmed`, `completed`, `cancelled`, `no_show`.

O sistema deve impedir conflitos de horário.

### Validação obrigatória

Antes de inserir:
1. validar barbearia;
2. validar serviço;
3. validar barbeiro;
4. confirmar que o barbeiro executa o serviço;
5. validar data;
6. confirmar expediente;
7. validar horário;
8. verificar intervalos;
9. verificar agendamentos existentes;
10. calcular duração;
11. garantir disponibilidade de todo o intervalo;
12. validar novamente imediatamente antes da inserção;
13. criar agendamento.

A disponibilidade nunca pode vir da imaginação do modelo.

## Clientes

Perfil com nome, WhatsApp, primeiro contato, última visita, total de agendamentos, próximo agendamento, histórico, barbeiro preferido e observações.

## Assistente IA

Configuração:
- nome;
- tom (profissional, amigável, casual);
- mensagem de boas-vindas;
- descrição da barbearia;
- endereço;
- funcionamento;
- pagamentos;
- estacionamento;
- política de cancelamento;
- política de atraso;
- FAQs;
- ativada/desativada.

A IA responde naturalmente em português brasileiro.

### Responsabilidades da IA

Pode entender linguagem natural, detectar intenção, extrair serviço/barbeiro/data/horário, responder FAQs e solicitar ações ao backend.

Pode auxiliar em:
- serviços e preços;
- horários e endereço;
- disponibilidade;
- criar, reagendar e cancelar agendamentos;
- transferência para humano.

Não pode inventar serviços, preços, barbeiros, horários, disponibilidade ou políticas.

### Backend actions

- `get_services`
- `get_service_price`
- `get_barbers`
- `get_barber_services`
- `get_business_hours`
- `get_business_information`
- `get_availability`
- `create_appointment`
- `reschedule_appointment`
- `cancel_appointment`
- `get_customer`
- `get_customer_appointments`
- `transfer_to_human`

OpenAI solicita a ação; o backend valida autorização e regras, executa e devolve resultado estruturado. O modelo nunca modifica o banco diretamente.

## WhatsApp

Usar a Meta WhatsApp Business Cloud API oficial.

Fluxo:
Cliente → WhatsApp → Meta webhook → TENVYQA → identificação de barbearia/cliente/conversa → IA ou humano → ações/backend → resposta → WhatsApp.

Preparar webhooks para mensagens recebidas, enviadas e status de entrega/leitura, com verificação e validação de requisições.

## Banco de dados inicial

Tabelas planejadas:
- `barbershops`
- `profiles`
- `barbershop_members`
- `barbers`
- `services`
- `barber_services`
- `business_hours`
- `barber_availability`
- `customers`
- `appointments`
- `conversations`
- `messages`
- `knowledge_base`
- `ai_settings`
- `whatsapp_settings`

Usar UUIDs quando apropriado, foreign keys, constraints, índices, timestamps e RLS.

## Mobile — TENVYQA Business

Destinado a Owner, Manager, Receptionist e Barber.

Início: agenda do dia, conversas novas, próximo atendimento, novos clientes e notificações.

Conversas: inbox, atendimento manual, assumir/devolver à IA e dados do cliente.

Agenda: hoje/semana e filtro por barbeiro.

Clientes: busca, perfil e histórico.

Mais: serviços, barbeiros, IA, barbearia, configurações e conta.

Preparar push notifications para novos agendamentos, cancelamentos, solicitação de humano e lembretes operacionais.

## Sincronização

Web, iOS e Android usam a mesma fonte de dados. Um agendamento criado pela IA no WhatsApp deve aparecer no Web e Mobile sem duplicar lógica de negócio.

## Segurança

Implementar RLS, autorização server-side, validação de inputs, secrets, endpoints protegidos, rate limiting quando necessário, tratamento seguro de erros e timestamps de auditoria.

Nunca expor service role. Nunca confiar em IDs do cliente sem autorização. Nunca executar dados estruturados da IA sem validação.

## Design

Interface premium, moderna, minimalista, profissional e tecnológica. Evitar clichês visuais de barbearia e excesso de elementos decorativos.

Usar tipografia clara, boa hierarquia, espaçamento generoso, cards, sombras sutis, ícones profissionais e controles mobile touch-friendly.

Criar estados de loading, skeleton, vazio, erro, retry, validação e sucesso.

## Escopo MVP V1

Priorizar:
- autenticação;
- onboarding;
- multi-tenant + RLS;
- barbeiros;
- serviços;
- horários;
- clientes;
- agenda/agendamentos;
- conversas WhatsApp;
- assistente OpenAI;
- takeover humano;
- dashboard;
- Web;
- experiência Mobile.

Não incluir no V1:
- salões de beleza;
- saúde/odontologia;
- oficinas;
- marketplace;
- app de consumidor;
- folha de pagamento;
- contabilidade;
- estoque;
- ERP.

## Fases

1. Banco, autenticação, multi-tenant e RLS.
2. Onboarding, serviços, barbeiros e horários.
3. Clientes, agenda e motor de agendamento.
4. Dashboard e interface de conversas.
5. Orquestração OpenAI.
6. WhatsApp Cloud API.
7. Mobile e preparação de push.
8. Testes de segurança, permissões, colisões e ferramentas da IA.

## Regra de desenvolvimento

O código-fonte deste repositório é a fonte oficial do projeto. Alterações devem ser feitas aqui; o Lovable deve ser usado como ambiente de visualização/preview quando conectado.
