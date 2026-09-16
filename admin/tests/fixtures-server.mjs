import http from 'node:http';
import {randomUUID} from 'node:crypto';
const stamp='2026-09-06T04:00:00.000Z';
let topics=[['지금 내 연애 온도','love','❤️','live'],['이번 주 직장 컨디션','work','💼','live'],['오늘 밤, 잠이 안 오는 이유','night','🌙','live'],['요즘 뉴스 보면 드는 기분','society','☁️','draft'],['시험 기간 멘탈','students','📚','closed']].map(([title,category,cover_emoji,status])=>({id:randomUUID(),title,category,cover_emoji,status,subtitle:'브라우저 검증용 토픽',starts_at:null,ends_at:null,created_at:stamp}));
let posts=[['오늘 하루, 여러분의 점수는 몇 점인가요?',72,false],['작은 성취 하나를 떠올려 보세요. 그 순간의 점수를 기록해 주세요.',86,false],['잠시 쉬어 가도 괜찮아요. 오늘의 나에게 한 줄을 남겨 보세요.',65,false],['새로운 한 주를 준비하는 마음',77,true]].map(([message,score,is_hidden])=>({id:randomUUID(),is_official:true,score,message,primary_mood:'calm',extra_moods:[],weather:null,author_name:'Scoor',is_hidden,deleted_at:null,created_at:stamp,likes_count:0,comments_count:0}));
let fail=false;const writes=[];
http.createServer(async(req,res)=>{let buf='';for await(const x of req)buf+=x;const u=new URL(req.url,'http://localhost');res.setHeader('Content-Type','application/json');
if(u.pathname==='/__state'){res.end(JSON.stringify({topics,posts,writes}));return;}
if(u.pathname==='/__fail'){fail=u.searchParams.get('on')==='1';res.end('{}');return;}
if(fail){res.writeHead(503);res.end(JSON.stringify({message:'테스트 연결 오류'}));return;}
const table=u.pathname.split('/').pop();if(!['topics','topic_stats','feed_posts','posts'].includes(table)){res.writeHead(404);res.end('{}');return;}
let list=table==='topics'?topics:table==='topic_stats'?topics.map(t=>({topic_id:t.id,posts_count:0,global_score:0})):posts;
if(req.method==='GET'){res.end(JSON.stringify(list));return;}
writes.push({method:req.method,table});
if(req.method==='POST'){const row={id:randomUUID(),created_at:new Date().toISOString(),starts_at:null,ends_at:null,subtitle:null,cover_emoji:null,is_hidden:false,deleted_at:null,likes_count:0,comments_count:0,author_name:'Scoor',...JSON.parse(buf)[0]};list.push(row);res.end(JSON.stringify([row]));return;}
const id=u.searchParams.get('id')?.slice(3);const row=list.find(r=>r.id===id);if(row)Object.assign(row,JSON.parse(buf));res.end(JSON.stringify(row?[row]:[]));
}).listen(4312,'127.0.0.1',()=>console.log('Isolated QA backend on 4312'));
