create table public.whatsapp_settings (
 id uuid primary key default gen_random_uuid(),
 barbershop_id uuid not null unique references public.barbershops(id) on delete cascade,
 phone_number_id text not null unique,
 business_account_id text,
 display_phone text,
 status text not null default 'disconnected',
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table public.whatsapp_settings enable row level security;
create policy "members read whatsapp settings" on public.whatsapp_settings for select using(public.is_barbershop_member(barbershop_id));
create policy "admins manage whatsapp settings" on public.whatsapp_settings for all using(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[])) with check(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[]));
create unique index if not exists messages_external_message_id_unique on public.messages(external_message_id) where external_message_id is not null;