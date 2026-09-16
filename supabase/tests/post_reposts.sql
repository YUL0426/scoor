-- Run after auth_shim and feed/repost migrations against an isolated database.
\set ON_ERROR_STOP on
begin;
create or replace function public.assert(cond boolean, label text) returns void
language plpgsql as $$ begin
 if cond then raise notice 'PASS %', label; else raise exception 'FAIL %', label; end if;
end $$;
insert into auth.users(id,email) values
('33333333-3333-3333-3333-333333333333','repost-a@example.invalid'),
('44444444-4444-4444-4444-444444444444','repost-b@example.invalid');
insert into public.posts(id,author_id,score,message,primary_mood) values
('aaaaaaaa-1111-1111-1111-111111111111','44444444-4444-4444-4444-444444444444',80,'original','calm');
set local role authenticated;
set local request.jwt.claim.sub='33333333-3333-3333-3333-333333333333';
insert into public.post_reposts(post_id,user_id) values ('aaaaaaaa-1111-1111-1111-111111111111',auth.uid());
insert into public.post_reposts(post_id,user_id) values ('aaaaaaaa-1111-1111-1111-111111111111',auth.uid())
on conflict(post_id,user_id) do update set post_id=excluded.post_id;
select public.assert((select reposts_count=1 and reposted_by_me from public.feed_posts where id='aaaaaaaa-1111-1111-1111-111111111111'),'idempotent repost and feed metadata');
set local request.jwt.claim.sub='44444444-4444-4444-4444-444444444444';
select public.assert((select not reposted_by_me from public.feed_posts where id='aaaaaaaa-1111-1111-1111-111111111111'),'other account does not inherit my repost');
delete from public.post_reposts where user_id='33333333-3333-3333-3333-333333333333';
select public.assert((select count(*)=1 from public.post_reposts),'cannot cancel another account repost');
do $$ begin
 insert into public.post_reposts(post_id,user_id) values ('aaaaaaaa-1111-1111-1111-111111111111','33333333-3333-3333-3333-333333333333');
 raise exception 'FAIL cross-account insert';
exception when insufficient_privilege then raise notice 'PASS cross-account insert denied'; end $$;
set local request.jwt.claim.sub='33333333-3333-3333-3333-333333333333';
insert into public.blocks(blocker_id,blocked_id) values(auth.uid(),'44444444-4444-4444-4444-444444444444');
select public.assert((select count(*)=0 from public.feed_posts where reposted_by_me),'blocked original omitted from repost list');
delete from public.blocks;
reset role;
update public.posts set is_hidden=true where id='aaaaaaaa-1111-1111-1111-111111111111';
set local role authenticated;
select public.assert((select count(*)=0 from public.feed_posts where reposted_by_me),'moderated original omitted from repost list');
delete from public.post_reposts where user_id=auth.uid();
reset role;
select public.assert((select count(*)=0 from public.post_reposts),'can cancel even after original is hidden');
update public.posts set is_hidden=false where id='aaaaaaaa-1111-1111-1111-111111111111';
set local role authenticated;
insert into public.post_reposts(post_id,user_id) values ('aaaaaaaa-1111-1111-1111-111111111111',auth.uid());
delete from public.post_reposts where user_id=auth.uid();
select public.assert((select reposts_count=0 and not reposted_by_me from public.feed_posts where id='aaaaaaaa-1111-1111-1111-111111111111'),'cancel restores metadata');
reset role;
rollback;
