begin;

create or replace function public.is_own_barber(target_barbershop uuid,target_barber uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.barbers b where b.id=target_barber and b.barbershop_id=target_barbershop and b.user_id=auth.uid());
$$;
revoke all on function public.is_own_barber(uuid,uuid) from public,anon;
grant execute on function public.is_own_barber(uuid,uuid) to authenticated;

drop policy if exists "members read appointments" on public.appointments;
create policy "operations or assigned barber read appointments" on public.appointments for select
using(
 public.has_barbershop_role(barbershop_id,array['owner','manager','receptionist']::public.member_role[])
 or (
  public.has_barbershop_role(barbershop_id,array['barber']::public.member_role[])
  and public.is_own_barber(barbershop_id,barber_id)
 )
);

drop policy if exists "members manage customers" on public.customers;
create policy "operations manage customers" on public.customers for all
using(public.has_barbershop_role(barbershop_id,array['owner','manager','receptionist']::public.member_role[]))
with check(public.has_barbershop_role(barbershop_id,array['owner','manager','receptionist']::public.member_role[]));

create policy "assigned barber read customers" on public.customers for select
using(
 public.has_barbershop_role(barbershop_id,array['barber']::public.member_role[])
 and exists(
  select 1 from public.appointments a
  join public.barbers b on b.id=a.barber_id
  where a.customer_id=customers.id and a.barbershop_id=customers.barbershop_id and b.user_id=auth.uid()
 )
);

commit;