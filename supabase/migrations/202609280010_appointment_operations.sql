create or replace function public.update_appointment_status(p_appointment uuid,p_status public.appointment_status)
returns void language plpgsql security definer set search_path=public as $$
declare v_shop uuid;v_current public.appointment_status;
begin select barbershop_id,status into v_shop,v_current from appointments where id=p_appointment;if not found then raise exception 'Appointment not found';end if;
if not public.has_barbershop_role(v_shop,array['owner','manager','receptionist']::public.member_role[]) then raise exception 'Not authorized';end if;
if p_status not in ('confirmed','completed','cancelled','no_show') then raise exception 'Invalid target status';end if;
if v_current in ('cancelled','completed','no_show') then raise exception 'Appointment is already closed';end if;
update appointments set status=p_status,updated_at=now() where id=p_appointment;end$$;
grant execute on function public.update_appointment_status(uuid,public.appointment_status) to authenticated;

create or replace function public.reschedule_appointment_safe(p_appointment uuid,p_starts_at timestamptz)
returns void language plpgsql security definer set search_path=public as $$
declare v_shop uuid;v_barber uuid;v_service uuid;v_duration integer;v_end timestamptz;v_tz text;v_ls timestamp;v_le timestamp;v_day integer;v_status public.appointment_status;
begin select a.barbershop_id,a.barber_id,a.service_id,a.status,s.duration_minutes into v_shop,v_barber,v_service,v_status,v_duration from appointments a join services s on s.id=a.service_id where a.id=p_appointment;if not found then raise exception 'Appointment not found';end if;
if not public.has_barbershop_role(v_shop,array['owner','manager','receptionist']::public.member_role[]) then raise exception 'Not authorized';end if;
if v_status in('cancelled','completed','no_show') then raise exception 'Appointment is already closed';end if;
if p_starts_at<=now() then raise exception 'New time must be in the future';end if;
select timezone into v_tz from barbershops where id=v_shop;v_end:=p_starts_at+make_interval(mins=>v_duration);v_ls:=p_starts_at at time zone v_tz;v_le:=v_end at time zone v_tz;v_day:=extract(dow from v_ls);
if not exists(select 1 from barber_availability where barbershop_id=v_shop and barber_id=v_barber and weekday=v_day and starts_at<=v_ls::time and ends_at>=v_le::time) then raise exception 'Outside barber working hours';end if;
update appointments set starts_at=p_starts_at,ends_at=v_end,status='confirmed',updated_at=now() where id=p_appointment;
exception when exclusion_violation then raise exception 'Barber is unavailable during this time';end$$;
grant execute on function public.reschedule_appointment_safe(uuid,timestamptz) to authenticated;