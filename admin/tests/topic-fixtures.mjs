// Isolated browser fixtures. Never connects to a real backend.
import http from 'node:http';
import { randomUUID } from 'node:crypto';
const stamp = new Date().toISOString();
const topics = [{id:randomUUID(),title:'주 4일 근무 도입에 찬성하나요?',subtitle:'함께 장단점을 논의해요.',category:'work',status:'live',created_at:stamp}];
const submissions = [{id:randomUUID(),title:'주 4일 재택근무 도입에 찬성하나요?',subtitle:'출퇴근 시간을 줄이고 집중할 수 있는 환경에 대해 함께 논의해요.',category:'work',kind:'discussion',source_url:null,score_low_label:'반대',score_high_label:'찬성',status:'pending',revision:1,review_reason:null,created_at:stamp}];
const reports=[{id:randomUUID(),target_id:topics[0].id,reason:'abuse',detail:'질문 표현을 검토해 주세요.'}];
http.createServer(async(req,res)=>{
  let raw=''; for await(const chunk of req) raw+=chunk;
  const u=new URL(req.url,'http://localhost');const table=u.pathname.split('/').pop();
  res.setHeader('Content-Type','application/json');
  if(req.method==='GET') { res.end(JSON.stringify(table==='topics'?topics:table==='topic_submissions'?submissions:table==='reports'?reports:[]));return; }
  const body=JSON.parse(raw||'{}');
  if(table==='review_topic_proposal') {
    const s=submissions.find(s=>s.id===body.p_id);
    if(s && s.status==='pending' && s.revision===body.p_revision) {
      s.status=body.p_action;s.review_reason=body.p_reason;s.revision++;
      if(s.status==='approved') topics.push({id:randomUUID(),title:s.title,subtitle:s.subtitle,category:s.category,status:'live',created_at:stamp});
    }
    res.end(JSON.stringify(s));return;
  }
  if(table==='resolve_topic_report') {
    const i=reports.findIndex(r=>r.id===body.p_id);
    if(i>=0){if(body.p_hide)topics.find(t=>t.id===reports[i].target_id).status='hidden';reports.splice(i,1);}
    res.end('null');return;
  }
  res.writeHead(404);res.end('{}');
}).listen(4319,'127.0.0.1',()=>console.log('Topic browser fixtures: 127.0.0.1:4319'));
