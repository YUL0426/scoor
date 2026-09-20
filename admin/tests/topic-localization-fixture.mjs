// Isolated test backend. Never forwards requests or uses production credentials.
import http from 'node:http';
import { readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
const topics = JSON.parse(readFileSync(new URL('../../supabase/seed/topic-translations.json', import.meta.url))).map(row => ({ ...row, category: 'work', created_at: new Date().toISOString() }));
http.createServer(async (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  const url = new URL(req.url, 'http://127.0.0.1');
  const table = url.pathname.split('/').pop();
  if (table === 'topic_stats') { res.end('[]'); return; }
  if (table !== 'topics') { res.writeHead(404); res.end('{}'); return; }
  if (req.method === 'GET') { res.end(JSON.stringify(topics)); return; }
  let raw = ''; for await (const chunk of req) raw += chunk;
  const payload = JSON.parse(raw || '{}');
  if (req.method === 'POST') {
    const row = { ...payload[0], id: randomUUID(), origin: 'admin', score_low_label: '부정적', score_high_label: '긍정적', created_at: new Date().toISOString() };
    topics.push(row); res.writeHead(201); res.end(JSON.stringify([row])); return;
  }
  if (req.method === 'PATCH') {
    const topic = topics.find(row => `eq.${row.id}` === url.searchParams.get('id'));
    if (!topic) { res.end('[]'); return; }
    const updated = { ...topic, ...payload };
    if (['live', 'closed'].includes(updated.status) && Object.keys(updated.translations ?? {}).length !== 7) {
      res.writeHead(400); res.end(JSON.stringify({ message: 'Complete all seven topic translations before publishing' })); return;
    }
    Object.assign(topic, payload); res.end(JSON.stringify([topic])); return;
  }
  res.writeHead(405); res.end('{}');
}).listen(4329, '127.0.0.1', () => console.log('Topic localization fixtures at 127.0.0.1:4329'));
