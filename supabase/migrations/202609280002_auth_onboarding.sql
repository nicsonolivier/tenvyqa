-- Secure account/profile bootstrap and first barbershop creation.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$ begin insert into public.profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name','')) on conflict(id) do nothing; return new; end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

-- Backfill profiles for auth users created before this migration.
insert into public.profiles(id,full_name) select id,coalesce(raw_user_meta_data->>'full_name','') from auth.users on conflict(id) do nothing;

create or replace function public.create_barbershop_for_current_user(shop_name text, shop_phone text default null, shop_whatsapp text default null) returns uuid language plpgsql security definer set search_path=public as $$ declare uid uuid:=auth.uid(); new_shop uuid; base_slug text; begin if uid is null then raise exception 'Authentication required'; end if; if nullif(trim(shop_name),'') is null then raise exception 'Barbershop name is required'; end if; if exists(select 1 from public.barbershop_members where user_id=uid) then raise exception 'User already belongs to a barbershop'; end if; insert into public.profiles(id,full_name) values(uid,'') on conflict(id) do nothing; base_slug:=lower(regexp_replace(trim(shop_name),'[^a-zA-Z0-9]+','-','g'))||'-'||substr(replace(gen_random_uuid()::text,'-',''),1,6); insert into public.barbershops(name,slug,phone,whatsapp_phone) values(trim(shop_name),base_slug,nullif(trim(shop_phone),''),nullif(trim(shop_whatsapp),'')) returning id into new_shop; insert into public.barbershop_members(barbershop_id,user_id,role) values(new_shop,uid,'owner'); return new_shop; end; $$;

revoke all on function public.create_barbershop_for_current_user(text,text,text) from public;
grant execute on function public.create_barbershop_for_current_user(text,text,text) to authenticated;
