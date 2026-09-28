begin;

create or replace function public.barber_can_read_customer(target_barbershop uuid,target_customer uuid)
returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select exists(
  select 1
  from public.appointments a
  join public.barbers b on b.id=a.barber_id
  where a.barbershop_id=target_barbershop
   and a.customer_id=target_customer
   and b.barbershop_id=target_barbershop
   and b.user_id=auth.uid()
 );
$$;
revoke all on function public.barber_can_read_customer(uuid,uuid) from public,anon;
grant execute on function public.barber_can_read_customer(uuid,uuid) to authenticated;

drop policy if exists "assigned barber read customers" on public.customers;
create policy "assigned barber read customers" on public.customers for select
using(
 public.has_barbershop_role(barbershop_id,array['barber']::public.member_role[])
 and public.barber_can_read_customer(barbershop_id,id)
);

drop policy if exists "members read memberships" on public.barbershop_members;
create policy "members read permitted memberships" on public.barbershop_members for select
using(
 user_id=auth.uid()
 or public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[])
);

commit;