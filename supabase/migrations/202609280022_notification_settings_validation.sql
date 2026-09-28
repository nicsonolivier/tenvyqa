begin;
create or replace function public.save_notification_settings(p_barbershop uuid,p_confirmation_enabled boolean,p_confirmation_template text,p_confirmation_language text,p_reminder_enabled boolean,p_reminder_hours integer,p_reminder_template text,p_reminder_language text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if not public.has_barbershop_role(p_barbershop,array['owner','manager']::public.member_role[]) then raise exception 'Not authorized';end if;
 if p_confirmation_enabled and not exists(select 1 from whatsapp_templates where barbershop_id=p_barbershop and name=p_confirmation_template and language=p_confirmation_language and status='approved') then raise exception 'Confirmation template must be approved';end if;
 if p_reminder_enabled and not exists(select 1 from whatsapp_templates where barbershop_id=p_barbershop and name=p_reminder_template and language=p_reminder_language and status='approved') then raise exception 'Reminder template must be approved';end if;
 if p_reminder_hours<1 or p_reminder_hours>168 then raise exception 'Invalid reminder interval';end if;
 insert into notification_settings(barbershop_id,appointment_confirmation_enabled,confirmation_template_name,confirmation_template_language,appointment_reminder_enabled,reminder_hours_before,reminder_template_name,reminder_template_language)
 values(p_barbershop,p_confirmation_enabled,nullif(p_confirmation_template,''),p_confirmation_language,p_reminder_enabled,p_reminder_hours,nullif(p_reminder_template,''),p_reminder_language)
 on conflict(barbershop_id) do update set appointment_confirmation_enabled=excluded.appointment_confirmation_enabled,confirmation_template_name=excluded.confirmation_template_name,confirmation_template_language=excluded.confirmation_template_language,appointment_reminder_enabled=excluded.appointment_reminder_enabled,reminder_hours_before=excluded.reminder_hours_before,reminder_template_name=excluded.reminder_template_name,reminder_template_language=excluded.reminder_template_language,updated_at=now();
 perform schedule_appointment_notifications(a.id) from appointments a where a.barbershop_id=p_barbershop and a.status in('pending','confirmed') and a.starts_at>now();
end$$;
revoke all on function public.save_notification_settings(uuid,boolean,text,text,boolean,integer,text,text) from public,anon;grant execute on function public.save_notification_settings(uuid,boolean,text,text,boolean,integer,text,text) to authenticated;
commit;