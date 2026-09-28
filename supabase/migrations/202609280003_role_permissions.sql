-- Role-aware authorization helpers and stricter configuration writes.
create or replace function public.has_barbershop_role(target_barbershop uuid, allowed public.member_role[]) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.barbershop_members m where m.barbershop_id=target_barbershop and m.user_id=auth.uid() and m.role=any(allowed)); $$;
revoke all on function public.has_barbershop_role(uuid,public.member_role[]) from public;grant execute on function public.has_barbershop_role(uuid,public.member_role[]) to authenticated;

drop policy if exists "members manage services" on public.services;
create policy "members read services" on public.services for select using(public.is_barbershop_member(barbershop_id));
create policy "admins manage services" on public.services for all using(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[])) with check(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[]));

drop policy if exists "members manage barbers" on public.barbers;
create policy "members read barbers" on public.barbers for select using(public.is_barbershop_member(barbershop_id));
create policy "admins manage barbers" on public.barbers for all using(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[])) with check(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[]));

drop policy if exists "members manage hours" on public.business_hours;
create policy "members read hours" on public.business_hours for select using(public.is_barbershop_member(barbershop_id));
create policy "admins manage hours" on public.business_hours for all using(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[])) with check(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[]));

drop policy if exists "members manage availability" on public.barber_availability;
create policy "members read availability" on public.barber_availability for select using(public.is_barbershop_member(barbershop_id));
create policy "admins manage availability" on public.barber_availability for all using(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[])) with check(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[]));
