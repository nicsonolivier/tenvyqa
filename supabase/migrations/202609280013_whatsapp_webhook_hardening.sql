begin;
alter table public.whatsapp_settings drop constraint if exists whatsapp_settings_status_check;
alter table public.whatsapp_settings add constraint whatsapp_settings_status_check check(status in('disconnected','pending','connected','error'));
create index if not exists whatsapp_settings_phone_number_idx on public.whatsapp_settings(phone_number_id);
commit;