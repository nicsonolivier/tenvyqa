begin;

drop policy if exists "members manage barber services" on public.barber_services;
create policy "admins manage barber services" on public.barber_services for all
using(exists(
 select 1 from public.barbers b
 where b.id=barber_id
 and public.has_barbershop_role(b.barbershop_id,array['owner','manager']::public.member_role[])
))
with check(exists(
 select 1 from public.barbers b
 where b.id=barber_id
 and public.has_barbershop_role(b.barbershop_id,array['owner','manager']::public.member_role[])
));

drop policy if exists "admins manage notification settings" on public.notification_settings;

commit;