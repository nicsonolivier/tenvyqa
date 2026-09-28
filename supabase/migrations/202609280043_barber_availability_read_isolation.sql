begin;

drop policy if exists "members read availability" on public.barber_availability;

create policy "operations read availability" on public.barber_availability for select
using(public.has_barbershop_role(barbershop_id,array['owner','manager','receptionist']::public.member_role[]));

create policy "barbers read own availability" on public.barber_availability for select
using(
 public.has_barbershop_role(barbershop_id,array['barber']::public.member_role[])
 and public.is_own_barber(barbershop_id,barber_id)
);

commit;