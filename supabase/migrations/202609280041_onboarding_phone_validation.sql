begin;

create or replace function public.create_barbershop_for_current_user(shop_name text,shop_phone text default null,shop_whatsapp text default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare uid uuid:=auth.uid();new_shop uuid;base_slug text;v_phone text;v_whatsapp text;
begin
 if uid is null then raise exception 'Authentication required';end if;
 if nullif(trim(shop_name),'') is null then raise exception 'Barbershop name is required';end if;
 if exists(select 1 from barbershop_members where user_id=uid) then raise exception 'User already belongs to a barbershop';end if;
 if nullif(trim(shop_phone),'') is not null then v_phone:=public.normalize_e164_digits(shop_phone);end if;
 if nullif(trim(shop_whatsapp),'') is not null then v_whatsapp:=public.normalize_e164_digits(shop_whatsapp);end if;
 insert into profiles(id,full_name) values(uid,'') on conflict(id) do nothing;
 base_slug:=lower(regexp_replace(trim(shop_name),'[^a-zA-Z0-9]+','-','g'))||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,6);
 insert into barbershops(name,slug,phone,whatsapp_phone) values(trim(shop_name),base_slug,v_phone,v_whatsapp) returning id into new_shop;
 insert into barbershop_members(barbershop_id,user_id,role) values(new_shop,uid,'owner');
 return new_shop;
end$$;
revoke all on function public.create_barbershop_for_current_user(text,text,text) from public,anon;
grant execute on function public.create_barbershop_for_current_user(text,text,text) to authenticated;

commit;