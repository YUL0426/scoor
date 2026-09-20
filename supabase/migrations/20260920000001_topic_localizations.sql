begin;

-- Canonical Korean copy remains unchanged for old clients and Korean users.
alter table public.topics add column translations jsonb not null default '{}'::jsonb;
comment on column public.topics.translations is 'Editorial translations by app locale: title, subtitle, score_low_label, score_high_label. Korean uses canonical columns.';

create function public.valid_topic_translations(value jsonb) returns boolean
language plpgsql immutable set search_path=public,pg_temp as $$
declare item record; field text;
begin
 if jsonb_typeof(value) is distinct from 'object' then return false; end if;
 for item in select * from jsonb_each(value) loop
  if item.key not in ('en','ja','zh-Hans','de','fr','pt-BR','es') or jsonb_typeof(item.value) is distinct from 'object' then return false; end if;
  if exists(select 1 from jsonb_object_keys(item.value) k where k not in ('title','subtitle','score_low_label','score_high_label')) then return false; end if;
  foreach field in array array['title','score_low_label','score_high_label'] loop
   if jsonb_typeof(item.value->field) is distinct from 'string' or char_length(btrim(item.value->>field)) not between 1 and (case when field='title' then 160 else 80 end) then return false; end if;
  end loop;
  if item.value->>'score_low_label'=item.value->>'score_high_label' then return false; end if;
  if item.value ? 'subtitle' and item.value->'subtitle'<>'null'::jsonb and
   (jsonb_typeof(item.value->'subtitle') is distinct from 'string' or char_length(item.value->>'subtitle')>500) then return false; end if;
 end loop;
 return true;
end $$;
alter table public.topics add constraint topics_translations_valid check(public.valid_topic_translations(translations));

-- Backfill only matching editorial originals; never rewrite the question or activity.
do $backfill$
declare source jsonb;
begin
 for source in select * from jsonb_array_elements($data$[
  {
    "id": "79fa6cb6-adbe-4127-850a-fb95bd094107",
    "origin": "admin",
    "score_high_label": "긍정적",
    "score_low_label": "부정적",
    "status": "live",
    "subtitle": "설렘부터 권태까지",
    "title": "지금 내 연애 온도",
    "translations": {
      "en": {
        "title": "My love life right now",
        "subtitle": "From butterflies to feeling stuck",
        "score_low_label": "Negative",
        "score_high_label": "Positive"
      },
      "ja": {
        "title": "今の恋愛の温度",
        "subtitle": "ときめきからマンネリまで",
        "score_low_label": "ネガティブ",
        "score_high_label": "ポジティブ"
      },
      "zh-Hans": {
        "title": "此刻我的恋爱温度",
        "subtitle": "从心动到倦怠",
        "score_low_label": "负面",
        "score_high_label": "正面"
      },
      "de": {
        "title": "Wie sich mein Liebesleben gerade anfühlt",
        "subtitle": "Von Schmetterlingen im Bauch bis zur Routine",
        "score_low_label": "Negativ",
        "score_high_label": "Positiv"
      },
      "fr": {
        "title": "Ma vie amoureuse en ce moment",
        "subtitle": "Des premiers frissons à la routine",
        "score_low_label": "Négatif",
        "score_high_label": "Positif"
      },
      "pt-BR": {
        "title": "Minha vida amorosa agora",
        "subtitle": "Do frio na barriga à rotina",
        "score_low_label": "Negativo",
        "score_high_label": "Positivo"
      },
      "es": {
        "title": "Mi vida amorosa ahora",
        "subtitle": "De las mariposas a la rutina",
        "score_low_label": "Negativo",
        "score_high_label": "Positivo"
      }
    }
  },
  {
    "id": "16a61c4f-b665-45b6-afa4-bc7791922adc",
    "origin": "admin",
    "score_high_label": "긍정적",
    "score_low_label": "부정적",
    "status": "live",
    "subtitle": "공부하는 사람들의 실시간 감정",
    "title": "시험 기간 멘탈",
    "translations": {
      "en": {
        "title": "Exam-season mindset",
        "subtitle": "How people studying are feeling right now",
        "score_low_label": "Negative",
        "score_high_label": "Positive"
      },
      "ja": {
        "title": "試験期間中のメンタル",
        "subtitle": "勉強している人たちの今の気持ち",
        "score_low_label": "ネガティブ",
        "score_high_label": "ポジティブ"
      },
      "zh-Hans": {
        "title": "考试季的心态",
        "subtitle": "正在学习的人们此刻的心情",
        "score_low_label": "负面",
        "score_high_label": "正面"
      },
      "de": {
        "title": "Stimmung in der Prüfungszeit",
        "subtitle": "Wie sich Lernende gerade fühlen",
        "score_low_label": "Negativ",
        "score_high_label": "Positiv"
      },
      "fr": {
        "title": "Le moral pendant les examens",
        "subtitle": "Le ressenti du moment de ceux qui étudient",
        "score_low_label": "Négatif",
        "score_high_label": "Positif"
      },
      "pt-BR": {
        "title": "O ânimo na época de provas",
        "subtitle": "Como quem está estudando se sente agora",
        "score_low_label": "Negativo",
        "score_high_label": "Positivo"
      },
      "es": {
        "title": "El ánimo en época de exámenes",
        "subtitle": "Cómo se sienten ahora quienes están estudiando",
        "score_low_label": "Negativo",
        "score_high_label": "Positivo"
      }
    }
  },
  {
    "id": "350296d1-a780-457d-b8d4-14fd8ea706ea",
    "origin": "admin",
    "score_high_label": "긍정적",
    "score_low_label": "부정적",
    "status": "live",
    "subtitle": "새벽에 깨어 있는 사람들의 점수",
    "title": "오늘 밤, 잠이 안 오는 이유",
    "translations": {
      "en": {
        "title": "What's keeping you up tonight?",
        "subtitle": "Scores from people still awake late at night",
        "score_low_label": "Negative",
        "score_high_label": "Positive"
      },
      "ja": {
        "title": "今夜、眠れない理由",
        "subtitle": "夜更けに起きている人たちのスコア",
        "score_low_label": "ネガティブ",
        "score_high_label": "ポジティブ"
      },
      "zh-Hans": {
        "title": "今晚睡不着的理由",
        "subtitle": "深夜还醒着的人们的评分",
        "score_low_label": "负面",
        "score_high_label": "正面"
      },
      "de": {
        "title": "Was hält dich heute Nacht wach?",
        "subtitle": "Scores von Menschen, die nachts noch wach sind",
        "score_low_label": "Negativ",
        "score_high_label": "Positiv"
      },
      "fr": {
        "title": "Qu’est-ce qui vous tient éveillé ce soir ?",
        "subtitle": "Les scores de ceux qui veillent tard dans la nuit",
        "score_low_label": "Négatif",
        "score_high_label": "Positif"
      },
      "pt-BR": {
        "title": "O que não deixa você dormir esta noite?",
        "subtitle": "Notas de quem ainda está acordado de madrugada",
        "score_low_label": "Negativo",
        "score_high_label": "Positivo"
      },
      "es": {
        "title": "¿Qué no te deja dormir esta noche?",
        "subtitle": "Puntuaciones de quienes siguen despiertos de madrugada",
        "score_low_label": "Negativo",
        "score_high_label": "Positivo"
      }
    }
  },
  {
    "id": "f71f02ed-efa1-435a-a6c6-35936f1ee100",
    "origin": "admin",
    "score_high_label": "긍정적",
    "score_low_label": "부정적",
    "status": "live",
    "subtitle": "월요일부터 지금까지, 몇 점인가요",
    "title": "이번 주 직장 컨디션",
    "translations": {
      "en": {
        "title": "How work feels this week",
        "subtitle": "From Monday until now, what score would you give it?",
        "score_low_label": "Negative",
        "score_high_label": "Positive"
      },
      "ja": {
        "title": "今週の仕事の調子",
        "subtitle": "月曜日から今まで、何点ですか？",
        "score_low_label": "ネガティブ",
        "score_high_label": "ポジティブ"
      },
      "zh-Hans": {
        "title": "这周的工作状态",
        "subtitle": "从周一到现在，你会打几分？",
        "score_low_label": "负面",
        "score_high_label": "正面"
      },
      "de": {
        "title": "Wie sich die Arbeit diese Woche anfühlt",
        "subtitle": "Von Montag bis jetzt: Wie viele Punkte gibst du?",
        "score_low_label": "Negativ",
        "score_high_label": "Positiv"
      },
      "fr": {
        "title": "Le travail cette semaine",
        "subtitle": "De lundi à maintenant, quelle note donneriez-vous ?",
        "score_low_label": "Négatif",
        "score_high_label": "Positif"
      },
      "pt-BR": {
        "title": "Como está o trabalho nesta semana",
        "subtitle": "De segunda-feira até agora, que nota você daria?",
        "score_low_label": "Negativo",
        "score_high_label": "Positivo"
      },
      "es": {
        "title": "Cómo va el trabajo esta semana",
        "subtitle": "Desde el lunes hasta ahora, ¿qué puntuación le darías?",
        "score_low_label": "Negativo",
        "score_high_label": "Positivo"
      }
    }
  },
  {
    "id": "5146e9ff-af38-4e5a-9adc-188c09d922db",
    "origin": "admin",
    "score_high_label": "긍정적",
    "score_low_label": "부정적",
    "status": "live",
    "subtitle": "세상 돌아가는 걸 점수로",
    "title": "요즘 뉴스 보면 드는 기분",
    "translations": {
      "en": {
        "title": "How the news makes me feel",
        "subtitle": "Score how you feel about what is happening in the world",
        "score_low_label": "Negative",
        "score_high_label": "Positive"
      },
      "ja": {
        "title": "最近のニュースを見て感じること",
        "subtitle": "世の中の動きをスコアで表そう",
        "score_low_label": "ネガティブ",
        "score_high_label": "ポジティブ"
      },
      "zh-Hans": {
        "title": "最近看新闻时的心情",
        "subtitle": "为世界上发生的事打个分",
        "score_low_label": "负面",
        "score_high_label": "正面"
      },
      "de": {
        "title": "Was die Nachrichten bei mir auslösen",
        "subtitle": "Bewerte, wie du das Weltgeschehen empfindest",
        "score_low_label": "Negativ",
        "score_high_label": "Positiv"
      },
      "fr": {
        "title": "Ce que les nouvelles me font ressentir",
        "subtitle": "Exprimez votre ressenti sur le monde avec un score",
        "score_low_label": "Négatif",
        "score_high_label": "Positif"
      },
      "pt-BR": {
        "title": "Como as notícias me fazem sentir",
        "subtitle": "Dê uma nota ao que você sente sobre os acontecimentos no mundo",
        "score_low_label": "Negativo",
        "score_high_label": "Positivo"
      },
      "es": {
        "title": "Cómo me hacen sentir las noticias",
        "subtitle": "Puntúa lo que sientes sobre lo que pasa en el mundo",
        "score_low_label": "Negativo",
        "score_high_label": "Positivo"
      }
    }
  },
  {
    "id": "6cf706a4-0ec0-4342-9ab1-42397b3e1866",
    "origin": "admin",
    "score_high_label": "긍정적",
    "score_low_label": "부정적",
    "status": "draft",
    "subtitle": "지수 보고 드는 기분",
    "title": "코스피 요새 상황",
    "translations": {
      "en": {
        "title": "The KOSPI lately",
        "subtitle": "How the index makes you feel",
        "score_low_label": "Negative",
        "score_high_label": "Positive"
      },
      "ja": {
        "title": "最近のKOSPIの動き",
        "subtitle": "指数を見て感じること",
        "score_low_label": "ネガティブ",
        "score_high_label": "ポジティブ"
      },
      "zh-Hans": {
        "title": "韩国综合股价指数近况",
        "subtitle": "看到指数时的心情",
        "score_low_label": "负面",
        "score_high_label": "正面"
      },
      "de": {
        "title": "Der KOSPI in letzter Zeit",
        "subtitle": "Wie du dich beim Blick auf den Index fühlst",
        "score_low_label": "Negativ",
        "score_high_label": "Positiv"
      },
      "fr": {
        "title": "Le KOSPI ces derniers temps",
        "subtitle": "Ce que cet indice vous fait ressentir",
        "score_low_label": "Négatif",
        "score_high_label": "Positif"
      },
      "pt-BR": {
        "title": "O KOSPI ultimamente",
        "subtitle": "Como você se sente ao olhar o índice",
        "score_low_label": "Negativo",
        "score_high_label": "Positivo"
      },
      "es": {
        "title": "El KOSPI últimamente",
        "subtitle": "Cómo te sientes al ver el índice",
        "score_low_label": "Negativo",
        "score_high_label": "Positivo"
      }
    }
  }
]$data$::jsonb) loop
  if exists(select 1 from public.topics where id=(source->>'id')::uuid and
    (origin,title,subtitle,score_low_label,score_high_label) is distinct from
    ('admin'::text,source->>'title',source->>'subtitle',source->>'score_low_label',source->>'score_high_label')) then
   raise exception 'Topic source changed; review translations before applying: %',source->>'id';
  end if;
  update public.topics set translations=source->'translations'
   where origin='admin' and title=source->>'title' and subtitle is not distinct from source->>'subtitle'
    and score_low_label=source->>'score_low_label' and score_high_label=source->>'score_high_label';
 end loop;
end $backfill$;

create function public.guard_topic_translations() returns trigger
language plpgsql set search_path=public,pg_temp as $$
begin
 if tg_op='UPDATE' then
  if (new.title,new.subtitle,new.score_low_label,new.score_high_label) is distinct from
     (old.title,old.subtitle,old.score_low_label,old.score_high_label) then
   new.translations='{}'::jsonb;
  end if;
 end if;
 if new.origin='admin' and new.status in ('live','closed') and not
    (new.translations ?& array['en','ja','zh-Hans','de','fr','pt-BR','es']) then
  raise exception 'Complete all seven topic translations before publishing' using errcode='23514';
 end if;
 if new.origin='admin' and new.status in ('live','closed') and coalesce(btrim(new.subtitle),'')<>'' and exists(
  select 1 from jsonb_each(new.translations) entry where coalesce(btrim(entry.value->>'subtitle'),'')='') then
  raise exception 'Translate the topic description before publishing' using errcode='23514';
 end if;
 return new;
end $$;
create trigger topics_translation_guard before insert or update on public.topics
 for each row execute function public.guard_topic_translations();

-- Keep the existing visibility/block rules and column order; append translations.
create or replace view public.topics_feed as
select t.id,t.category,t.title,t.subtitle,t.cover_emoji,t.status,t.created_at,
 coalesce(s.posts_count,0) as posts_count,coalesce(s.global_score,0) as global_score,
 coalesce(s.score_delta,0) as score_delta,coalesce(s.last_activity_at,t.created_at) as last_activity_at,
 t.origin,t.proposed_by,t.source_url,t.score_low_label,t.score_high_label,p.username as proposer_name,
 t.translations
from public.topics t left join public.topic_stats s on s.topic_id=t.id
left join public.profiles p on p.id=t.proposed_by
where t.status in ('live','closed') and not exists(select 1 from public.blocks b where b.blocker_id=auth.uid() and b.blocked_id=t.proposed_by);

create function public.search_localized_topics(p_query text,p_language text default 'en')
returns setof public.topics_feed language sql stable security invoker set search_path=public,pg_temp as $$
 select t.* from public.topics_feed t
 where char_length(btrim(p_query))>0 and
 (case when p_language='ko' then t.title else coalesce(nullif(t.translations->p_language->>'title',''),nullif(t.translations->'en'->>'title',''),t.title) end)
 ilike '%' || replace(replace(replace(left(btrim(p_query),160),E'\\',E'\\\\'), '%',E'\\%'),'_',E'\\_') || '%'
 order by t.created_at desc,t.id desc limit 20
$$;
revoke all on function public.search_localized_topics(text,text) from public;
grant execute on function public.search_localized_topics(text,text) to anon,authenticated,service_role;
notify pgrst,'reload schema';
commit;
