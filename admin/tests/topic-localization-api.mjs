// Start topic-localization-fixture.mjs, then a local admin on 4330 with QA auth.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { parseTopicTranslations, TOPIC_LANGUAGES } from '../lib/topic-translations.ts';
const fixtures = JSON.parse(readFileSync(new URL('../../supabase/seed/topic-translations.json', import.meta.url)));
for (const row of fixtures) assert.equal(Object.keys(parseTopicTranslations(row.translations, true)).length, 7);
for (const bad of [null, [], { xx: {} }, { en: { title: 'incomplete' } }, { en: { title: 'same', score_low_label: 'x', score_high_label: 'x' } }]) assert.throws(() => parseTopicTranslations(bad));
assert.throws(() => parseTopicTranslations({}, true));
const base = process.env.TOPIC_QA_URL;
assert(base && ['127.0.0.1','localhost'].includes(new URL(base).hostname));
let count=0;
async function check(path,status,options={}) { const r=await fetch(base+path,options);assert.equal(r.status,status,`${path}: ${await r.clone().text()}`);count++;return r; }
await check('/api/topics',401);
await check(`/api/topics/${fixtures[0].id}`,401,{ method:'PATCH',body:'{}' });
const login=await check('/api/auth/login',200,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:'qa@example.test',password:'topic-qa-password'})});
const headers={Cookie:login.headers.get('set-cookie').split(';')[0],'Content-Type':'application/json'};
const result=await check('/api/topics',200,{headers});
assert.equal(Object.keys((await result.json()).topics[0].translations).length,Object.keys(TOPIC_LANGUAGES).length);
for (const payload of [null, [], { translations:null }, { translations:{xx:{}} }, { title:'changed original' }]) await check(`/api/topics/${fixtures[0].id}`,400,{method:'PATCH',headers,body:JSON.stringify(payload)});
await check(`/api/topics/${fixtures[0].id}`,403,{method:'PATCH',headers:{...headers,Origin:'https://untrusted.example'},body:'{}'});
await check('/api/topics',400,{method:'POST',headers,body:JSON.stringify({title:'Korean only',category:'work',status:'live'})});
const data={...fixtures[0].translations,en:{...fixtures[0].translations.en,title:'Updated QA translation'}};
await check(`/api/topics/${fixtures[0].id}`,200,{method:'PATCH',headers,body:JSON.stringify({translations:data})});
const updated=(await (await check('/api/topics',200,{headers})).json()).topics.find(row=>row.id===fixtures[0].id);
assert.equal(updated.title,fixtures[0].title);assert.equal(updated.translations.en.title,'Updated QA translation');
await check('/api/topics',201,{method:'POST',headers,body:JSON.stringify({title:'QA new localized topic',category:'work',status:'live',translations:fixtures[0].translations})});
await check(`/api/topics/00000000-0000-4000-8000-000000000001`,404,{method:'PATCH',headers,body:JSON.stringify({translations:data})});
console.log(`PASS ${count} API cases, seven-language validation, editable translation persistence, immutable original, auth and origin protection`);
