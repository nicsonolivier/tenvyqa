begin;

create or replace function public.ingest_whatsapp_text_message_internal(
 p_barbershop uuid,p_phone text,p_customer_name text,p_external_message_id text,p_body text,p_provider_created_at timestamptz default now()
)
returns table(conversation_id uuid,message_id uuid,conversation_mode public.conversation_mode,duplicate boolean)
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_customer uuid;v_conversation uuid;v_mode public.conversation_mode;v_message uuid;v_phone text;
begin
 if nullif(trim(p_external_message_id),'') is null then raise exception 'External message id is required';end if;
 if nullif(p_body,'') is null then raise exception 'Message body is required';end if;
 v_phone:=public.normalize_e164_digits(p_phone);

 select m.id,m.conversation_id into v_message,v_conversation from messages m where m.external_message_id=p_external_message_id;
 if found then select c.mode into v_mode from conversations c where c.id=v_conversation;return query select v_conversation,v_message,v_mode,true;return;end if;

 insert into customers(barbershop_id,whatsapp_phone,name,first_contact_at)
 values(p_barbershop,v_phone,nullif(p_customer_name,''),p_provider_created_at)
 on conflict(barbershop_id,whatsapp_phone) do update set name=coalesce(customers.name,excluded.name),updated_at=now()
 returning id into v_customer;

 insert into conversations(barbershop_id,customer_id,mode,unread_count,last_message_at,last_customer_message_at)
 values(p_barbershop,v_customer,'ai',1,p_provider_created_at,p_provider_created_at)
 on conflict(barbershop_id,customer_id) do update set unread_count=conversations.unread_count+1,last_message_at=greatest(conversations.last_message_at,excluded.last_message_at),last_customer_message_at=greatest(coalesce(conversations.last_customer_message_at,excluded.last_customer_message_at),excluded.last_customer_message_at),updated_at=now()
 returning id,mode into v_conversation,v_mode;

 begin
  insert into messages(barbershop_id,conversation_id,direction,source,body,external_message_id,status,provider_created_at)
  values(p_barbershop,v_conversation,'inbound','customer',p_body,p_external_message_id,'received',p_provider_created_at)
  returning id into v_message;
 exception when unique_violation then
  select m.id,m.conversation_id,c.mode into v_message,v_conversation,v_mode from messages m join conversations c on c.id=m.conversation_id where m.external_message_id=p_external_message_id;
  if not found then raise;end if;
  return query select v_conversation,v_message,v_mode,true;return;
 end;
 return query select v_conversation,v_message,v_mode,false;
end$$;
revoke all on function public.ingest_whatsapp_text_message_internal(uuid,text,text,text,text,timestamptz) from public,anon,authenticated;
grant execute on function public.ingest_whatsapp_text_message_internal(uuid,text,text,text,text,timestamptz) to service_role;

commit;