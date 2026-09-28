begin;
create table public.notification_settings(
 id uuid primary key default gen_random_uuid(),barbershop_id uuid not null unique references public.barbershops(id) on delete cascade,
 appointment_confirmation_enabled boolean not null default false,confirmation_template_name text,confirmation_template_language text not null default 'pt_BR',
 appointment_reminder_enabled boolean not null default false,reminder_hours_before integer not null default 24 check(reminder_hours_before between 1 and 168),reminder_template_name text,reminder_template_language text not null default 'pt_BR',
 created_at timestamptz not null default now(),updated_at timestamptz not null default now());
alter table public.notification_settings enable row level security;
create policy "members read notification settings" on public.notification_settings for select using(public.is_barbershop_member(barbershop_id));
create policy "admins manage notification settings" on public.notification_settings for all using(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[])) with check(public.has_barbershop_role(barbershop_id,array['owner','manager']::public.member_role[]));

create table public.appointment_notifications(
 id uuid primary key default gen_random_uuid(),barbershop_id uuid not null references public.barbershops(id) on delete cascade,appointment_id uuid not null references public.appointments(id) on delete cascade,
 kind text not null check(kind in('confirmation','reminder')),scheduled_for timestamptz not null,status text not null default 'pending' check(status in('pending','processing','sent','skipped','failed')),
 message_id uuid references public.messages(id) on delete set null,attempts integer not null default 0,last_error text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(appointment_id,kind,scheduled_for));
create index appointment_notifications_due_idx on public.appointment_notifications(status,scheduled_for) where status='pending';
alter table public.appointment_notifications enable row level security;
create policy "members read appointment notifications" on public.appointment_notifications for select using(public.is_barbershop_member(barbershop_id));

create or replace function public.schedule_appointment_notifications(p_appointment uuid) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare a appointments%rowtype;s notification_settings%rowtype;begin select * into a from appointments where id=p_appointment;if not found then return;end if;select * into s from notification_settings where barbershop_id=a.barbershop_id;if not found then return;end if;
 delete from appointment_notifications where appointment_id=a.id and status='pending';
 if a.status in('pending','confirmed') then
  if s.appointment_confirmation_enabled and s.confirmation_template_name is not null then insert into appointment_notifications(barbershop_id,appointment_id,kind,scheduled_for) values(a.barbershop_id,a.id,'confirmation',now()) on conflict do nothing;end if;
  if s.appointment_reminder_enabled and s.reminder_template_name is not null and a.starts_at-make_interval(hours=>s.reminder_hours_before)>now() then insert into appointment_notifications(barbershop_id,appointment_id,kind,scheduled_for) values(a.barbershop_id,a.id,'reminder',a.starts_at-make_interval(hours=>s.reminder_hours_before)) on conflict do nothing;end if;
 end if;end$$;
revoke all on function public.schedule_appointment_notifications(uuid) from public,anon,authenticated;

create or replace function public.appointment_notification_trigger() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$begin perform public.schedule_appointment_notifications(new.id);return new;end$$;
drop trigger if exists appointments_schedule_notifications on public.appointments;
create trigger appointments_schedule_notifications after insert or update of starts_at,status on public.appointments for each row execute function public.appointment_notification_trigger();

create or replace function public.claim_due_appointment_notifications(p_limit integer default 25)
returns table(id uuid,barbershop_id uuid,appointment_id uuid,kind text) language plpgsql security definer set search_path=public,pg_temp as $$
begin return query update appointment_notifications n set status='processing',attempts=attempts+1,updated_at=now() where n.id in(select x.id from appointment_notifications x where x.status='pending' and x.scheduled_for<=now() order by x.scheduled_for for update skip locked limit greatest(1,least(p_limit,100))) returning n.id,n.barbershop_id,n.appointment_id,n.kind;end$$;
revoke all on function public.claim_due_appointment_notifications(integer) from public,anon,authenticated;
commit;