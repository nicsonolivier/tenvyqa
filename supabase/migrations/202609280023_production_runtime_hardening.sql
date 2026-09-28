begin;
do $$ begin
 if not exists(select 1 from pg_publication where pubname='supabase_realtime') then create publication supabase_realtime; end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='conversations') then alter publication supabase_realtime add table public.conversations; end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='messages') then alter publication supabase_realtime add table public.messages; end if;
end $$;
grant execute on function public.register_inbound_conversation(uuid,uuid,timestamptz) to service_role;
grant execute on function public.claim_outbound_message(uuid) to service_role;
grant execute on function public.release_outbound_message(uuid,boolean,text) to service_role;
grant execute on function public.get_retryable_outbox(integer) to service_role;
grant execute on function public.apply_whatsapp_message_status(uuid,text,text,timestamptz) to service_role;
grant execute on function public.fail_expired_freeform_message(uuid) to service_role;
grant execute on function public.schedule_appointment_notifications(uuid) to service_role;
grant execute on function public.claim_due_appointment_notifications(integer) to service_role;
commit;