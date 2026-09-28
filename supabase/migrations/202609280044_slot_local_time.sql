begin;

drop function if exists public.get_available_slots(uuid,uuid,uuid,date,integer);

create function public.get_available_slots(p_barbershop uuid,p_barber uuid,p_service uuid,p_date date,p_step_minutes integer default 30)
returns table(slot_start timestamptz,slot_end timestamptz,local_time text)
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare v_duration integer;v_tz text;v_barber_open time;v_barber_close time;v_shop_open time;v_shop_close time;v_open time;v_close time;v_day integer;v_cursor timestamp;v_end timestamp;
begin
 if not public.is_barbershop_member(p_barbershop) then raise exception 'Not authorized';end if;
 if public.has_barbershop_role(p_barbershop,array['barber']::public.member_role[]) and not public.is_own_barber(p_barbershop,p_barber) then raise exception 'Not authorized';end if;
 if p_step_minutes is null or p_step_minutes<5 or p_step_minutes>240 then raise exception 'Invalid slot step';end if;
 select duration_minutes into v_duration from services where id=p_service and barbershop_id=p_barbershop and active=true;if not found then raise exception 'Invalid service';end if;
 if not exists(select 1 from barbers b join barber_services bs on bs.barber_id=b.id where b.id=p_barber and b.barbershop_id=p_barbershop and b.active and bs.service_id=p_service) then raise exception 'Barber does not perform this service';end if;
 select timezone into v_tz from barbershops where id=p_barbershop;if v_tz is null then raise exception 'Barbershop not found';end if;
 begin perform now() at time zone v_tz;exception when invalid_parameter_value then raise exception 'Invalid barbershop timezone';end;
 v_day:=extract(dow from p_date);
 select starts_at,ends_at into v_barber_open,v_barber_close from barber_availability where barbershop_id=p_barbershop and barber_id=p_barber and weekday=v_day limit 1;if not found then return;end if;
 select opens_at,closes_at into v_shop_open,v_shop_close from business_hours where barbershop_id=p_barbershop and weekday=v_day and is_closed=false;if not found then return;end if;
 v_open:=greatest(v_barber_open,v_shop_open);v_close:=least(v_barber_close,v_shop_close);if v_open>=v_close then return;end if;
 v_cursor:=p_date+v_open;v_end:=p_date+v_close;
 while v_cursor+make_interval(mins=>v_duration)<=v_end loop
  if (v_cursor at time zone v_tz)>now() and not exists(select 1 from appointments a where a.barber_id=p_barber and a.status in('pending','confirmed') and tstzrange(a.starts_at,a.ends_at,'[)')&&tstzrange(v_cursor at time zone v_tz,(v_cursor+make_interval(mins=>v_duration)) at time zone v_tz,'[)')) then
   slot_start:=v_cursor at time zone v_tz;slot_end:=(v_cursor+make_interval(mins=>v_duration)) at time zone v_tz;local_time:=to_char(v_cursor,'HH24:MI');return next;
  end if;
  v_cursor:=v_cursor+make_interval(mins=>p_step_minutes);
 end loop;
end$$;
revoke all on function public.get_available_slots(uuid,uuid,uuid,date,integer) from public,anon;
grant execute on function public.get_available_slots(uuid,uuid,uuid,date,integer) to authenticated;

commit;