"use client";
import { useEffect, useState } from "react";
import type { AdminTopic } from "@/types";
type Report = { id: string; target_id: string; reason: string; detail: string | null };
export function TopicReportsClient() {
  const [reports, setReports] = useState<Report[]>([]);
  const [topics, setTopics] = useState<AdminTopic[]>([]);
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [revision, setRevision] = useState(0);
  useEffect(() => {
    let cancelled = false;
    Promise.all([fetch("/api/topic-reports"), fetch("/api/topics")]).then(async ([a,b]) => {
      const [r,t] = await Promise.all([a.json(),b.json()]);
      if (!a.ok || !b.ok) throw new Error(r.error ?? t.error);
      if (!cancelled) { setReports(r.reports); setTopics(t.topics); }
    }).catch(e => { if (!cancelled) setError(e.message); }).finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, [revision]);
  async function resolve(id: string, hide: boolean) {
    setBusy(true); setError("");
    try {
      const r = await fetch("/api/topic-reports", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ id, hide }) });
      const body = await r.json(); if (!r.ok) throw new Error(body.error);
      setReports(rows => rows.filter(row => row.id !== id));
      window.dispatchEvent(new Event("topics-updated"));
    } catch (e) { setError(e instanceof Error ? e.message : "처리 실패"); }
    finally { setBusy(false); }
  }
  return <section className="mb-8 rounded-xl border border-white/10 p-5" aria-label="토픽 신고">
    <div className="flex items-center justify-between"><h2 className="text-lg font-semibold">토픽 신고</h2>
      <button className="ui-button" onClick={() => { setError(""); setLoading(true); setRevision(n => n+1); }}>새로고침</button></div>
    {error && <p role="alert" className="text-red-300">{error}</p>}
    {loading ? <p role="status" className="py-4">불러오는 중…</p> : reports.length === 0 && <p className="py-4 text-white/50">검토할 신고가 없습니다.</p>}
    {reports.map(report => { const topic = topics.find(t => t.id === report.target_id); return <article key={report.id} className="border-t border-white/10 py-4 space-y-2">
      <h3 className="font-semibold">{topic?.title ?? `토픽 ${report.target_id}`}</h3>
      {topic && <p className="text-sm text-white/60">{topic.subtitle}</p>}
      <p className="text-sm">신고 사유: {report.reason}</p><p className="text-sm whitespace-pre-wrap">{report.detail}</p>
      <div className="flex gap-3"><button className="ui-button" disabled={busy} onClick={() => void resolve(report.id,true)}>토픽 숨김 및 처리</button>
        <button className="ui-button" disabled={busy} onClick={() => void resolve(report.id,false)}>문제없음</button></div>
    </article>; })}
  </section>;
}
