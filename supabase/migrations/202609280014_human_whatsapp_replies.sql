begin;
create or replace function public.create_human_reply(p_conversation uuid,p_body text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_shop uuid;v_mode public.conversation_mode;v_id uuid;
begin
 if nullif(btrim(p_body),'') is null then raise exception 'Message cannot be empty';end if;
 if length(p_body)>4096 then raise exception 'Message is too long';end if;
 select barbershop_id,mode into v_shop,v_mode from public.conversations where id=p_conversation;if not found then raise exception 'Conversation not found';end if;
 if not public.has_barbershop_role(v_shop,array['owner','manager','receptionist']::public.member_role[]) then raise exception 'Not authorized';end if;
 if v_mode<>'human' then raise exception 'Take over the conversation before replying';end if;
 insert into public.messages(barbershop_id,conversation_id,direction,source,body,status) values(v_shop,p_conversation,'outbound','human',btrim(p_body),'queued') returning id into v_id;
 update public.conversations set last_message_at=now(),updated_at=now() where id=p_conversation;
 return v_id;
end$$;
revoke all on function public.create_human_reply(uuid,text) from public,anon;
grant execute on function public.create_human_reply(uuid,text) to authenticated;
commit;