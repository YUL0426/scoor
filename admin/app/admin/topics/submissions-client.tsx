"use client";
import { useEffect, useState } from "react";
import { TOPIC_CATEGORY_LABELS, type AdminTopic } from "@/types";

type Submission = {
  id: string; title: string; subtitle: string; category: string; kind: string;
  source_url: string | null; score_low_label: string; score_high_label: string;
  status: string; revision: number; review_reason: string | null; created_at: string;
};
const labels: Record<string, string> = { pending: "검토 중", changes_requested: "수정 요청", approved: "게시됨", rejected: "반려", duplicate: "중복 연결", withdrawn: "철회" };

export function SubmissionsClient() {
  const [rows, setRows] = useState<Submission[]>([]);
  const [topics, setTopics] = useState<AdminTopic[]>([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState("pending");
  const [reload, setReload] = useState(0);
  useEffect(() => {
    let cancelled = false;
    Promise.all([fetch("/api/topic-submissions"), fetch("/api/topics")])
      .then(async ([a, b]) => {
        const [proposals, published] = await Promise.all([a.json(), b.json()]);
        if (!a.ok || !b.ok) throw new Error(proposals.error ?? published.error ?? "불러오지 못했습니다.");
        if (!cancelled) { setRows(proposals.submissions); setTopics(published.topics); }
      }).catch(e => { if (!cancelled) setError(e.message); })
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, [reload]);
  return <section className="mb-8 rounded-xl border border-white/10 p-5" aria-label="유저 토픽 제안">
    <div className="flex items-center justify-between gap-3 mb-4">
      <h2 className="text-lg font-semibold">유저 토픽 제안</h2>
      <button className="ui-button" onClick={() => { setLoading(true); setError(""); setReload(n => n + 1); }}>새로고침</button>
    </div>
    <p className="text-sm text-white/50 mb-4">질문의 중립성·출처·중복·개인 공격 여부를 확인하세요. 승인하면 월드에 즉시 게시되고 제안자에게 앱 내 알림이 전달됩니다.</p>
    <label className="text-sm">심사 상태 <select className="bg-neutral-900 rounded p-2 ml-2" value={filter} onChange={e => setFilter(e.target.value)}>
      <option value="all">전체 (최근 200건)</option>
      {Object.entries(labels).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
    </select></label>
    {error && <p role="alert" className="text-red-300 mt-3">{error}</p>}
    {loading ? <p role="status" className="py-6">불러오는 중…</p> : <div className="space-y-4 mt-4">
      {rows.filter(s => filter === "all" || s.status === filter).map(s => <ReviewCard key={`${s.id}-${s.revision}`} submission={s} topics={topics}
        onSaved={() => { setReload(n => n + 1); window.dispatchEvent(new Event("topics-updated")); }} />)}
      {!rows.some(s => filter === "all" || s.status === filter) && <p className="py-6 text-white/50">해당 상태의 제안이 없습니다.</p>}
    </div>}
  </section>;
}

function ReviewCard({ submission: s, topics, onSaved }: { submission: Submission; topics: AdminTopic[]; onSaved: () => void }) {
  const [action, setAction] = useState("approved");
  const [reason, setReason] = useState("");
  const [topicId, setTopicId] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  async function save() {
    setBusy(true); setError("");
    try {
      const response = await fetch("/api/topic-submissions", { method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ id: s.id, revision: s.revision, action, reason, topicId }) });
      const result = await response.json();
      if (!response.ok) throw new Error(result.error);
      onSaved();
    } catch (e) { setError(e instanceof Error ? e.message : "저장하지 못했습니다."); }
    finally { setBusy(false); }
  }
  return <article className="rounded-lg bg-white/5 p-4 space-y-3">
    <p className="text-xs text-white/50">{labels[s.status]} · {(TOPIC_CATEGORY_LABELS as Record<string, string>)[s.category] ?? s.category} · {s.kind === "news" ? "뉴스·사건" : "논의"}</p>
    <h3 className="font-semibold break-words">{s.title}</h3><p className="text-sm whitespace-pre-wrap break-words">{s.subtitle}</p>
    <p className="text-sm">0: {s.score_low_label} / 100: {s.score_high_label}</p>
    {s.source_url?.startsWith("https://") && <a className="text-sm underline break-all" href={s.source_url} target="_blank" rel="noopener noreferrer">출처 확인: {s.source_url}</a>}
    {s.review_reason && <p className="text-sm text-white/60">처리 사유: {s.review_reason}</p>}
    {s.status === "pending" && <fieldset disabled={busy} className="space-y-3">
      <label className="block text-sm">처리 결과 <select className="bg-neutral-900 rounded p-2 ml-2" value={action} onChange={e => setAction(e.target.value)}>
        <option value="approved">승인 및 게시</option><option value="changes_requested">수정 요청</option><option value="rejected">반려</option><option value="duplicate">기존 토픽으로 연결</option>
      </select></label>
      {action === "duplicate" && <label className="block text-sm">연결할 토픽 <select className="bg-neutral-900 rounded p-2 max-w-full" value={topicId} onChange={e => setTopicId(e.target.value)}>
        <option value="">토픽 선택</option>{topics.filter(t => ["live", "closed"].includes(t.status)).map(t => <option value={t.id} key={t.id}>{t.title}</option>)}
      </select></label>}
      <label className="block text-sm">제안자에게 전달할 사유 {action !== "approved" && "(필수)"}
        <textarea className="block w-full rounded bg-neutral-900 p-3 mt-1" maxLength={500} value={reason} onChange={e => setReason(e.target.value)} /></label>
      <button className="ui-button" onClick={() => void save()} disabled={busy || (action !== "approved" && !reason.trim()) || (action === "duplicate" && !topicId)}>{busy ? "처리 중…" : action === "approved" ? "승인하고 월드에 게시" : "처리 결과 저장"}</button>
    </fieldset>}
    {error && <p role="alert" className="text-red-300 text-sm">{error}</p>}
  </article>;
}
