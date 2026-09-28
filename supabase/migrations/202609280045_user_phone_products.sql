begin;

alter table public.profiles add column if not exists phone text;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_phone text;
begin
 if nullif(trim(coalesce(new.raw_user_meta_data->>'phone','')),'') is not null then
  v_phone:=public.normalize_e164_digits(new.raw_user_meta_data->>'phone');
 end if;
 insert into public.profiles(id,full_name,phone)
 values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),v_phone)
 on conflict(id) do update set
  full_name=case when nullif(public.profiles.full_name,'') is null then excluded.full_name else public.profiles.full_name end,
  phone=coalesce(public.profiles.phone,excluded.phone);
 return new;
end$$;

create table if not exists public.products(
 id uuid primary key default gen_random_uuid(),
 barbershop_id uuid not null references public.barbershops(id) on delete cascade,
 name text not null check(length(trim(name))>0),
 description text,
 price_cents integer not null check(price_cents>=0),
 stock_quantity integer not null default 0 check(stock_quantity>=0),
 active boolean not null default true,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists products_barbershop_active_idx on public.products(barbershop_id,active);
alter table public.products enable row level security;
drop policy if exists "members read products" on public.products;
drop policy if exists "admins manage products" on public.products;
create policy "members read products" on public.products for select
 using(public.is_barbershop_member(barbershop_id));
create policy "admins manage products" on public.products for all
 using(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[]))
 with check(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[]));

commit;
