create extension if not exists "pgcrypto";

create type public.member_role as enum ('owner','manager','receptionist','barber');
create type public.appointment_status as enum ('pending','confirmed','completed','cancelled','no_show');

create table public.barbershops (id uuid primary key default gen_random_uuid(), name text not null, slug text unique, phone text, whatsapp_phone text, description text, timezone text not null default 'America/Sao_Paulo', created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.profiles (id uuid primary key references auth.users(id) on delete cascade, full_name text, avatar_url text, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.barbershop_members (id uuid primary key default gen_random_uuid(), barbershop_id uuid not null references public.barbershops(id) on delete cascade, user_id uuid not null references public.profiles(id) on delete cascade, role public.member_role not null default 'barber', created_at timestamptz not null default now(), unique(barbershop_id,user_id));
create table public.services (id uuid primary key default gen_random_uuid(), barbershop_id uuid not null references public.barbershops(id) on delete cascade, name text not null, description text, price_cents integer not null check(price_cents>=0), duration_minutes integer not null check(duration_minutes>0), active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.barbers (id uuid primary key default gen_random_uuid(), barbershop_id uuid not null references public.barbershops(id) on delete cascade, user_id uuid references public.profiles(id) on delete set null, name text not null, bio text, photo_url text, active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now());
create table public.barber_services (barber_id uuid not null references public.barbers(id) on delete cascade, service_id uuid not null references public.services(id) on delete cascade, primary key(barber_id,service_id));
create table public.customers (id uuid primary key default gen_random_uuid(), barbershop_id uuid not null references public.barbershops(id) on delete cascade, name text, whatsapp_phone text not null, notes text, preferred_barber_id uuid references public.barbers(id) on delete set null, first_contact_at timestamptz not null default now(), created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(barbershop_id,whatsapp_phone));
create table public.business_hours (id uuid primary key default gen_random_uuid(), barbershop_id uuid not null references public.barbershops(id) on delete cascade, weekday smallint not null check(weekday between 0 and 6), opens_at time, closes_at time, is_closed boolean not null default false, unique(barbershop_id,weekday));
create table public.barber_availability (id uuid primary key default gen_random_uuid(), barbershop_id uuid not null references public.barbershops(id) on delete cascade, barber_id uuid not null references public.barbers(id) on delete cascade, weekday smallint not null check(weekday between 0 and 6), starts_at time not null, ends_at time not null, check(starts_at<ends_at));
create table public.appointments (id uuid primary key default gen_random_uuid(), barbershop_id uuid not null references public.barbershops(id) on delete cascade, customer_id uuid not null references public.customers(id), barber_id uuid not null references public.barbers(id), service_id uuid not null references public.services(id), starts_at timestamptz not null, ends_at timestamptz not null, price_cents integer not null check(price_cents>=0), status public.appointment_status not null default 'pending', notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), check(starts_at<ends_at));

create index on public.barbershop_members(user_id,barbershop_id);
create index on public.services(barbershop_id,active);
create index on public.barbers(barbershop_id,active);
create index on public.customers(barbershop_id,whatsapp_phone);
create index on public.appointments(barbershop_id,starts_at);
create index on public.appointments(barber_id,starts_at,ends_at);

create or replace function public.is_barbershop_member(target_barbershop uuid) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.barbershop_members m where m.barbershop_id=target_barbershop and m.user_id=auth.uid()); $$;

alter table public.barbershops enable row level security; alter table public.profiles enable row level security; alter table public.barbershop_members enable row level security; alter table public.services enable row level security; alter table public.barbers enable row level security; alter table public.barber_services enable row level security; alter table public.customers enable row level security; alter table public.business_hours enable row level security; alter table public.barber_availability enable row level security; alter table public.appointments enable row level security;

create policy "members read barbershops" on public.barbershops for select using(public.is_barbershop_member(id));
create policy "users read own profile" on public.profiles for select using(id=auth.uid());
create policy "users update own profile" on public.profiles for update using(id=auth.uid()) with check(id=auth.uid());
create policy "members read memberships" on public.barbershop_members for select using(user_id=auth.uid() or public.is_barbershop_member(barbershop_id));
create policy "members manage services" on public.services for all using(public.is_barbershop_member(barbershop_id)) with check(public.is_barbershop_member(barbershop_id));
create policy "members manage barbers" on public.barbers for all using(public.is_barbershop_member(barbershop_id)) with check(public.is_barbershop_member(barbershop_id));
create policy "members manage customers" on public.customers for all using(public.is_barbershop_member(barbershop_id)) with check(public.is_barbershop_member(barbershop_id));
create policy "members manage hours" on public.business_hours for all using(public.is_barbershop_member(barbershop_id)) with check(public.is_barbershop_member(barbershop_id));
create policy "members manage availability" on public.barber_availability for all using(public.is_barbershop_member(barbershop_id)) with check(public.is_barbershop_member(barbershop_id));
create policy "members manage appointments" on public.appointments for all using(public.is_barbershop_member(barbershop_id)) with check(public.is_barbershop_member(barbershop_id));
create policy "members read barber services" on public.barber_services for select using(exists(select 1 from public.barbers b where b.id=barber_id and public.is_barbershop_member(b.barbershop_id)));
create policy "members manage barber services" on public.barber_services for all using(exists(select 1 from public.barbers b where b.id=barber_id and public.is_barbershop_member(b.barbershop_id))) with check(exists(select 1 from public.barbers b where b.id=barber_id and public.is_barbershop_member(b.barbershop_id)));
