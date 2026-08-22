"use client";

/**
 * 피드 큐레이션 + 모더레이션.
 *
 * 여기서 등록하는 글은 전부 **공식 글**이다 (author_id 없음, 앱에서 "Scoor" +
 * 배지). 앱에 아직 작성 UI가 없어 출시 시점 피드는 이 글들로 채워지는데,
 * 운영자 글을 일반 사용자 글처럼 보이게 만드는 순간 P0-1이 지적한 가짜 소셜
 * 데이터로 되돌아가기 때문에 그 구분은 스키마(check 제약)와 앱 렌더링 양쪽에서
 * 강제된다.
 *
 * 사용자 글은 등록할 수 없고 숨김/삭제만 된다 — 이 화면의 모더레이션 절반이다.
 */

import { useCallback, useEffect, useState } from "react";
import { Loader2, Plus, Eye, EyeOff, Trash2, RefreshCw, Heart, MessageCircle } from "lucide-react";
import {
  POST_MOODS,
  POST_MOOD_LABELS,
  POST_WEATHERS,
  type AdminPost,
  type PostMood,
} from "@/types";

const WEATHER_GLYPH: Record<string, string> = {
  sunny: "☀️", cloudy: "☁️", rainy: "🌧️", snowy: "❄️", night: "🌙",
};

function moodLabel(raw: string): string {
  return (POST_MOOD_LABELS as Record<string, string>)[raw] ?? raw;
}

/** iOS `ScoreTone`과 같은 구간. 어드민에서도 같은 색으로 읽혀야 한다. */
function scoreColor(score: number): string {
  if (score >= 86) return "#ff4d4d";
  if (score >= 71) return "#f29d71";
  if (score >= 51) return "#f4f4f6";
  if (score >= 31) return "#8b8ba4";
  return "#52526c";
}

async function fetchPosts(): Promise<AdminPost[]> {
  const response = await fetch("/api/feed", { cache: "no-store" });
  const body = (await response.json()) as { posts?: AdminPost[]; error?: string };
  if (!response.ok) throw new Error(body.error ?? "피드를 불러오지 못했습니다.");
  return body.posts ?? [];
}

function messageOf(error: unknown): string {
  return error instanceof Error ? error.message : "문제가 발생했습니다.";
}

export function FeedClient() {
  const [posts, setPosts] = useState<AdminPost[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [pendingId, setPendingId] = useState<string | null>(null);

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
      .then((list) => { if (!cancelled) setPosts(list); })
      .catch((e: unknown) => { if (!cancelled) setError(messageOf(e)); })
      .finally(() => { if (!cancelled) setIsLoading(false); });
    return () => { cancelled = true; };
  }, []);

  async function setHidden(post: AdminPost, isHidden: boolean) {
    setPendingId(post.id);
    setError(null);
    try {
      const response = await fetch(`/api/feed/${post.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ isHidden }),
      });
      const body = (await response.json()) as { error?: string };
      if (!response.ok) throw new Error(body.error ?? "글을 수정하지 못했습니다.");
      setPosts((current) => current.map((p) => (p.id === post.id ? { ...p, isHidden } : p)));
    } catch (e) {
      setError(messageOf(e));
    } finally {
      setPendingId(null);
    }
  }

  async function remove(post: AdminPost) {
    if (!window.confirm("이 글을 삭제할까요? 앱에서 즉시 사라집니다.")) return;
    setPendingId(post.id);
    setError(null);
    try {
      const response = await fetch(`/api/feed/${post.id}`, { method: "DELETE" });
      const body = (await response.json()) as { error?: string };
      if (!response.ok) throw new Error(body.error ?? "글을 삭제하지 못했습니다.");
      setPosts((current) =>
        current.map((p) => (p.id === post.id ? { ...p, deletedAt: new Date().toISOString() } : p))
      );
    } catch (e) {
      setError(messageOf(e));
    } finally {
      setPendingId(null);
    }
  }

  const visibleCount = posts.filter((p) => !p.isHidden && !p.deletedAt).length;
  const officialCount = posts.filter((p) => p.isOfficial && !p.isHidden && !p.deletedAt).length;

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-3 gap-4">
        {[
          { label: "앱에 보이는 글", value: String(visibleCount), color: visibleCount > 0 ? "#22c55e" : "#f59e0b" },
          { label: "공식 글", value: String(officialCount), color: "#4f8ef7" },
          { label: "숨김·삭제", value: String(posts.length - visibleCount), color: "#8b8ba4" },
        ].map((s) => (
          <div key={s.label} className="bg-[#0d0d1f] border border-white/6 rounded-xl px-5 py-4">
            <p className="text-xs text-[#52526c] uppercase tracking-wider mb-1">{s.label}</p>
            <p className="text-2xl font-bold tabular-nums" style={{ color: s.color }}>{s.value}</p>
          </div>
        ))}
      </div>

      {visibleCount === 0 && !isLoading && (
        <p className="text-xs text-[#f59e0b]">
          앱에 보이는 글이 없습니다 — 지금 Feed 탭은 빈 화면입니다.
        </p>
      )}

      <CreatePostForm onCreated={load} />

      {error && (
        <div className="rounded-lg border border-red-500/30 bg-red-500/10 px-4 py-3 text-sm text-red-300">
          {error}
        </div>
      )}

      <div className="bg-[#0d0d1f] border border-white/6 rounded-xl overflow-hidden">
        <div className="flex items-center justify-between px-5 py-3 border-b border-white/6">
          <h2 className="text-sm font-semibold text-[#f4f4f6]">글 목록</h2>
          <button
            onClick={() => void load()}
            className="flex items-center gap-1.5 text-xs text-[#8b8ba4] hover:text-[#f4f4f6] transition-colors"
          >
            <RefreshCw className="h-3.5 w-3.5" />
            새로고침
          </button>
        </div>

        {isLoading ? (
          <div className="flex items-center justify-center py-14 text-[#52526c]">
            <Loader2 className="h-5 w-5 animate-spin" />
          </div>
        ) : posts.length === 0 ? (
          <div className="py-14 text-center">
            <p className="text-sm text-[#8b8ba4]">아직 글이 없습니다.</p>
            <p className="text-xs text-[#52526c] mt-1">
              위에서 첫 글을 등록해주세요 — 글이 없으면 앱 Feed 탭이 빈 화면이 됩니다.
            </p>
          </div>
        ) : (
          <ul className="divide-y divide-white/6">
            {posts.map((post) => {
              const isPending = pendingId === post.id;
              const isGone = Boolean(post.deletedAt);
              return (
                <li
                  key={post.id}
                  className={`flex items-start gap-4 px-5 py-4 ${isGone ? "opacity-40" : ""}`}
                >
                  <span
                    className="text-lg font-bold tabular-nums w-10 text-right flex-shrink-0"
                    style={{ color: scoreColor(post.score) }}
                  >
                    {post.score}
                  </span>

                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2 mb-1">
                      <span className="text-xs font-medium text-[#f4f4f6]">
                        {post.isOfficial ? "Scoor" : (post.authorName ?? "익명")}
                      </span>
                      {post.isOfficial && (
                        <span className="text-[10px] font-semibold px-1.5 py-0.5 rounded bg-[#ff4d4d]/15 text-[#ff4d4d]">
                          공식
                        </span>
                      )}
                      <span className="text-[10px] text-[#52526c]">
                        #{moodLabel(post.primaryMood)}
                        {post.extraMoods.map((m) => ` #${moodLabel(m)}`).join("")}
                        {post.weather ? ` ${WEATHER_GLYPH[post.weather] ?? ""}` : ""}
                      </span>
                    </div>
                    <p className="text-sm text-[#8b8ba4] break-words">{post.message}</p>
                    <div className="flex items-center gap-3 mt-2 text-[10px] text-[#52526c]">
                      <span className="flex items-center gap-1">
                        <Heart className="h-3 w-3" /> {post.likesCount}
                      </span>
                      <span className="flex items-center gap-1">
                        <MessageCircle className="h-3 w-3" /> {post.commentsCount}
                      </span>
                      <span>{new Date(post.createdAt).toLocaleString("ko-KR")}</span>
                      {isGone && <span className="text-[#f59e0b]">삭제됨</span>}
                      {post.isHidden && !isGone && <span className="text-[#f59e0b]">숨김</span>}
                    </div>
                  </div>

                  <div className="flex items-center gap-1.5 flex-shrink-0 w-20 justify-end pt-1">
                    {isPending ? (
                      <Loader2 className="h-4 w-4 animate-spin text-[#52526c]" />
                    ) : isGone ? null : (
                      <>
                        <IconButton
                          title={post.isHidden ? "숨김 해제" : "숨기기"}
                          onClick={() => void setHidden(post, !post.isHidden)}
                          icon={post.isHidden ? <EyeOff className="h-3.5 w-3.5" /> : <Eye className="h-3.5 w-3.5" />}
                        />
                        <IconButton
                          title="삭제"
                          onClick={() => void remove(post)}
                          icon={<Trash2 className="h-3.5 w-3.5" />}
                        />
                      </>
                    )}
                  </div>
                </li>
              );
            })}
          </ul>
        )}
      </div>
    </div>
  );
}

function IconButton({ title, onClick, icon }: { title: string; onClick: () => void; icon: React.ReactNode }) {
  return (
    <button
      title={title}
      onClick={onClick}
      className="p-1.5 rounded-md text-[#8b8ba4] hover:text-[#f4f4f6] hover:bg-white/5 transition-colors"
    >
      {icon}
    </button>
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
        body: JSON.stringify({ score, message: message.trim(), primaryMood, weather: weather || undefined }),
      });
      const body = (await response.json()) as { error?: string };
      if (!response.ok) throw new Error(body.error ?? "글을 등록하지 못했습니다.");
      setMessage("");
      await onCreated();
    } catch (e) {
      setError(messageOf(e));
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <form onSubmit={submit} className="bg-[#0d0d1f] border border-white/6 rounded-xl p-5 space-y-4">
      <div className="flex items-center gap-2">
        <Plus className="h-4 w-4 text-[#8b8ba4]" />
        <h2 className="text-sm font-semibold text-[#f4f4f6]">공식 글 등록</h2>
        <span className="text-xs text-[#52526c]">
          앱에서 &ldquo;Scoor · 공식&rdquo; 배지와 함께 보입니다
        </span>
      </div>

      <div className="grid grid-cols-[120px_1fr] gap-3">
        <label className="space-y-1.5">
          <span className="block text-xs text-[#8b8ba4]">점수</span>
          <input
            type="number"
            min={0}
            max={100}
            value={score}
            onChange={(e) => setScore(Number(e.target.value))}
            className="w-full bg-[#08081a] border border-white/8 rounded-lg px-3 py-2 text-sm text-[#f4f4f6] tabular-nums"
          />
        </label>
        <label className="space-y-1.5">
          <span className="block text-xs text-[#8b8ba4]">본문 (280자)</span>
          <input
            value={message}
            maxLength={280}
            onChange={(e) => setMessage(e.target.value)}
            placeholder="오늘 하루는 몇 점인가요?"
            className="w-full bg-[#08081a] border border-white/8 rounded-lg px-3 py-2 text-sm text-[#f4f4f6]"
          />
        </label>
      </div>

      <div className="grid grid-cols-2 gap-3">
        <label className="space-y-1.5">
          <span className="block text-xs text-[#8b8ba4]">감정</span>
          <select
            value={primaryMood}
            onChange={(e) => setPrimaryMood(e.target.value as PostMood)}
            className="w-full bg-[#08081a] border border-white/8 rounded-lg px-3 py-2 text-sm text-[#f4f4f6]"
          >
            {POST_MOODS.map((m) => (
              <option key={m} value={m}>{POST_MOOD_LABELS[m]}</option>
            ))}
          </select>
        </label>
        <label className="space-y-1.5">
          <span className="block text-xs text-[#8b8ba4]">날씨 (선택)</span>
          <select
            value={weather}
            onChange={(e) => setWeather(e.target.value)}
            className="w-full bg-[#08081a] border border-white/8 rounded-lg px-3 py-2 text-sm text-[#f4f4f6]"
          >
            <option value="">없음</option>
            {POST_WEATHERS.map((w) => (
              <option key={w} value={w}>{WEATHER_GLYPH[w]} {w}</option>
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
