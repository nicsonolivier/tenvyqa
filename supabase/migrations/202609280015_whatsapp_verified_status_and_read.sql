begin;
create or replace function public.save_whatsapp_identifiers(p_barbershop uuid,p_phone_number_id text,p_business_account_id text default null,p_display_phone text default null)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not public.has_barbershop_role(p_barbershop,array['owner','manager']::public.member_role[]) then raise exception 'Not authorized';end if;
 if nullif(btrim(p_phone_number_id),'') is null then raise exception 'Phone Number ID is required';end if;
 insert into public.whatsapp_settings(barbershop_id,phone_number_id,business_account_id,display_phone,status,updated_at)
 values(p_barbershop,btrim(p_phone_number_id),nullif(btrim(p_business_account_id),''),nullif(btrim(p_display_phone),''),'pending',now())
 on conflict(barbershop_id) do update set phone_number_id=excluded.phone_number_id,business_account_id=excluded.business_account_id,display_phone=excluded.display_phone,status=case when public.whatsapp_settings.phone_number_id is distinct from excluded.phone_number_id then 'pending' else public.whatsapp_settings.status end,updated_at=now();
end$$;
revoke all on function public.save_whatsapp_identifiers(uuid,text,text,text) from public,anon;grant execute on function public.save_whatsapp_identifiers(uuid,text,text,text) to authenticated;
create or replace function public.mark_conversation_read(p_conversation uuid) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_shop uuid;begin select barbershop_id into v_shop from public.conversations where id=p_conversation;if not found then raise exception 'Conversation not found';end if;if not public.has_barbershop_role(v_shop,array['owner','manager','receptionist']::public.member_role[]) then raise exception 'Not authorized';end if;update public.conversations set unread_count=0,updated_at=now() where id=p_conversation;end$$;
revoke all on function public.mark_conversation_read(uuid) from public,anon;grant execute on function public.mark_conversation_read(uuid) to authenticated;
drop policy if exists "admins manage whatsapp settings" on public.whatsapp_settings;
create policy "admins insert whatsapp identifiers" on public.whatsapp_settings for insert with check(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[]) and status in('disconnected','pending'));
create policy "admins update whatsapp identifiers" on public.whatsapp_settings for update using(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[])) with check(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[]) and status in('disconnected','pending'));
commit;