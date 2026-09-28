-- Barber-specific services, weekly availability, and reusable availability engine.
alter table public.barber_availability add constraint barber_availability_unique_weekday unique(barber_id,weekday);

drop policy if exists "members manage barber services" on public.barber_services;
create policy "admins manage barber services" on public.barber_services for all
using(exists(select 1 from public.barbers b where b.id=barber_id and public.has_barbershop_role(b.barbershop_id,array['owner','manager']::public.member_role[])))
with check(exists(select 1 from public.barbers b where b.id=barber_id and public.has_barbershop_role(b.barbershop_id,array['owner','manager']::public.member_role[])));

create or replace function public.get_available_slots(p_barbershop uuid,p_barber uuid,p_service uuid,p_date date,p_step_minutes integer default 30)
returns table(slot_start timestamptz,slot_end timestamptz)
language plpgsql stable security definer set search_path=public as $$
declare v_duration integer;v_tz text;v_open time;v_close time;v_day integer;v_cursor timestamp;v_end timestamp;
begin
 if not public.is_barbershop_member(p_barbershop) then raise exception 'Not authorized'; end if;
 select duration_minutes into v_duration from public.services where id=p_service and barbershop_id=p_barbershop and active=true;
 if not found then raise exception 'Invalid service'; end if;
 if not exists(select 1 from public.barbers b join public.barber_services bs on bs.barber_id=b.id where b.id=p_barber and b.barbershop_id=p_barbershop and b.active and bs.service_id=p_service) then raise exception 'Barber does not perform this service'; end if;
 select timezone into v_tz from public.barbershops where id=p_barbershop;
 v_day:=extract(dow from p_date);
 select starts_at,ends_at into v_open,v_close from public.barber_availability where barbershop_id=p_barbershop and barber_id=p_barber and weekday=v_day limit 1;
 if not found then return; end if;
 v_cursor:=p_date+v_open; v_end:=p_date+v_close;
 while v_cursor+make_interval(mins=>v_duration)<=v_end loop
   if not exists(select 1 from public.appointments a where a.barber_id=p_barber and a.status in('pending','confirmed') and tstzrange(a.starts_at,a.ends_at,'[)') && tstzrange(v_cursor at time zone v_tz,(v_cursor+make_interval(mins=>v_duration)) at time zone v_tz,'[)')) then
     slot_start:=v_cursor at time zone v_tz;slot_end:=(v_cursor+make_interval(mins=>v_duration)) at time zone v_tz;return next;
   end if;
   v_cursor:=v_cursor+make_interval(mins=>p_step_minutes);
 end loop;
end $$;
grant execute on function public.get_available_slots(uuid,uuid,uuid,date,integer) to authenticated;

create or replace function public.create_appointment_safe(p_barbershop uuid,p_customer uuid,p_barber uuid,p_service uuid,p_starts_at timestamptz,p_notes text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_duration integer;v_price integer;v_end timestamptz;v_id uuid;v_tz text;v_local_start timestamp;v_local_end timestamp;v_day integer;
begin
 if not public.has_barbershop_role(p_barbershop,array['owner','manager','receptionist']::public.member_role[]) then raise exception 'Not authorized'; end if;
 select duration_minutes,price_cents into v_duration,v_price from public.services where id=p_service and barbershop_id=p_barbershop and active=true;if not found then raise exception 'Invalid service';end if;
 if not exists(select 1 from public.barbers b join public.barber_services bs on bs.barber_id=b.id where b.id=p_barber and b.barbershop_id=p_barbershop and b.active and bs.service_id=p_service) then raise exception 'Barber does not perform this service';end if;
 if not exists(select 1 from public.customers where id=p_customer and barbershop_id=p_barbershop) then raise exception 'Invalid customer';end if;
 select timezone into v_tz from public.barbershops where id=p_barbershop;v_end:=p_starts_at+make_interval(mins=>v_duration);v_local_start:=p_starts_at at time zone v_tz;v_local_end:=v_end at time zone v_tz;v_day:=extract(dow from v_local_start);
 if not exists(select 1 from public.barber_availability where barbershop_id=p_barbershop and barber_id=p_barber and weekday=v_day and starts_at<=v_local_start::time and ends_at>=v_local_end::time) then raise exception 'Outside barber working hours';end if;
 insert into public.appointments(barbershop_id,customer_id,barber_id,service_id,starts_at,ends_at,price_cents,status,notes) values(p_barbershop,p_customer,p_barber,p_service,p_starts_at,v_end,v_price,'confirmed',p_notes) returning id into v_id;return v_id;
exception when exclusion_violation then raise exception 'Barber is unavailable during this time';end $$;
