"use client";
import { useEffect, useState, useCallback } from "react";
import {
  Loader2,
  Plus,
  Eye,
  EyeOff,
  Archive,
  ListTodo,
  ArrowUpRight,
} from "lucide-react";
import { CreateDialog, ListToolbar } from "@/components/admin/content-tools";
import {
  TOPIC_CATEGORIES,
  TOPIC_CATEGORY_LABELS,
  type AdminTopic,
  type TopicStatus,
} from "@/types";
const categoryLabel = (raw: string) =>
  (TOPIC_CATEGORY_LABELS as Record<string, string>)[raw] ?? raw;
const statusLabel = { live: "공개", draft: "초안", closed: "마감", hidden: "숨김" };
async function fetchTopics(): Promise<AdminTopic[]> {
  const r = await fetch("/api/topics", { cache: "no-store" });
  const b = await r.json();
  if (!r.ok) throw new Error(b.error ?? "토픽을 불러오지 못했습니다.");
  return b.topics ?? [];
}
export function TopicsClient() {
  const [topics, setTopics] = useState<AdminTopic[]>([]),
    [isLoading, setIsLoading] = useState(true),
    [error, setError] = useState<string | null>(null);
  const [pendingId, setPendingId] = useState<string | null>(null),
    [query, setQuery] = useState(""),
    [filter, setFilter] = useState("all"),
    [createOpen, setCreateOpen] = useState(false),
    [notice, setNotice] = useState("");
  const load = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      setTopics(await fetchTopics());
    } catch (e) {
      setError(e instanceof Error ? e.message : "연결을 확인해 주세요.");
    } finally {
      setIsLoading(false);
    }
  }, []);
  useEffect(() => {
    let cancelled = false;
    fetchTopics()
      .then((rows) => {
        if (!cancelled) setTopics(rows);
      })
      .catch((e) => {
        if (!cancelled) setError(e.message);
      })
      .finally(() => {
        if (!cancelled) setIsLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);
  useEffect(() => {
    const refresh = () => { void load(); };
    window.addEventListener("topics-updated", refresh);
    return () => window.removeEventListener("topics-updated", refresh);
  }, [load]);
  async function setStatus(topic: AdminTopic, status: TopicStatus) {
    if (pendingId) return;
    setPendingId(topic.id);
    setError(null);
    setNotice("");
    try {
      const r = await fetch(`/api/topics/${topic.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ status }),
      });
      const b = await r.json();
      if (!r.ok) throw new Error(b.error ?? "상태를 변경하지 못했습니다.");
      setTopics((rows) =>
        rows.map((t) => (t.id === topic.id ? { ...t, status } : t)),
      );
      setNotice(
        `‘${topic.title}’ 토픽을 ${statusLabel[status]} 상태로 변경했습니다.`,
      );
    } catch (e) {
      setError(e instanceof Error ? e.message : "다시 시도해 주세요.");
    } finally {
      setPendingId(null);
    }
  }
  const count = (status: string) =>
    topics.filter((t) => t.status === status).length;
  const visible = topics.filter(
    (t) =>
      (filter === "all" || t.status === filter) &&
      `${t.title} ${t.subtitle ?? ""} ${categoryLabel(t.category)}`
        .toLowerCase()
        .includes(query.toLowerCase()),
  );
  return (
    <div>
      <div className="page-intro">
        <div>
          <p className="ui-kicker !mb-1">콘텐츠 / WORLD</p>
          <h2>월드 토픽</h2>
          <p>사람들이 오늘의 생각을 나눌 주제를 관리하세요.</p>
        </div>
        <CreateDialog
          title="새 토픽"
          description="초안으로 준비하고, 공개할 때 앱에 노출하세요."
          open={createOpen}
          onOpenChange={setCreateOpen}
        >
          <CreateTopicForm
            onCreated={async () => {
              setCreateOpen(false);
              setNotice("새 토픽을 만들었습니다.");
              await load();
            }}
          />
        </CreateDialog>
      </div>
      <div className="ui-summary">
        {[
          { label: "공개 중", value: count("live") },
          { label: "작성 중인 초안", value: count("draft") },
          { label: "마감된 토픽", value: count("closed") },
        ].map((s) => (
          <div key={s.label}>
            <p>{s.label}</p>
            <strong>{isLoading || error ? "—" : s.value}</strong>
          </div>
        ))}
      </div>
      {error && (
        <div role="alert" className="ui-error mb-4">
          {error}
          <button className="ui-button ml-auto" onClick={() => void load()}>
            다시 시도
          </button>
        </div>
      )}
      {notice && (
        <p role="status" className="mb-4 text-xs text-[#8ccbb0]">
          {notice}
        </p>
      )}
      <section className="ui-panel" aria-label="토픽 목록">
        <ListToolbar
          query={query}
          onQuery={setQuery}
          filter={filter}
          onFilter={setFilter}
          tabs={[
            { value: "all", label: "전체", count: topics.length },
            ...(["live", "draft", "closed", "hidden"] as TopicStatus[]).map((s) => ({
              value: s,
              label: statusLabel[s],
              count: count(s),
            })),
          ]}
          loading={isLoading}
          onRefresh={() => void load()}
        />
        <div className="flex items-center justify-between px-[18px] py-2.5 text-[11px] text-text-tertiary">
          <span>토픽</span>
          <span className="hidden sm:block">참여 · 상태 · 작업</span>
        </div>
        {isLoading ? (
          <div className="ui-empty" role="status">
            <Loader2 size={20} className="animate-spin" />
            토픽을 불러오는 중
          </div>
        ) : error && !topics.length ? (
          <div className="ui-empty">
            <strong>토픽을 확인할 수 없습니다</strong>
            <span>연결을 확인한 뒤 다시 시도해 주세요.</span>
          </div>
        ) : !visible.length ? (
          <div className="ui-empty">
            <ListTodo size={25} strokeWidth={1.3} />
            <strong>
              {topics.length
                ? "일치하는 토픽이 없습니다"
                : "첫 토픽을 준비해 보세요"}
            </strong>
            <span>
              {topics.length
                ? "검색어나 상태 필터를 바꿔 보세요."
                : "새 토픽을 초안으로 만들고 공개할 수 있습니다."}
            </span>
            {!topics.length && (
              <button
                className="ui-button mt-3"
                onClick={() => setCreateOpen(true)}
              >
                <Plus size={13} />새 토픽
              </button>
            )}
          </div>
        ) : (
          <ul>
            {visible.map((topic) => (
              <li key={topic.id} className="ui-row">
                <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-md border border-white/8 bg-white/2 text-lg">
                  {topic.coverEmoji ?? "◌"}
                </span>
                <div className="min-w-[130px] flex-1">
                  <p className="text-[13px] font-medium">{topic.title}</p>
                  <p className="mt-0.5 text-[11px] text-text-tertiary">
                    {categoryLabel(topic.category)}
                    {topic.subtitle ? ` · ${topic.subtitle}` : ""}
                  </p>
                </div>
                <span className="hidden w-20 text-right text-xs tabular-nums text-text-secondary sm:block">
                  {topic.postsCount.toLocaleString()}명 참여
                </span>
                <span className={`ui-pill ${topic.status}`}>
                  <span className="h-1.5 w-1.5 rounded-full bg-current" />
                  {statusLabel[topic.status]}
                </span>
                <fieldset
                  disabled={pendingId !== null}
                  className="flex min-w-[70px] justify-end gap-1"
                  aria-label={`${topic.title} 상태 변경`}
                >
                  {pendingId === topic.id ? (
                    <Loader2 size={16} className="animate-spin" />
                  ) : (
                    <>
                      {topic.status !== "live" && (
                        <button
                          className="ui-icon"
                          aria-label={`${topic.title} 공개`}
                          title="공개"
                          onClick={() => void setStatus(topic, "live")}
                        >
                          <Eye size={15} />
                        </button>
                      )}
                      {topic.status === "live" && (
                        <button
                          className="ui-icon"
                          aria-label={`${topic.title} 공개 해제`}
                          title="초안으로 전환"
                          onClick={() => void setStatus(topic, "draft")}
                        >
                          <EyeOff size={15} />
                        </button>
                      )}
                      {topic.status !== "hidden" && (<button className="ui-button" disabled={!!pendingId} onClick={() => void setStatus(topic, "hidden")}>숨김</button>)}
                      {topic.status !== "closed" && (
                        <button
                          className="ui-icon"
                          aria-label={`${topic.title} 마감`}
                          title="마감"
                          onClick={() => void setStatus(topic, "closed")}
                        >
                          <Archive size={15} />
                        </button>
                      )}
                    </>
                  )}
                </fieldset>
              </li>
            ))}
          </ul>
        )}
        <div className="flex items-center justify-between border-t border-white/8 px-4 py-3 text-[11px] text-text-tertiary">
          <span>{visible.length}개 표시 · 최근 200개 범위</span>
          <span className="flex items-center gap-1">
            <ArrowUpRight size={12} />
            공개한 토픽은 앱에 반영됩니다
          </span>
        </div>
      </section>
    </div>
  );
}

function CreateTopicForm({ onCreated }: { onCreated: () => Promise<void> }) {
  const [category, setCategory] = useState<string>(TOPIC_CATEGORIES[0]);
  const [title, setTitle] = useState("");
  const [subtitle, setSubtitle] = useState("");
  const [coverEmoji, setCoverEmoji] = useState("");
  const [publishNow, setPublishNow] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const canSubmit = title.trim().length > 0 && !isSubmitting;

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (!canSubmit) return;
    setIsSubmitting(true);
    setError(null);
    try {
      const response = await fetch("/api/topics", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          category,
          title,
          subtitle,
          coverEmoji,
          status: publishNow ? "live" : "draft",
        }),
      });
      const body = (await response.json()) as { error?: string };
      if (!response.ok)
        throw new Error(body.error ?? "토픽을 만들지 못했습니다.");
      setTitle("");
      setSubtitle("");
      setCoverEmoji("");
      setPublishNow(false);
      await onCreated();
    } catch (e) {
      setError(e instanceof Error ? e.message : "토픽을 만들지 못했습니다.");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <form onSubmit={submit} className="space-y-4">
      <div className="grid grid-cols-12 gap-3">
        <label className="col-span-4 sm:col-span-2 flex flex-col gap-1.5">
          <span className="text-[10px] uppercase tracking-wider text-[#8b8e98]">
            이모지
          </span>
          <input
            value={coverEmoji}
            onChange={(e) => setCoverEmoji(e.target.value)}
            placeholder="🏀"
            maxLength={4}
            className="bg-[#111214] border border-white/8 rounded-lg px-3 py-2 text-sm text-[#ededee] text-center focus:outline-none focus:border-[#e36b59]/60"
          />
        </label>

        <label className="col-span-8 sm:col-span-3 flex flex-col gap-1.5">
          <span className="text-[10px] uppercase tracking-wider text-[#8b8e98]">
            카테고리
          </span>
          <select
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            className="bg-[#111214] border border-white/8 rounded-lg px-3 py-2 text-sm text-[#ededee] focus:outline-none focus:border-[#e36b59]/60"
          >
            {TOPIC_CATEGORIES.map((c) => (
              <option key={c} value={c}>
                {TOPIC_CATEGORY_LABELS[c]}
              </option>
            ))}
          </select>
        </label>

        <label className="col-span-12 sm:col-span-7 flex flex-col gap-1.5">
          <span className="text-[10px] uppercase tracking-wider text-[#8b8e98]">
            제목{" "}
            <span className="text-[#8b8e98]/70">
              ({title.trim().length}/80)
            </span>
          </span>
          <input
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            placeholder="지금 내 연애 온도"
            maxLength={80}
            className="bg-[#111214] border border-white/8 rounded-lg px-3 py-2 text-sm text-[#ededee] focus:outline-none focus:border-[#e36b59]/60"
          />
        </label>

        <label className="col-span-12 flex flex-col gap-1.5">
          <span className="text-[10px] uppercase tracking-wider text-[#8b8e98]">
            부제 <span className="text-[#8b8e98]/70">(선택)</span>
          </span>
          <input
            value={subtitle}
            onChange={(e) => setSubtitle(e.target.value)}
            placeholder="사람들의 실시간 감정"
            maxLength={200}
            className="bg-[#111214] border border-white/8 rounded-lg px-3 py-2 text-sm text-[#ededee] focus:outline-none focus:border-[#e36b59]/60"
          />
        </label>
      </div>

      {error && <p className="text-xs text-red-300">{error}</p>}

      <div className="flex items-center justify-between">
        <label className="flex items-center gap-2 text-xs text-[#a2a4ac] cursor-pointer">
          <input
            type="checkbox"
            checked={publishNow}
            onChange={(e) => setPublishNow(e.target.checked)}
            className="accent-[#e36b59]"
          />
          즉시 공개 (앱에 노출)
        </label>

        <button
          type="submit"
          disabled={!canSubmit}
          className="flex items-center gap-2 bg-[#e36b59] text-white text-sm font-semibold px-4 py-2 rounded-lg disabled:opacity-40 hover:bg-[#e36b59]/90 transition-colors"
        >
          {isSubmitting ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <Plus className="h-4 w-4" />
          )}
          만들기
        </button>
      </div>
    </form>
  );
}
