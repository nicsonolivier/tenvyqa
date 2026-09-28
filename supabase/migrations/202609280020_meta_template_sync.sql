begin;
alter table public.whatsapp_templates add column if not exists meta_template_id text;
alter table public.whatsapp_templates add column if not exists components jsonb not null default '[]'::jsonb;
alter table public.whatsapp_templates add column if not exists synced_at timestamptz;
create index if not exists whatsapp_templates_meta_id_idx on public.whatsapp_templates(barbershop_id,meta_template_id);
drop policy if exists "admins manage whatsapp template references" on public.whatsapp_templates;
create policy "admins delete whatsapp template references" on public.whatsapp_templates for delete using(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[]));
commit;