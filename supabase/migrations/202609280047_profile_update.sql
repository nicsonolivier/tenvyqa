begin;

create or replace function public.update_current_user_profile(p_full_name text,p_phone text)
returns table(full_name text,phone text)
language plpgsql security definer set search_path=public,pg_temp as $$
declare uid uuid:=auth.uid();v_name text;v_phone text;
begin
 if uid is null then raise exception 'Authentication required';end if;
 v_name:=trim(coalesce(p_full_name,''));
 if v_name='' then raise exception 'Full name is required';end if;
 v_phone:=public.normalize_e164_digits(p_phone);
 if exists(select 1 from public.profiles p where p.phone=v_phone and p.id<>uid) then
  raise exception 'Phone already registered';
 end if;
 update public.profiles p set full_name=v_name,phone=v_phone,updated_at=now() where p.id=uid;
 if not found then raise exception 'Profile not found';end if;
 return query select p.full_name,p.phone from public.profiles p where p.id=uid;
end$$;

revoke all on function public.update_current_user_profile(text,text) from public,anon;
grant execute on function public.update_current_user_profile(text,text) to authenticated;

commit;
