/** Run against a separately started LOCAL admin server with QA-only credentials.
 * ADMIN_AUDIT_URL=http://127.0.0.1:3108 ADMIN_AUDIT_EMAIL=... ADMIN_AUDIT_PASSWORD=...
 * ADMIN_AUDIT_SECRET=... node tests/auth-smoke.mjs
 * Never sends an authorized content mutation; validates rejection paths only.
 */
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
const base = process.env.ADMIN_AUDIT_URL;
assert(base && ['127.0.0.1','localhost'].includes(new URL(base).hostname), 'Local server required');
const email = process.env.ADMIN_AUDIT_EMAIL, password = process.env.ADMIN_AUDIT_PASSWORD;
const secret = process.env.ADMIN_AUDIT_SECRET;
assert(email && password && secret, 'QA credentials required');
let count = 0;
async function check(path, expected, options = {}) {
  const response = await fetch(new URL(path, base), { redirect:'manual', ...options });
  assert.equal(response.status, expected, `${options.method || 'GET'} ${path}`);
  count++;
  return response;
}
const body = (value) => ({method:'POST',headers:{'Content-Type':'application/json',Origin:base},body:JSON.stringify(value)});
for (const path of ['/api/topics','/api/feed','/api/auth/session']) await check(path,401);
await check('/admin/topics',307);
await check('/api/auth/login',400,body({email:12,password:[]}));
await check('/api/auth/login',401,body({email,password:'incorrect'}));
await check('/api/auth/login',403,{...body({email,password}),headers:{Origin:'https://untrusted.example','Content-Type':'application/json'}});
const login = await check('/api/auth/login',200,body({email,password}));
const setCookie = login.headers.get('set-cookie');
assert.match(setCookie,/HttpOnly/i);assert.match(setCookie,/SameSite=lax/i);
const cookie = setCookie.split(';')[0], token = cookie.split('=')[1];
const headers = {Cookie:cookie, Origin:base,'Content-Type':'application/json'};
await check('/api/auth/session',200,{headers});
for (const path of ['/api/topics','/api/feed']) await check(path,200,{headers});
await check('/api/topics',403,{method:'POST',headers:{...headers,Origin:'https://untrusted.example'},body:'{}'});
await check('/api/auth/logout',403,{method:'POST',headers:{...headers,'sec-fetch-site':'cross-site'}});
for (const [path,method,data] of [
 ['/api/topics','POST',{}],['/api/feed','POST',{score:101,message:'Invalid'}],
 ['/api/topics/not-a-uuid','PATCH',{status:'live'}],['/api/feed/not-a-uuid','PATCH',{isHidden:true}],
 ['/api/feed/not-a-uuid','DELETE',null],
 ['/api/feed/00000000-0000-0000-0000-000000000001','PATCH',{isHidden:'true'}],
]) await check(path,400,{method,headers,body:data ? JSON.stringify(data):undefined});
for (const method of ['POST','PATCH','DELETE']) {
 const path = method==='POST'?'/api/feed':'/api/feed/00000000-0000-0000-0000-000000000001';
 await check(path,401,{method,body:'{}'});
}
const sign = (payload) => { const b=Buffer.from(JSON.stringify(payload)).toString('base64url');return `${b}.${createHmac('sha256',secret).update(b).digest('base64url')}`;};
for (const invalid of [token+'.extra','invalid.token',sign({email,exp:Date.now()-1000}),sign({email:'different@example.test',exp:Date.now()+60000}),sign({email,exp:'forever'})]) {
 const h={Cookie:`scoor_admin_session=${invalid}`};
 await check('/api/auth/session',401,{headers:h});await check('/api/topics',401,{headers:h});await check('/admin',307,{headers:h});
}
const logout=await check('/api/auth/logout',200,{method:'POST',headers});
assert.match(logout.headers.get('set-cookie'),/Max-Age=0/i);
await check('/api/auth/session',401);
console.log(`PASS ${count} HTTP checks; cookie attributes verified; no authorized content writes.`);
