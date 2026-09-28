begin;
create table if not exists public.whatsapp_templates(id uuid primary key default gen_random_uuid(),barbershop_id uuid not null references public.barbershops(id) on delete cascade,name text not null,language text not null default 'pt_BR',category text,status text not null default 'unknown' check(status in('unknown','pending','approved','rejected','paused','disabled')),created_at timestamptz not null default now(),updated_at timestamptz not null default now(),unique(barbershop_id,name,language));
alter table public.whatsapp_templates enable row level security;
create policy "members read whatsapp templates" on public.whatsapp_templates for select using(public.is_barbershop_member(barbershop_id));
create policy "admins manage whatsapp template references" on public.whatsapp_templates for all using(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[])) with check(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[]));
create or replace function public.create_template_message(p_conversation uuid,p_template_name text,p_language text default 'pt_BR')
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_shop uuid;v_id uuid;begin
 select barbershop_id into v_shop from public.conversations where id=p_conversation;if not found then raise exception 'Conversation not found';end if;
 if not public.has_barbershop_role(v_shop,array['owner','manager','receptionist']::public.member_role[]) then raise exception 'Not authorized';end if;
 if not exists(select 1 from public.whatsapp_templates where barbershop_id=v_shop and name=p_template_name and language=p_language and status='approved') then raise exception 'Approved template not found';end if;
 insert into public.messages(barbershop_id,conversation_id,direction,source,body,status,message_type,template_name,template_language) values(v_shop,p_conversation,'outbound','human','Template: '||p_template_name,'queued','template',p_template_name,p_language) returning id into v_id;
 update public.conversations set last_message_at=now(),updated_at=now() where id=p_conversation;return v_id;
end$$;
revoke all on function public.create_template_message(uuid,text,text) from public,anon;grant execute on function public.create_template_message(uuid,text,text) to authenticated;
commit;