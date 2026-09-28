begin;
alter table public.messages add column if not exists send_attempts integer not null default 0 check(send_attempts>=0);
alter table public.messages add column if not exists sending_started_at timestamptz;
alter table public.messages add column if not exists last_send_error text;
create or replace function public.register_inbound_conversation(p_barbershop uuid,p_customer uuid)
returns table(id uuid,mode public.conversation_mode) language plpgsql security definer set search_path=public,pg_temp as $$
begin
 insert into public.conversations(barbershop_id,customer_id,mode,unread_count,last_message_at) values(p_barbershop,p_customer,'ai',1,now())
 on conflict(barbershop_id,customer_id) do update set unread_count=public.conversations.unread_count+1,last_message_at=now(),updated_at=now()
 returning conversations.id,conversations.mode into id,mode;return next;
end$$;
revoke all on function public.register_inbound_conversation(uuid,uuid) from public,anon,authenticated;
create or replace function public.claim_outbound_message(p_message uuid)
returns table(id uuid,barbershop_id uuid,conversation_id uuid,body text) language plpgsql security definer set search_path=public,pg_temp as $$
begin
 return query update public.messages m set status='sending',sending_started_at=now(),send_attempts=m.send_attempts+1,last_send_error=null
 where m.id=p_message and m.direction='outbound' and m.external_message_id is null and m.send_attempts<4 and (m.status in('generated','queued','retry') or (m.status='sending' and m.sending_started_at<now()-interval '2 minutes'))
 returning m.id,m.barbershop_id,m.conversation_id,m.body;
end$$;
revoke all on function public.claim_outbound_message(uuid) from public,anon,authenticated;
create or replace function public.release_outbound_message(p_message uuid,p_retry boolean,p_error text default null) returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin update public.messages set status=case when p_retry and send_attempts<4 then 'retry' else 'failed' end,last_send_error=left(p_error,500),sending_started_at=null where id=p_message and external_message_id is null;end$$;
revoke all on function public.release_outbound_message(uuid,boolean,text) from public,anon,authenticated;
commit;