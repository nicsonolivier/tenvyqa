begin;

create or replace function public.normalize_e164_digits(p_phone text)
returns text language plpgsql immutable set search_path=public,pg_temp as $$
declare v text;
begin
 v:=regexp_replace(coalesce(p_phone,''),'[^0-9]','','g');
 if v!~'^[1-9][0-9]{7,14}$' then raise exception 'Invalid international phone number';end if;
 return v;
end$$;
revoke all on function public.normalize_e164_digits(text) from public,anon;
grant execute on function public.normalize_e164_digits(text) to authenticated,service_role;

create or replace function public.create_customer_safe(p_barbershop uuid,p_name text,p_phone text)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_id uuid;v_phone text;
begin
 if not public.has_barbershop_role(p_barbershop,array['owner','manager','receptionist']::public.member_role[]) then raise exception 'Not authorized';end if;
 if nullif(trim(p_name),'') is null then raise exception 'Customer name is required';end if;
 v_phone:=public.normalize_e164_digits(p_phone);
 insert into customers(barbershop_id,name,whatsapp_phone)
 values(p_barbershop,trim(p_name),v_phone)
 returning id into v_id;
 return v_id;
exception when unique_violation then
 raise exception 'Customer phone already exists';
end$$;
revoke all on function public.create_customer_safe(uuid,text,text) from public,anon;
grant execute on function public.create_customer_safe(uuid,text,text) to authenticated;

commit;