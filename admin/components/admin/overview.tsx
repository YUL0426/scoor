"use client";
import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import {
  ArrowUpRight,
  CircleDashed,
  Check,
  ListTodo,
  Rss,
  RefreshCw,
  ArrowRight,
  MessageSquare,
  Eye,
} from "lucide-react";
import type { AdminTopic, AdminPost } from "@/types";
export function Overview() {
  const [data, setData] = useState<{
      topics: AdminTopic[];
      posts: AdminPost[];
    } | null>(null),
    [error, setError] = useState<string | null>(null),
    [loading, setLoading] = useState(true),
    [updated, setUpdated] = useState<Date | null>(null);
  const fetchData = useCallback(async () => {
    const responses = await Promise.all([
      fetch("/api/topics", { cache: "no-store" }),
      fetch("/api/feed", { cache: "no-store" }),
    ]);
    const bodies = await Promise.all(responses.map((r) => r.json()));
    for (let i = 0; i < responses.length; i++)
      if (!responses[i].ok)
        throw new Error(bodies[i].error ?? "콘텐츠를 불러오지 못했습니다.");
    return {
      topics: bodies[0].topics as AdminTopic[],
      posts: bodies[1].posts as AdminPost[],
    };
  }, []);
  const refresh = async () => {
    setLoading(true);
    setError(null);
    try {
      setData(await fetchData());
      setUpdated(new Date());
    } catch (e) {
      setError(e instanceof Error ? e.message : "다시 시도해 주세요.");
    } finally {
      setLoading(false);
    }
  };
  useEffect(() => {
    let cancelled = false;
    fetchData()
      .then((d) => {
        if (!cancelled) {
          setData(d);
          setUpdated(new Date());
        }
      })
      .catch((e) => {
        if (!cancelled) setError(e.message);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [fetchData]);
  const live = data?.topics.filter((t) => t.status === "live") ?? [],
    drafts = data?.topics.filter((t) => t.status === "draft") ?? [],
    publicPosts = data?.posts.filter((p) => !p.isHidden && !p.deletedAt) ?? [];
  const counts = [
    {
      label: "공개 중인 토픽",
      count: live.length,
      detail: "앱 World에서 참여 가능",
      icon: ListTodo,
      href: "/admin/topics",
    },
    {
      label: "준비 중인 초안",
      count: drafts.length,
      detail: "공개할 다음 이야기를 준비하세요",
      icon: CircleDashed,
      href: "/admin/topics",
    },
    {
      label: "공개 중인 피드",
      count: publicPosts.length,
      detail: "앱 Feed에 표시되는 글",
      icon: Rss,
      href: "/admin/feed",
    },
  ];
  return (
    <>
      <div className="page-intro">
        <div>
          <p className="ui-kicker !mb-1">SCOOR / OPERATIONS</p>
          <h2>오늘의 워크스페이스</h2>
          <p>콘텐츠를 준비하고, 사람들이 나눌 이야기를 이어가세요.</p>
        </div>
        <button
          onClick={() => void refresh()}
          disabled={loading}
          className="ui-button"
        >
          <RefreshCw size={13} className={loading ? "animate-spin" : ""} />
          새로고침
        </button>
      </div>
      {error && (
        <div role="alert" className="ui-error mb-5">
          {error}
          <button onClick={() => void refresh()} className="ui-button ml-auto">
            다시 시도
          </button>
        </div>
      )}
      <div className="mb-7 grid grid-cols-1 gap-3 md:grid-cols-3">
        {counts.map((c) => (
          <Link
            href={c.href}
            key={c.label}
            className="group ui-panel px-5 py-5 hover:border-white/20"
          >
            <div className="flex items-center gap-2 text-xs text-text-secondary">
              <c.icon size={14} />
              {c.label}
              <ArrowUpRight size={13} className="ml-auto text-text-tertiary" />
            </div>
            <p className="my-3 text-[34px] font-medium leading-none tracking-[-1.5px] tabular-nums">
              {!data || error ? "—" : c.count}
            </p>
            <p className="text-[11px] text-text-tertiary">{c.detail}</p>
          </Link>
        ))}
      </div>
      <div className="grid items-start gap-6 xl:grid-cols-[minmax(0,1fr)_300px]">
        <div className="space-y-6">
          <section className="ui-panel">
            <div className="flex items-center gap-2 px-5 py-4">
              <ListTodo size={15} className="text-text-secondary" />
              <h3 className="text-[13px] font-medium">공개 중인 토픽</h3>
              <span className="ui-pill">
                {data && !error ? live.length : "—"}
              </span>
              <Link
                className="ml-auto flex items-center gap-1 text-xs text-text-tertiary hover:text-text-primary"
                href="/admin/topics"
              >
                전체 보기
                <ArrowRight size={13} />
              </Link>
            </div>
            {loading && !data ? (
              <div className="ui-empty">콘텐츠를 불러오는 중…</div>
            ) : !live.length ? (
              <div className="ui-empty">
                <ListTodo size={24} />
                <strong>
                  {error
                    ? "토픽을 확인할 수 없습니다"
                    : "공개 중인 토픽이 없습니다"}
                </strong>
                <Link href="/admin/topics" className="ui-button mt-2">
                  토픽 관리로 이동
                </Link>
              </div>
            ) : (
              live.slice(0, 6).map((t) => (
                <Link href="/admin/topics" className="ui-row" key={t.id}>
                  <span className="text-xl">{t.coverEmoji ?? "◌"}</span>
                  <div className="min-w-0 flex-1">
                    <p className="text-[13px] font-medium">{t.title}</p>
                    <p className="mt-0.5 truncate text-[11px] text-text-tertiary">
                      {t.subtitle ?? "오늘의 이야기를 나눠 보세요"}
                    </p>
                  </div>
                  <span className="text-[11px] text-text-secondary">
                    {t.postsCount}명 참여
                  </span>
                  <span className="ui-pill live">공개</span>
                </Link>
              ))
            )}
          </section>
          <section className="ui-panel">
            <div className="flex items-center gap-2 px-5 py-4">
              <Rss size={15} className="text-text-secondary" />
              <h3 className="text-[13px] font-medium">최근 공개된 피드</h3>
              <Link
                href="/admin/feed"
                className="ml-auto flex items-center gap-1 text-xs text-text-tertiary hover:text-text-primary"
              >
                피드 관리
                <ArrowRight size={13} />
              </Link>
            </div>
            {!publicPosts.length ? (
              <div className="ui-empty !py-10">
                <MessageSquare size={23} strokeWidth={1.4} />
                <strong>
                  {error
                    ? "피드를 확인할 수 없습니다"
                    : "첫 공식 글을 기다리고 있어요"}
                </strong>
                <span>앱에서 만날 첫 메시지를 작성해 보세요.</span>
                <Link href="/admin/feed" className="ui-button mt-2">
                  공식 글 등록하기
                  <ArrowUpRight size={12} />
                </Link>
              </div>
            ) : (
              publicPosts.slice(0, 3).map((p) => (
                <Link href="/admin/feed" className="ui-row" key={p.id}>
                  <span className="w-8 text-center text-lg tabular-nums">
                    {p.score}
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-[13px]">{p.message}</p>
                    <p className="mt-1 text-[11px] text-text-tertiary">
                      {p.isOfficial ? "Scoor · 공식" : (p.authorName ?? "익명")}{" "}
                      · 댓글 {p.commentsCount}
                    </p>
                  </div>
                  <ArrowUpRight size={13} className="text-text-tertiary" />
                </Link>
              ))
            )}
          </section>
        </div>
        <aside className="space-y-5">
          <section className="ui-panel">
            <div className="border-b border-white/8 px-4 py-3.5 text-xs font-medium">
              콘텐츠 준비 상태
            </div>
            <div className="space-y-5 p-4">
              {[
                {
                  title: "월드 토픽",
                  ready: live.length > 0,
                  description: live.length
                    ? `${live.length}개의 토픽이 공개되어 있습니다.`
                    : "공개할 토픽을 준비해 주세요.",
                },
                {
                  title: "공식 피드",
                  ready: publicPosts.length > 0,
                  description: publicPosts.length
                    ? `${publicPosts.length}개의 글이 공개되어 있습니다.`
                    : "아직 앱에 보이는 글이 없습니다.",
                },
              ].map((s) => (
                <div key={s.title} className="flex gap-2.5">
                  <span
                    className={`mt-0.5 ${data && !error && s.ready ? "text-[#8ccbb0]" : "text-text-tertiary"}`}
                  >
                    {data && !error && s.ready ? (
                      <Check size={15} />
                    ) : (
                      <CircleDashed size={15} />
                    )}
                  </span>
                  <div>
                    <p className="text-xs">{s.title}</p>
                    <p className="mt-1 text-[11px] leading-relaxed text-text-tertiary">
                      {!data || error
                        ? "불러온 후 확인할 수 있습니다."
                        : s.description}
                    </p>
                  </div>
                </div>
              ))}
            </div>
          </section>
          <div className="px-1">
            <p className="mb-2 flex items-center gap-2 text-xs text-text-secondary">
              <Eye size={13} />
              현재 표시 범위
            </p>
            <p className="text-[11px] leading-relaxed text-text-tertiary">
              토픽·피드 각각 최근 200개를 기준으로 표시합니다.
              사용자·분석·알림은 미리보기 메뉴에서 샘플 화면을 확인할 수
              있습니다.
            </p>
            <div className="mt-5 border-t border-white/8 pt-4 text-[11px] text-text-tertiary">
              {updated
                ? `마지막 조회 ${updated.toLocaleTimeString("ko-KR", { hour: "2-digit", minute: "2-digit" })}`
                : "조회 대기 중"}
            </div>
          </div>
        </aside>
      </div>
    </>
  );
}
