begin;
create or replace function public.replace_barber_availability(p_barber uuid,p_rows jsonb)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_shop uuid;v_row jsonb;v_weekday integer;v_start time;v_end time;
begin
 select barbershop_id into v_shop from barbers where id=p_barber;
 if v_shop is null then raise exception 'Barber not found';end if;
 if not public.has_barbershop_role(v_shop,array['owner'::member_role,'manager'::member_role]) then raise exception 'Not authorized';end if;
 if jsonb_typeof(coalesce(p_rows,'[]'::jsonb))<>'array' then raise exception 'Invalid availability';end if;
 for v_row in select value from jsonb_array_elements(coalesce(p_rows,'[]'::jsonb)) loop
  v_weekday=(v_row->>'weekday')::integer;v_start=(v_row->>'starts_at')::time;v_end=(v_row->>'ends_at')::time;
  if v_weekday<0 or v_weekday>6 or v_start>=v_end then raise exception 'Invalid availability interval';end if;
 end loop;
 delete from barber_availability where barber_id=p_barber;
 insert into barber_availability(barbershop_id,barber_id,weekday,starts_at,ends_at)
 select v_shop,p_barber,(x->>'weekday')::integer,(x->>'starts_at')::time,(x->>'ends_at')::time from jsonb_array_elements(coalesce(p_rows,'[]'::jsonb)) x;
end$$;
revoke all on function public.replace_barber_availability(uuid,jsonb) from public,anon;
grant execute on function public.replace_barber_availability(uuid,jsonb) to authenticated;
commit;