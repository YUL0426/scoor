-- Run inside a transaction after the localization migration, then roll back.
do $$
declare original_count integer; example jsonb; test_id uuid := gen_random_uuid();
begin
 if public.valid_topic_translations('[]') or public.valid_topic_translations('{"xx":{}}')
  or public.valid_topic_translations('{"en":{"title":"x","score_low_label":"same","score_high_label":"same"}}') then
  raise exception 'Invalid translations accepted';
 end if;
 select translations into example from public.topics where id='16a61c4f-b665-45b6-afa4-bc7791922adc';
 if example is null or not example ?& array['en','ja','zh-Hans','de','fr','pt-BR','es'] then raise exception 'Seed translations missing'; end if;
 if not exists(select 1 from public.search_localized_topics('Exam-season','en') where id='16a61c4f-b665-45b6-afa4-bc7791922adc') then raise exception 'English search missing'; end if;
 if not exists(select 1 from public.search_localized_topics('試験','ja') where id='16a61c4f-b665-45b6-afa4-bc7791922adc') then raise exception 'Japanese search missing'; end if;
 if not exists(select 1 from public.search_localized_topics('시험','ko') where id='16a61c4f-b665-45b6-afa4-bc7791922adc') then raise exception 'Korean search missing'; end if;
 if exists(select 1 from public.search_localized_topics('%','en')) then raise exception 'Search wildcard was not escaped'; end if;
 if exists(select 1 from public.search_localized_topics('The KOSPI','en')) then raise exception 'Draft leaked into search'; end if;
 insert into public.topics(id,category,title,subtitle,status,translations) values(test_id,'work','QA translation rollback','원문','draft',example);
 begin
  update public.topics set translations='{}',status='live' where id=test_id;
  raise exception 'Incomplete topic published';
 exception when check_violation then null; end;
 update public.topics set status='live' where id=test_id;
 begin
  update public.topics set title='바뀐 질문' where id=test_id;
  raise exception 'Stale translation survived a live source edit';
 exception when check_violation then null; end;
 update public.topics set status='draft' where id=test_id;
 update public.topics set title='바뀐 질문' where id=test_id;
 if (select translations <> '{}'::jsonb from public.topics where id=test_id) then raise exception 'Draft source edit did not invalidate translations'; end if;
 delete from public.topics where id=test_id;
 raise notice 'PASS topic translation validation, publication guard, source invalidation, localized search and draft visibility';
end $$;
set local role anon;
do $$ begin
 if not exists(select 1 from public.topics_feed where translations->'en'->>'title'='Exam-season mindset') then raise exception 'Anonymous feed cannot read translations'; end if;
 begin
  update public.topics set translations='{}' where id='16a61c4f-b665-45b6-afa4-bc7791922adc';
  raise exception 'Anonymous client can edit translations';
 exception when insufficient_privilege then null; end;
 raise notice 'PASS public read and operator-only write';
end $$;
reset role;
