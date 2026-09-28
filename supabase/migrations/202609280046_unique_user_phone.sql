begin;

create unique index if not exists profiles_phone_unique_idx
on public.profiles(phone)
where phone is not null;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_phone text;
begin
 if nullif(trim(coalesce(new.raw_user_meta_data->>'phone','')),'') is not null then
  v_phone:=public.normalize_e164_digits(new.raw_user_meta_data->>'phone');
  if exists(select 1 from public.profiles p where p.phone=v_phone and p.id<>new.id) then
   raise exception 'Phone already registered';
  end if;
 end if;
 insert into public.profiles(id,full_name,phone)
 values(new.id,trim(coalesce(new.raw_user_meta_data->>'full_name','')),v_phone)
 on conflict(id) do update set
  full_name=case when nullif(public.profiles.full_name,'') is null then excluded.full_name else public.profiles.full_name end,
  phone=coalesce(public.profiles.phone,excluded.phone);
 return new;
end$$;

commit;
