begin;

create or replace function public.get_dashboard_metrics(p_barbershop uuid)
returns table(appointments bigint,conversations bigint,customers bigint,barbers bigint)
language plpgsql stable security definer set search_path=public,pg_temp as $$
declare v_tz text;v_start timestamptz;v_end timestamptz;
begin
 if not public.is_barbershop_member(p_barbershop) then raise exception 'Not authorized';end if;
 select timezone into v_tz from barbershops where id=p_barbershop;
 if v_tz is null then raise exception 'Barbershop not found';end if;
 begin
  perform now() at time zone v_tz;
 exception when invalid_parameter_value then
  raise exception 'Invalid barbershop timezone';
 end;
 v_start:=(date_trunc('day',now() at time zone v_tz) at time zone v_tz);
 v_end:=((date_trunc('day',now() at time zone v_tz)+interval '1 day') at time zone v_tz);
 return query
 select
  (select count(*) from appointments a where a.barbershop_id=p_barbershop and a.starts_at>=v_start and a.starts_at<v_end),
  (select count(*) from conversations c where c.barbershop_id=p_barbershop and c.last_message_at>=v_start and c.last_message_at<v_end),
  (select count(*) from customers u where u.barbershop_id=p_barbershop and u.created_at>=v_start and u.created_at<v_end),
  (select count(*) from public.barbers b where b.barbershop_id=p_barbershop and b.active);
end$$;
revoke all on function public.get_dashboard_metrics(uuid) from public,anon;
grant execute on function public.get_dashboard_metrics(uuid) to authenticated;

commit;