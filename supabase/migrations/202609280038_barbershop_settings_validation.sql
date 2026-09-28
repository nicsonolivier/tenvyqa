begin;

create or replace function public.save_barbershop_settings(
 p_barbershop uuid,p_name text,p_phone text,p_whatsapp_phone text,p_description text,p_timezone text
) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_name text:=nullif(trim(p_name),'');v_tz text:=nullif(trim(p_timezone),'');
begin
 if not public.has_barbershop_role(p_barbershop,array['owner','manager']::public.member_role[]) then raise exception 'Not authorized';end if;
 if v_name is null then raise exception 'Barbershop name is required';end if;
 if v_tz is null or not exists(select 1 from pg_timezone_names where name=v_tz) then raise exception 'Invalid timezone';end if;
 update barbershops set
  name=v_name,
  phone=nullif(trim(p_phone),''),
  whatsapp_phone=nullif(trim(p_whatsapp_phone),''),
  description=nullif(trim(p_description),''),
  timezone=v_tz,
  updated_at=now()
 where id=p_barbershop;
 if not found then raise exception 'Barbershop not found';end if;
end$$;
revoke all on function public.save_barbershop_settings(uuid,text,text,text,text,text) from public,anon;
grant execute on function public.save_barbershop_settings(uuid,text,text,text,text,text) to authenticated;

commit;