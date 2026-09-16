-- Local release audit: run after auth_shim, migrations, and feed_rls.sql.
-- Uses only the isolated test database; rolls back its score fixtures.
\set ON_ERROR_STOP on
begin;
insert into auth.users(id,email) values
('33333333-3333-3333-3333-333333333333','score-a@example.invalid'),
('44444444-4444-4444-4444-444444444444','score-b@example.invalid');
set local role authenticated;
set local request.jwt.claim.sub='33333333-3333-3333-3333-333333333333';
insert into public.scores(user_id,day,value,reason,client_updated_at) values
(auth.uid(),'2026-09-01',70,'private reason','2026-09-01T10:00:00Z');
select public.assert((select count(*)=1 from public.scores),'S1 own score readable');
set local request.jwt.claim.sub='44444444-4444-4444-4444-444444444444';
select public.assert((select count(*)=0 from public.scores),'S2 other account cannot read score or reason');
do $$ begin
 insert into public.scores(user_id,day,value,client_updated_at) values
 ('33333333-3333-3333-3333-333333333333','2026-09-02',10,now());
 raise exception 'FAIL other-owner insert allowed';
exception when insufficient_privilege then raise notice 'PASS S3 other-owner insert denied'; end $$;
update public.scores set value=1 where user_id='33333333-3333-3333-3333-333333333333';
delete from public.scores where user_id='33333333-3333-3333-3333-333333333333';
set local request.jwt.claim.sub='33333333-3333-3333-3333-333333333333';
select public.assert((select value=70 from public.scores),'S4 other-owner update/delete had no effect');
insert into public.scores(user_id,day,value,reason,client_updated_at) values
(auth.uid(),'2026-09-01',20,'stale','2026-09-01T09:00:00Z')
on conflict(user_id,day) do update set value=excluded.value,reason=excluded.reason,client_updated_at=excluded.client_updated_at;
select public.assert((select value=70 from public.scores),'S5 stale offline write does not overwrite newer value');
update public.scores set value=91,reason='edited',client_updated_at='2026-09-01T11:00:00Z';
select public.assert((select value=91 and reason='edited' from public.scores),'S6 own score and reason editable');
update public.scores set deleted_at='2026-09-01T12:00:00Z',client_updated_at='2026-09-01T12:00:00Z';
select public.assert((select deleted_at is not null from public.scores),'S7 deletion tombstone retained for sync');
reset role;
delete from auth.users where id='33333333-3333-3333-3333-333333333333';
select public.assert((select count(*)=0 from public.scores),'S8 account deletion cascades private records');
rollback;
