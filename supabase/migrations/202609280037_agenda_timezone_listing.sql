begin;

create or replace function public.get_agenda_appointments(p_barbershop uuid,p_date date default null,p_barber uuid default null,p_limit integer default 100)
returns table(id uuid,barber_id uuid,service_id uuid,starts_at timestamptz,status public.appointment_status,customer_name text,barber_name text,service_name text,local_date text,local_time text)
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare v_tz text;v_start timestamptz;v_end timestamptz;v_limit integer;v_is_barber boolean;
begin
 if not public.is_barbershop_member(p_barbershop) then raise exception 'Not authorized';end if;\n v_is_barber:=public.has_barbershop_role(p_barbershop,array['barber']::public.member_role[]);
 select timezone into v_tz from barbershops where barbershops.id=p_barbershop;
 if v_tz is null then raise exception 'Barbershop not found';end if;
 begin perform now() at time zone v_tz;exception when invalid_parameter_value then raise exception 'Invalid barbershop timezone';end;
 v_limit:=least(greatest(coalesce(p_limit,100),1),500);
 if p_date is not null then
  v_start:=(p_date::timestamp at time zone v_tz);
  v_end:=((p_date+1)::timestamp at time zone v_tz);
 else v_start:=now();v_end:=null;end if;
 return query
 select a.id,a.barber_id,a.service_id,a.starts_at,a.status,c.name,b.name,s.name,
        to_char(a.starts_at at time zone v_tz,'DD/MM'),
        to_char(a.starts_at at time zone v_tz,'HH24:MI')
 from appointments a
 join customers c on c.id=a.customer_id
 join barbers b on b.id=a.barber_id
 join services s on s.id=a.service_id
 where a.barbershop_id=p_barbershop
   and a.starts_at>=v_start
   and (v_end is null or a.starts_at<v_end)
   and (p_barber is null or a.barber_id=p_barber)\n   and (not v_is_barber or public.is_own_barber(p_barbershop,a.barber_id))
 order by a.starts_at
 limit v_limit;
end$$;
revoke all on function public.get_agenda_appointments(uuid,date,uuid,integer) from public,anon;
grant execute on function public.get_agenda_appointments(uuid,date,uuid,integer) to authenticated;

commit;