begin;
alter table public.appointment_notifications add column if not exists processing_started_at timestamptz;
create or replace function public.claim_due_appointment_notifications(p_limit integer default 25)
returns table(id uuid,barbershop_id uuid,appointment_id uuid,kind text) language plpgsql security definer set search_path=public,pg_temp as $$
begin
 return query update appointment_notifications n set status='processing',attempts=n.attempts+1,processing_started_at=now(),updated_at=now()
 where n.id in(select x.id from appointment_notifications x where x.attempts<4 and x.scheduled_for<=now() and (x.status='pending' or (x.status='processing' and x.processing_started_at<now()-interval '5 minutes')) order by x.scheduled_for for update skip locked limit greatest(1,least(p_limit,100)))
 returning n.id,n.barbershop_id,n.appointment_id,n.kind;
end$$;
revoke all on function public.claim_due_appointment_notifications(integer) from public,anon,authenticated;grant execute on function public.claim_due_appointment_notifications(integer) to service_role;
create or replace function public.finish_appointment_notification(p_id uuid,p_status text,p_message uuid default null,p_error text default null) returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if p_status not in('sent','skipped','failed','pending') then raise exception 'Invalid notification status';end if;
 update appointment_notifications set status=p_status,message_id=coalesce(p_message,message_id),last_error=left(p_error,500),processing_started_at=null,updated_at=now() where id=p_id;
end$$;
revoke all on function public.finish_appointment_notification(uuid,text,uuid,text) from public,anon,authenticated;grant execute on function public.finish_appointment_notification(uuid,text,uuid,text) to service_role;
commit;