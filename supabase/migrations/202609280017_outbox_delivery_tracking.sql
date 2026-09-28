begin;
alter table public.messages add column if not exists sent_at timestamptz;
alter table public.messages add column if not exists delivered_at timestamptz;
alter table public.messages add column if not exists read_at timestamptz;
alter table public.messages add column if not exists failed_at timestamptz;
create index if not exists messages_retry_outbox_idx on public.messages(status,send_attempts,sending_started_at) where direction='outbound' and external_message_id is null;
create or replace function public.apply_whatsapp_message_status(p_barbershop uuid,p_external_message_id text,p_status text,p_event_at timestamptz default now())
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 update public.messages set
 status=case
  when p_status='read' then 'read'
  when p_status='delivered' and status not in('read') then 'delivered'
  when p_status='sent' and status not in('read','delivered') then 'sent'
  when p_status='failed' and status not in('read','delivered','sent') then 'failed'
  else status end,
 sent_at=case when p_status in('sent','delivered','read') then coalesce(sent_at,p_event_at) else sent_at end,
 delivered_at=case when p_status in('delivered','read') then coalesce(delivered_at,p_event_at) else delivered_at end,
 read_at=case when p_status='read' then coalesce(read_at,p_event_at) else read_at end,
 failed_at=case when p_status='failed' and status not in('read','delivered','sent') then coalesce(failed_at,p_event_at) else failed_at end
 where barbershop_id=p_barbershop and external_message_id=p_external_message_id and direction='outbound';
end$$;
revoke all on function public.apply_whatsapp_message_status(uuid,text,text,timestamptz) from public,anon,authenticated;
create or replace function public.get_retryable_outbox(p_limit integer default 25)
returns table(id uuid) language sql security definer set search_path=public,pg_temp as $$
 select m.id from public.messages m where m.direction='outbound' and m.external_message_id is null and m.send_attempts<4 and (m.status='retry' or (m.status='sending' and m.sending_started_at<now()-interval '2 minutes')) order by coalesce(m.sending_started_at,m.created_at) asc limit greatest(1,least(p_limit,100));
$$;
revoke all on function public.get_retryable_outbox(integer) from public,anon,authenticated;
commit;