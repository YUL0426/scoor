// Run only against an isolated local admin with topic-fixtures.mjs and QA auth.
import assert from 'node:assert/strict';
const base=process.env.TOPIC_QA_URL;
assert(base && ['127.0.0.1','localhost'].includes(new URL(base).hostname),'Local QA server required');
let count=0;
async function check(path,status,options={}) { const r=await fetch(base+path,options);assert.equal(r.status,status,`${path}: ${await r.clone().text()}`);count++;return r; }
for(const path of ['/api/topic-submissions','/api/topic-reports']) {
 await check(path,401);await check(path,401,{method:'POST',body:'{}'});
}
const login=await check('/api/auth/login',200,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:'qa@example.test',password:'topic-qa-password'})});
const cookie=login.headers.get('set-cookie').split(';')[0];
const headers={Cookie:cookie,'Content-Type':'application/json'};
for(const path of ['/api/topic-submissions','/api/topic-reports']) {
 await check(path,200,{headers});
 await check(path,403,{method:'POST',headers:{...headers,Origin:'https://untrusted.example'},body:'{}'});
 await check(path,400,{method:'POST',headers,body:'{}'});
 await check(path,400,{method:'POST',headers,body:'null'});
}
await check('/api/topic-submissions',400,{method:'POST',headers,body:JSON.stringify({id:'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',revision:1,action:'rejected',reason:''})});
console.log(`PASS ${count} topic API authentication, origin, and validation checks`);
