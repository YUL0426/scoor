"use client";
import { useState, useEffect, useCallback } from "react";
import * as Dialog from "@radix-ui/react-dialog";
import {
  Loader2,
  Plus,
  Eye,
  EyeOff,
  Trash2,
  Heart,
  MessageCircle,
  Rss,
} from "lucide-react";
import { CreateDialog, ListToolbar } from "@/components/admin/content-tools";
import {
  POST_MOODS,
  POST_MOOD_LABELS,
  POST_WEATHERS,
  type AdminPost,
  type PostMood,
} from "@/types";
const WEATHER_GLYPH: Record<string, string> = {
  sunny: "☀️",
  cloudy: "☁️",
  rainy: "🌧️",
  snowy: "❄️",
  night: "🌙",
};
const moodLabel = (raw: string) =>
  (POST_MOOD_LABELS as Record<string, string>)[raw] ?? raw;
const messageOf = (e: unknown) =>
  e instanceof Error ? e.message : "다시 시도해 주세요.";
async function fetchPosts(): Promise<AdminPost[]> {
  const r = await fetch("/api/feed", { cache: "no-store" });
  const b = await r.json();
  if (!r.ok) throw new Error(b.error ?? "피드를 불러오지 못했습니다.");
  return b.posts ?? [];
}
export function FeedClient() {
  const [posts, setPosts] = useState<AdminPost[]>([]),
    [isLoading, setIsLoading] = useState(true),
    [error, setError] = useState<string | null>(null),
    [pendingId, setPendingId] = useState<string | null>(null);
  const [query, setQuery] = useState(""),
    [filter, setFilter] = useState("all"),
    [createOpen, setCreateOpen] = useState(false),
    [notice, setNotice] = useState(""),
    [deleteTarget, setDeleteTarget] = useState<AdminPost | null>(null);
  const load = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      setPosts(await fetchPosts());
    } catch (e) {
      setError(messageOf(e));
    } finally {
      setIsLoading(false);
    }
  }, []);
  useEffect(() => {
    let cancelled = false;
    fetchPosts()
      .then((rows) => {
        if (!cancelled) setPosts(rows);
      })
      .catch((e) => {
        if (!cancelled) setError(messageOf(e));
      })
      .finally(() => {
        if (!cancelled) setIsLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);
  async function update(post: AdminPost, remove = false) {
    if (pendingId) return;
    setPendingId(post.id);
    setError(null);
    setNotice("");
    try {
      const r = await fetch(`/api/feed/${post.id}`, {
        method: remove ? "DELETE" : "PATCH",
        headers: { "Content-Type": "application/json" },
        ...(!remove
          ? { body: JSON.stringify({ isHidden: !post.isHidden }) }
          : {}),
      });
      const b = await r.json();
      if (!r.ok) throw new Error(b.error ?? "글을 변경하지 못했습니다.");
      setPosts((rows) =>
        rows.map((p) =>
          p.id === post.id
            ? {
                ...p,
                ...(remove
                  ? { deletedAt: new Date().toISOString() }
                  : { isHidden: !p.isHidden }),
              }
            : p,
        ),
      );
      setDeleteTarget(null);
      setNotice(
        remove
          ? "글을 삭제했습니다."
          : post.isHidden
            ? "숨김을 해제했습니다."
            : "앱에서 글을 숨겼습니다.",
      );
    } catch (e) {
      setError(messageOf(e));
    } finally {
      setPendingId(null);
    }
  }
  const status = (p: AdminPost) =>
    p.deletedAt ? "deleted" : p.isHidden ? "hidden" : "live";
  const labels: Record<string, string> = {
    live: "공개",
    hidden: "숨김",
    deleted: "삭제",
  };
  const count = (s: string) => posts.filter((p) => status(p) === s).length;
  const visible = posts.filter(
    (p) =>
      (filter === "all" || status(p) === filter) &&
      `${p.message} ${p.authorName ?? ""} ${moodLabel(p.primaryMood)}`
        .toLowerCase()
        .includes(query.toLowerCase()),
  );
  return (
    <div>
      <div className="page-intro">
        <div>
          <p className="ui-kicker !mb-1">콘텐츠 / FEED</p>
          <h2>피드</h2>
          <p>공식 메시지를 전하고, 공개된 콘텐츠를 살펴보세요.</p>
        </div>
        <CreateDialog
          title="공식 글 등록"
          description="등록하면 앱에 ‘Scoor · 공식’ 배지와 함께 바로 공개됩니다."
          open={createOpen}
          onOpenChange={setCreateOpen}
        >
          <CreatePostForm
            onCreated={async () => {
              setCreateOpen(false);
              setNotice("공식 글을 등록했습니다.");
              await load();
            }}
          />
        </CreateDialog>
      </div>
      <div className="ui-summary">
        {[
          { label: "앱에 공개 중", value: count("live") },
          { label: "숨긴 글", value: count("hidden") },
          { label: "삭제한 글", value: count("deleted") },
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
      <section className="ui-panel" aria-label="피드 목록">
        <ListToolbar
          query={query}
          onQuery={setQuery}
          filter={filter}
          onFilter={setFilter}
          tabs={[
            { value: "all", label: "전체", count: posts.length },
            ...["live", "hidden", "deleted"].map((s) => ({
              value: s,
              label: labels[s],
              count: count(s),
            })),
          ]}
          loading={isLoading}
          onRefresh={() => void load()}
        />
        {isLoading ? (
          <div className="ui-empty" role="status">
            <Loader2 size={20} className="animate-spin" />
            피드를 불러오는 중
          </div>
        ) : error && !posts.length ? (
          <div className="ui-empty">
            <strong>피드를 확인할 수 없습니다</strong>
            <span>연결을 확인한 뒤 다시 시도해 주세요.</span>
          </div>
        ) : !visible.length ? (
          <div className="ui-empty">
            <Rss size={25} strokeWidth={1.3} />
            <strong>
              {posts.length
                ? "일치하는 글이 없습니다"
                : "첫 공식 글을 등록해 보세요"}
            </strong>
            <span>
              {posts.length
                ? "검색어나 상태 필터를 바꿔 보세요."
                : "지금 공개된 글이 없어 앱 피드도 비어 있습니다."}
            </span>
            {!posts.length && (
              <button
                className="ui-button mt-3"
                onClick={() => setCreateOpen(true)}
              >
                <Plus size={13} />
                공식 글 등록
              </button>
            )}
          </div>
        ) : (
          <ul>
            {visible.map((post) => (
              <li key={post.id} className="ui-row !items-start">
                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-md border border-white/10 bg-white/3 text-base font-medium tabular-nums">
                  {post.score}
                </div>
                <div className="min-w-[140px] flex-1">
                  <div className="mb-1 flex items-center gap-2 text-xs">
                    <span className="font-medium">
                      {post.isOfficial ? "Scoor" : (post.authorName ?? "익명")}
                    </span>
                    {post.isOfficial && (
                      <span className="text-[10px] text-brand-light">공식</span>
                    )}
                    <span className="text-text-tertiary">
                      · {moodLabel(post.primaryMood)}
                    </span>
                  </div>
                  <p
                    className={`text-[13px] leading-relaxed ${post.deletedAt ? "text-text-tertiary line-through" : "text-text-primary"}`}
                  >
                    {post.message}
                  </p>
                  <div className="mt-2 flex flex-wrap items-center gap-3 text-[11px] text-text-tertiary">
                    <span className="flex items-center gap-1">
                      <Heart size={11} />
                      {post.likesCount}
                    </span>
                    <span className="flex items-center gap-1">
                      <MessageCircle size={11} />
                      {post.commentsCount}
                    </span>
                    <time dateTime={post.createdAt}>
                      {new Date(post.createdAt).toLocaleDateString("ko-KR")}
                    </time>
                  </div>
                </div>
                <span
                  className={`ui-pill ${status(post) === "live" ? "live" : "draft"}`}
                >
                  {labels[status(post)]}
                </span>
                <fieldset
                  className="flex min-w-[64px] justify-end gap-1"
                  disabled={pendingId !== null}
                  aria-label={`${post.message} 작업`}
                >
                  {pendingId === post.id ? (
                    <Loader2 size={16} className="animate-spin" />
                  ) : (
                    !post.deletedAt && (
                      <>
                        <button
                          className="ui-icon"
                          aria-label={`${post.message} ${post.isHidden ? "숨김 해제" : "숨기기"}`}
                          title={post.isHidden ? "숨김 해제" : "숨기기"}
                          onClick={() => void update(post)}
                        >
                          {post.isHidden ? (
                            <Eye size={15} />
                          ) : (
                            <EyeOff size={15} />
                          )}
                        </button>
                        <button
                          className="ui-icon hover:!text-red-300"
                          aria-label={`${post.message} 삭제`}
                          title="삭제"
                          onClick={() => {
                            setError(null);
                            setDeleteTarget(post);
                          }}
                        >
                          <Trash2 size={14} />
                        </button>
                      </>
                    )
                  )}
                </fieldset>
              </li>
            ))}
          </ul>
        )}
        <div className="border-t border-white/8 px-4 py-3 text-[11px] text-text-tertiary">
          {visible.length}개 표시 · 최근 200개 범위
        </div>
      </section>
      <Dialog.Root
        open={deleteTarget !== null}
        onOpenChange={(open) => {
          if (!open && !pendingId) setDeleteTarget(null);
        }}
      >
        <Dialog.Portal>
          <Dialog.Overlay className="dialog-overlay" />
          <Dialog.Content className="dialog-content !max-w-[440px]">
            <Dialog.Title className="text-lg font-semibold">
              이 글을 삭제할까요?
            </Dialog.Title>
            <Dialog.Description className="mt-2 text-sm text-text-secondary">
              앱에서 즉시 사라지며, 이 화면에서 되돌릴 수 없습니다.
            </Dialog.Description>
            <blockquote className="my-5 rounded-md border border-white/10 bg-black/10 p-3 text-sm text-text-secondary">
              {deleteTarget?.message}
            </blockquote>
            {error && (
              <p role="alert" className="mb-4 text-xs text-red-300">
                {error}
              </p>
            )}
            <div className="flex justify-end gap-2">
              <Dialog.Close className="ui-button" disabled={pendingId !== null}>
                취소
              </Dialog.Close>
              <button
                className="ui-button primary"
                disabled={pendingId !== null}
                onClick={() => deleteTarget && void update(deleteTarget, true)}
              >
                {pendingId ? "삭제 중…" : "글 삭제"}
              </button>
            </div>
          </Dialog.Content>
        </Dialog.Portal>
      </Dialog.Root>
    </div>
  );
}

function CreatePostForm({ onCreated }: { onCreated: () => Promise<void> }) {
  const [score, setScore] = useState(70);
  const [message, setMessage] = useState("");
  const [primaryMood, setPrimaryMood] = useState<PostMood>(POST_MOODS[0]);
  const [weather, setWeather] = useState<string>("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const canSubmit = message.trim().length > 0 && !isSubmitting;

  async function submit(event: React.FormEvent) {
    event.preventDefault();
    if (!canSubmit) return;
    setIsSubmitting(true);
    setError(null);
    try {
      const response = await fetch("/api/feed", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          score,
          message: message.trim(),
          primaryMood,
          weather: weather || undefined,
        }),
      });
      const body = (await response.json()) as { error?: string };
      if (!response.ok)
        throw new Error(body.error ?? "글을 등록하지 못했습니다.");
      setMessage("");
      await onCreated();
    } catch (e) {
      setError(messageOf(e));
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <form onSubmit={submit} className="space-y-4">
      <div className="grid grid-cols-1 sm:grid-cols-[100px_1fr] gap-3">
        <label className="space-y-1.5">
          <span className="block text-xs text-[#a2a4ac]">점수</span>
          <input
            type="number"
            min={0}
            max={100}
            value={score}
            onChange={(e) => setScore(Number(e.target.value))}
            className="w-full bg-[#141517] border border-white/8 rounded-lg px-3 py-2 text-sm text-[#ededee] tabular-nums"
          />
        </label>
        <label className="space-y-1.5">
          <span className="block text-xs text-[#a2a4ac]">본문 (280자)</span>
          <input
            value={message}
            maxLength={280}
            onChange={(e) => setMessage(e.target.value)}
            placeholder="오늘 하루는 몇 점인가요?"
            className="w-full bg-[#141517] border border-white/8 rounded-lg px-3 py-2 text-sm text-[#ededee]"
          />
        </label>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <label className="space-y-1.5">
          <span className="block text-xs text-[#a2a4ac]">감정</span>
          <select
            value={primaryMood}
            onChange={(e) => setPrimaryMood(e.target.value as PostMood)}
            className="w-full bg-[#141517] border border-white/8 rounded-lg px-3 py-2 text-sm text-[#ededee]"
          >
            {POST_MOODS.map((m) => (
              <option key={m} value={m}>
                {POST_MOOD_LABELS[m]}
              </option>
            ))}
          </select>
        </label>
        <label className="space-y-1.5">
          <span className="block text-xs text-[#a2a4ac]">날씨 (선택)</span>
          <select
            value={weather}
            onChange={(e) => setWeather(e.target.value)}
            className="w-full bg-[#141517] border border-white/8 rounded-lg px-3 py-2 text-sm text-[#ededee]"
          >
            <option value="">없음</option>
            {POST_WEATHERS.map((w) => (
              <option key={w} value={w}>
                {WEATHER_GLYPH[w]} {w}
              </option>
            ))}
          </select>
        </label>
      </div>

      {error && <p className="text-xs text-red-300">{error}</p>}

      <button
        type="submit"
        disabled={!canSubmit}
        className="flex items-center gap-2 rounded-lg bg-[#ff4d4d] px-4 py-2 text-sm font-semibold text-white disabled:opacity-40"
      >
        {isSubmitting && <Loader2 className="h-4 w-4 animate-spin" />}
        등록
      </button>
    </form>
  );
}
