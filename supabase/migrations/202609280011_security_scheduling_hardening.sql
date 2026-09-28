begin;

-- Conversation data is operational/customer-sensitive: barbers do not receive global inbox access.
drop policy if exists "members manage conversations" on public.conversations;
drop policy if exists "members manage messages" on public.messages;
create policy "operations manage conversations" on public.conversations for all
using(public.has_barbershop_role(barbershop_id,array['owner','manager','receptionist']::public.member_role[]))
with check(public.has_barbershop_role(barbershop_id,array['owner','manager','receptionist']::public.member_role[]));
create policy "operations manage messages" on public.messages for all
using(public.has_barbershop_role(barbershop_id,array['owner','manager','receptionist']::public.member_role[]))
with check(public.has_barbershop_role(barbershop_id,array['owner','manager','receptionist']::public.member_role[]));

-- Direct appointment writes bypass business validation, so authenticated clients must use RPCs.
drop policy if exists "members manage appointments" on public.appointments;
create policy "members read appointments" on public.appointments for select
using(public.is_barbershop_member(barbershop_id));

-- Global business hours must describe a valid interval whenever the shop is open.
alter table public.business_hours drop constraint if exists business_hours_valid_interval;
alter table public.business_hours add constraint business_hours_valid_interval
check(is_closed or (opens_at is not null and closes_at is not null and opens_at < closes_at));

create or replace function public.get_available_slots(p_barbershop uuid,p_barber uuid,p_service uuid,p_date date,p_step_minutes integer default 30)
returns table(slot_start timestamptz,slot_end timestamptz)
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare v_duration integer;v_tz text;v_barber_open time;v_barber_close time;v_shop_open time;v_shop_close time;v_open time;v_close time;v_day integer;v_cursor timestamp;v_end timestamp;
begin
 if not public.is_barbershop_member(p_barbershop) then raise exception 'Not authorized';end if;
 if p_step_minutes is null or p_step_minutes<5 or p_step_minutes>240 then raise exception 'Invalid slot step';end if;
 select duration_minutes into v_duration from public.services where id=p_service and barbershop_id=p_barbershop and active=true;if not found then raise exception 'Invalid service';end if;
 if not exists(select 1 from public.barbers b join public.barber_services bs on bs.barber_id=b.id where b.id=p_barber and b.barbershop_id=p_barbershop and b.active and bs.service_id=p_service) then raise exception 'Barber does not perform this service';end if;
 select timezone into v_tz from public.barbershops where id=p_barbershop;v_day:=extract(dow from p_date);
 select starts_at,ends_at into v_barber_open,v_barber_close from public.barber_availability where barbershop_id=p_barbershop and barber_id=p_barber and weekday=v_day limit 1;if not found then return;end if;
 select opens_at,closes_at into v_shop_open,v_shop_close from public.business_hours where barbershop_id=p_barbershop and weekday=v_day and is_closed=false;
 if not found then return;end if;
 v_open:=greatest(v_barber_open,v_shop_open);v_close:=least(v_barber_close,v_shop_close);if v_open>=v_close then return;end if;
 v_cursor:=p_date+v_open;v_end:=p_date+v_close;
 while v_cursor+make_interval(mins=>v_duration)<=v_end loop
  if (v_cursor at time zone v_tz)>now() and not exists(select 1 from public.appointments a where a.barber_id=p_barber and a.status in('pending','confirmed') and tstzrange(a.starts_at,a.ends_at,'[)')&&tstzrange(v_cursor at time zone v_tz,(v_cursor+make_interval(mins=>v_duration)) at time zone v_tz,'[)')) then slot_start:=v_cursor at time zone v_tz;slot_end:=(v_cursor+make_interval(mins=>v_duration)) at time zone v_tz;return next;end if;
  v_cursor:=v_cursor+make_interval(mins=>p_step_minutes);
 end loop;
end$$;

create or replace function public.create_appointment_safe(p_barbershop uuid,p_customer uuid,p_barber uuid,p_service uuid,p_starts_at timestamptz,p_notes text default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_duration integer;v_price integer;v_end timestamptz;v_id uuid;v_tz text;v_ls timestamp;v_le timestamp;v_day integer;
begin
 if not public.has_barbershop_role(p_barbershop,array['owner','manager','receptionist']::public.member_role[]) then raise exception 'Not authorized';end if;
 if p_starts_at<=now() then raise exception 'Appointment must be in the future';end if;
 select duration_minutes,price_cents into v_duration,v_price from public.services where id=p_service and barbershop_id=p_barbershop and active=true;if not found then raise exception 'Invalid service';end if;
 if not exists(select 1 from public.barbers b join public.barber_services bs on bs.barber_id=b.id where b.id=p_barber and b.barbershop_id=p_barbershop and b.active and bs.service_id=p_service) then raise exception 'Barber does not perform this service';end if;
 if not exists(select 1 from public.customers where id=p_customer and barbershop_id=p_barbershop) then raise exception 'Invalid customer';end if;
 select timezone into v_tz from public.barbershops where id=p_barbershop;v_end:=p_starts_at+make_interval(mins=>v_duration);v_ls:=p_starts_at at time zone v_tz;v_le:=v_end at time zone v_tz;v_day:=extract(dow from v_ls);
 if not exists(select 1 from public.barber_availability where barbershop_id=p_barbershop and barber_id=p_barber and weekday=v_day and starts_at<=v_ls::time and ends_at>=v_le::time) then raise exception 'Outside barber working hours';end if;
 if not exists(select 1 from public.business_hours where barbershop_id=p_barbershop and weekday=v_day and is_closed=false and opens_at<=v_ls::time and closes_at>=v_le::time) then raise exception 'Outside business hours';end if;
 insert into public.appointments(barbershop_id,customer_id,barber_id,service_id,starts_at,ends_at,price_cents,status,notes) values(p_barbershop,p_customer,p_barber,p_service,p_starts_at,v_end,v_price,'confirmed',p_notes) returning id into v_id;return v_id;
exception when exclusion_violation then raise exception 'Barber is unavailable during this time';end$$;

create or replace function public.reschedule_appointment_safe(p_appointment uuid,p_starts_at timestamptz)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_shop uuid;v_barber uuid;v_duration integer;v_end timestamptz;v_tz text;v_ls timestamp;v_le timestamp;v_day integer;v_status public.appointment_status;
begin
 select a.barbershop_id,a.barber_id,a.status,s.duration_minutes into v_shop,v_barber,v_status,v_duration from public.appointments a join public.services s on s.id=a.service_id where a.id=p_appointment;if not found then raise exception 'Appointment not found';end if;
 if not public.has_barbershop_role(v_shop,array['owner','manager','receptionist']::public.member_role[]) then raise exception 'Not authorized';end if;
 if v_status in('cancelled','completed','no_show') then raise exception 'Appointment is already closed';end if;if p_starts_at<=now() then raise exception 'New time must be in the future';end if;
 select timezone into v_tz from public.barbershops where id=v_shop;v_end:=p_starts_at+make_interval(mins=>v_duration);v_ls:=p_starts_at at time zone v_tz;v_le:=v_end at time zone v_tz;v_day:=extract(dow from v_ls);
 if not exists(select 1 from public.barber_availability where barbershop_id=v_shop and barber_id=v_barber and weekday=v_day and starts_at<=v_ls::time and ends_at>=v_le::time) then raise exception 'Outside barber working hours';end if;
 if not exists(select 1 from public.business_hours where barbershop_id=v_shop and weekday=v_day and is_closed=false and opens_at<=v_ls::time and closes_at>=v_le::time) then raise exception 'Outside business hours';end if;
 update public.appointments set starts_at=p_starts_at,ends_at=v_end,status='confirmed',updated_at=now() where id=p_appointment;
exception when exclusion_violation then raise exception 'Barber is unavailable during this time';end$$;

-- Harden user-facing SECURITY DEFINER RPC privileges.
revoke all on function public.is_barbershop_member(uuid) from public,anon;
grant execute on function public.is_barbershop_member(uuid) to authenticated;
revoke all on function public.get_available_slots(uuid,uuid,uuid,date,integer) from public,anon;
grant execute on function public.get_available_slots(uuid,uuid,uuid,date,integer) to authenticated;
revoke all on function public.create_appointment_safe(uuid,uuid,uuid,uuid,timestamptz,text) from public,anon;
grant execute on function public.create_appointment_safe(uuid,uuid,uuid,uuid,timestamptz,text) to authenticated;
revoke all on function public.set_conversation_mode(uuid,public.conversation_mode) from public,anon;
grant execute on function public.set_conversation_mode(uuid,public.conversation_mode) to authenticated;
revoke all on function public.update_appointment_status(uuid,public.appointment_status) from public,anon;
grant execute on function public.update_appointment_status(uuid,public.appointment_status) to authenticated;
revoke all on function public.reschedule_appointment_safe(uuid,timestamptz) from public,anon;
grant execute on function public.reschedule_appointment_safe(uuid,timestamptz) to authenticated;

commit;