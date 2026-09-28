-- Appointment engine: database-level collision prevention + secure creation RPC.
create extension if not exists btree_gist;

alter table public.appointments
  add constraint appointments_no_barber_overlap
  exclude using gist (
    barber_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  ) where (status in ('pending','confirmed'));

create or replace function public.create_appointment_safe(
  p_barbershop uuid,
  p_customer uuid,
  p_barber uuid,
  p_service uuid,
  p_starts_at timestamptz,
  p_notes text default null
) returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_duration integer;
  v_price integer;
  v_end timestamptz;
  v_id uuid;
begin
  if not public.has_barbershop_role(p_barbershop,array['owner','manager','receptionist']::public.member_role[]) then
    raise exception 'Not authorized';
  end if;
  select duration_minutes,price_cents into v_duration,v_price
    from public.services where id=p_service and barbershop_id=p_barbershop and active=true;
  if not found then raise exception 'Invalid service'; end if;
  if not exists(select 1 from public.barbers where id=p_barber and barbershop_id=p_barbershop and active=true) then
    raise exception 'Invalid barber';
  end if;
  if not exists(select 1 from public.customers where id=p_customer and barbershop_id=p_barbershop) then
    raise exception 'Invalid customer';
  end if;
  v_end:=p_starts_at+make_interval(mins=>v_duration);
  insert into public.appointments(barbershop_id,customer_id,barber_id,service_id,starts_at,ends_at,price_cents,status,notes)
  values(p_barbershop,p_customer,p_barber,p_service,p_starts_at,v_end,v_price,'confirmed',p_notes)
  returning id into v_id;
  return v_id;
exception when exclusion_violation then
  raise exception 'Barber is unavailable during this time';
end; $$;
revoke all on function public.create_appointment_safe(uuid,uuid,uuid,uuid,timestamptz,text) from public;
grant execute on function public.create_appointment_safe(uuid,uuid,uuid,uuid,timestamptz,text) to authenticated;
