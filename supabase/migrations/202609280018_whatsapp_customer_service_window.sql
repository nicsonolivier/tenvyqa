begin;
alter table public.conversations add column if not exists last_customer_message_at timestamptz;
alter table public.messages add column if not exists message_type text not null default 'text' check(message_type in('text','template'));
alter table public.messages add column if not exists template_name text;
alter table public.messages add column if not exists template_language text;
create or replace function public.register_inbound_conversation(p_barbershop uuid,p_customer uuid,p_customer_message_at timestamptz default now())
returns table(id uuid,mode public.conversation_mode) language plpgsql security definer set search_path=public,pg_temp as $$
begin
 insert into public.conversations(barbershop_id,customer_id,mode,unread_count,last_message_at,last_customer_message_at) values(p_barbershop,p_customer,'ai',1,p_customer_message_at,p_customer_message_at)
 on conflict(barbershop_id,customer_id) do update set unread_count=public.conversations.unread_count+1,last_message_at=greatest(public.conversations.last_message_at,p_customer_message_at),last_customer_message_at=greatest(coalesce(public.conversations.last_customer_message_at,p_customer_message_at),p_customer_message_at),updated_at=now()
 returning conversations.id,conversations.mode into id,mode;return next;
end$$;
revoke all on function public.register_inbound_conversation(uuid,uuid,timestamptz) from public,anon,authenticated;
create or replace function public.claim_outbound_message(p_message uuid)
returns table(id uuid,barbershop_id uuid,conversation_id uuid,body text,message_type text,template_name text,template_language text) language plpgsql security definer set search_path=public,pg_temp as $$
begin
 return query update public.messages m set status='sending',sending_started_at=now(),send_attempts=m.send_attempts+1,last_send_error=null
 from public.conversations c where m.id=p_message and c.id=m.conversation_id and m.direction='outbound' and m.external_message_id is null and m.send_attempts<4
 and (m.status in('generated','queued','retry') or (m.status='sending' and m.sending_started_at<now()-interval '2 minutes'))
 and (m.message_type='template' or c.last_customer_message_at is not null and c.last_customer_message_at>=now()-interval '24 hours')
 returning m.id,m.barbershop_id,m.conversation_id,m.body,m.message_type,m.template_name,m.template_language;
end$$;
revoke all on function public.claim_outbound_message(uuid) from public,anon,authenticated;
create or replace function public.fail_expired_freeform_message(p_message uuid) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare changed boolean;begin update public.messages m set status='failed',failed_at=now(),last_send_error='Customer service window expired' from public.conversations c where m.id=p_message and c.id=m.conversation_id and m.direction='outbound' and m.message_type='text' and m.external_message_id is null and (c.last_customer_message_at is null or c.last_customer_message_at<now()-interval '24 hours') returning true into changed;return coalesce(changed,false);end$$;
revoke all on function public.fail_expired_freeform_message(uuid) from public,anon,authenticated;
commit;