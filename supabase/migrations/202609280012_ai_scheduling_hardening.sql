begin;
create or replace function public.get_available_slots_internal(p_barbershop uuid,p_barber uuid,p_service uuid,p_date date,p_step_minutes integer default 30)
returns table(slot_start timestamptz,slot_end timestamptz) language plpgsql stable security definer set search_path=public,pg_temp as $$
declare v_duration integer;v_tz text;v_bo time;v_bc time;v_so time;v_sc time;v_open time;v_close time;v_day integer;v_cursor timestamp;v_end timestamp;
begin
 if p_step_minutes is null or p_step_minutes<5 or p_step_minutes>240 then raise exception 'Invalid slot step';end if;
 select duration_minutes into v_duration from public.services where id=p_service and barbershop_id=p_barbershop and active=true;if not found then raise exception 'Invalid service';end if;
 if not exists(select 1 from public.barbers b join public.barber_services bs on bs.barber_id=b.id where b.id=p_barber and b.barbershop_id=p_barbershop and b.active and bs.service_id=p_service) then raise exception 'Barber does not perform this service';end if;
 select timezone into v_tz from public.barbershops where id=p_barbershop;if not found then raise exception 'Invalid barbershop';end if;
 v_day:=extract(dow from p_date);
 select starts_at,ends_at into v_bo,v_bc from public.barber_availability where barbershop_id=p_barbershop and barber_id=p_barber and weekday=v_day limit 1;if not found then return;end if;
 select opens_at,closes_at into v_so,v_sc from public.business_hours where barbershop_id=p_barbershop and weekday=v_day and is_closed=false;if not found then return;end if;
 v_open:=greatest(v_bo,v_so);v_close:=least(v_bc,v_sc);if v_open>=v_close then return;end if;
 v_cursor:=p_date+v_open;v_end:=p_date+v_close;
 while v_cursor+make_interval(mins=>v_duration)<=v_end loop
  if (v_cursor at time zone v_tz)>now() and not exists(select 1 from public.appointments a where a.barber_id=p_barber and a.status in('pending','confirmed') and tstzrange(a.starts_at,a.ends_at,'[)')&&tstzrange(v_cursor at time zone v_tz,(v_cursor+make_interval(mins=>v_duration)) at time zone v_tz,'[)')) then slot_start:=v_cursor at time zone v_tz;slot_end:=(v_cursor+make_interval(mins=>v_duration)) at time zone v_tz;return next;end if;
  v_cursor:=v_cursor+make_interval(mins=>p_step_minutes);
 end loop;
end$$;
revoke all on function public.get_available_slots_internal(uuid,uuid,uuid,date,integer) from public,anon,authenticated;

create or replace function public.create_appointment_internal(p_barbershop uuid,p_customer uuid,p_barber uuid,p_service uuid,p_starts_at timestamptz,p_notes text default null)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v_duration integer;v_price integer;v_end timestamptz;v_id uuid;v_tz text;v_ls timestamp;v_le timestamp;v_day integer;
begin
 if p_starts_at<=now() then raise exception 'Appointment must be in the future';end if;
 select duration_minutes,price_cents into v_duration,v_price from public.services where id=p_service and barbershop_id=p_barbershop and active=true;if not found then raise exception 'Invalid service';end if;
 if not exists(select 1 from public.barbers b join public.barber_services bs on bs.barber_id=b.id where b.id=p_barber and b.barbershop_id=p_barbershop and b.active and bs.service_id=p_service) then raise exception 'Invalid barber/service';end if;
 if not exists(select 1 from public.customers where id=p_customer and barbershop_id=p_barbershop) then raise exception 'Invalid customer';end if;
 select timezone into v_tz from public.barbershops where id=p_barbershop;if not found then raise exception 'Invalid barbershop';end if;
 v_end:=p_starts_at+make_interval(mins=>v_duration);v_ls:=p_starts_at at time zone v_tz;v_le:=v_end at time zone v_tz;v_day:=extract(dow from v_ls);
 if not exists(select 1 from public.barber_availability where barbershop_id=p_barbershop and barber_id=p_barber and weekday=v_day and starts_at<=v_ls::time and ends_at>=v_le::time) then raise exception 'Outside barber working hours';end if;
 if not exists(select 1 from public.business_hours where barbershop_id=p_barbershop and weekday=v_day and is_closed=false and opens_at<=v_ls::time and closes_at>=v_le::time) then raise exception 'Outside business hours';end if;
 insert into public.appointments(barbershop_id,customer_id,barber_id,service_id,starts_at,ends_at,price_cents,status,notes) values(p_barbershop,p_customer,p_barber,p_service,p_starts_at,v_end,v_price,'confirmed',p_notes) returning id into v_id;return v_id;
exception when exclusion_violation then raise exception 'Barber is unavailable during this time';end$$;
revoke all on function public.create_appointment_internal(uuid,uuid,uuid,uuid,timestamptz,text) from public,anon,authenticated;
commit;