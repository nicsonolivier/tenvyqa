begin;

create or replace function public.claim_due_appointment_notifications(p_limit integer default 25)
returns table(id uuid,barbershop_id uuid,appointment_id uuid,kind text,message_id uuid)
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 return query
 update appointment_notifications n
 set status='processing',attempts=n.attempts+1,processing_started_at=now(),updated_at=now()
 where n.id in(
  select x.id from appointment_notifications x
  where x.attempts<4 and x.scheduled_for<=now()
   and (x.status='pending' or (x.status='processing' and x.processing_started_at<now()-interval '5 minutes'))
  order by x.scheduled_for for update skip locked
  limit greatest(1,least(p_limit,100))
 )
 returning n.id,n.barbershop_id,n.appointment_id,n.kind,n.message_id;
end$$;
revoke all on function public.claim_due_appointment_notifications(integer) from public,anon,authenticated;
grant execute on function public.claim_due_appointment_notifications(integer) to service_role;

create or replace function public.ensure_appointment_notification_message(
 p_notification uuid,p_conversation uuid,p_template_name text,p_template_language text
) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare n appointment_notifications%rowtype;v_message uuid;
begin
 select * into n from appointment_notifications where id=p_notification for update;
 if not found then raise exception 'Notification not found';end if;
 if n.message_id is not null then return n.message_id;end if;
 if n.status<>'processing' then raise exception 'Notification is not processing';end if;
 if not exists(select 1 from conversations c where c.id=p_conversation and c.barbershop_id=n.barbershop_id) then raise exception 'Invalid conversation';end if;
 if not exists(select 1 from whatsapp_templates t where t.barbershop_id=n.barbershop_id and t.name=p_template_name and t.language=p_template_language and t.status='approved') then raise exception 'Template is not approved';end if;
 insert into messages(barbershop_id,conversation_id,direction,source,body,status,message_type,template_name,template_language)
 values(n.barbershop_id,p_conversation,'outbound','system','Template: '||p_template_name,'queued','template',p_template_name,p_template_language)
 returning id into v_message;
 update appointment_notifications set message_id=v_message,updated_at=now() where id=n.id;
 return v_message;
end$$;
revoke all on function public.ensure_appointment_notification_message(uuid,uuid,text,text) from public,anon,authenticated;
grant execute on function public.ensure_appointment_notification_message(uuid,uuid,text,text) to service_role;

commit;