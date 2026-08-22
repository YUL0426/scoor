/**
 * 피드 글 큐레이션 (spec-13 §3.3).
 *
 * 앱에는 아직 글 작성 UI가 없어서 (Phase 2), 출시 시점 피드는 여기서 등록한
 * **공식 글**로 시작한다. 그래서 이 라우트가 만드는 행은 예외 없이
 * `is_official = true`이고 작성자가 없다 — 앱은 그것을 "Scoor" 이름과 배지로
 * 렌더링한다. 운영자 글에 사람 이름을 붙여 일반 사용자 글처럼 내보내는 순간
 * P0-1이 지적한 가짜 소셜 데이터로 되돌아간다.
 *
 * 읽기는 `feed_posts` 뷰를 쓴다. 뷰가 security_invoker인데 service_role은 RLS를
 * 우회하므로, 같은 뷰 하나로 숨김·삭제된 글까지 집계와 함께 볼 수 있다.
 */

import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { requireAdmin } from "@/lib/server/guard";
import { supabaseAdminConfig, supabaseRest, SupabaseRestError } from "@/lib/server/supabase";
import { POST_MOODS, POST_WEATHERS, type AdminPost, type PostMood, type PostWeather } from "@/types";

const NOT_CONFIGURED =
  "백엔드가 설정되지 않았습니다. admin/.env.local의 SUPABASE_URL·SUPABASE_SERVICE_ROLE_KEY를 확인해주세요.";

interface FeedPostRow {
  id: string;
  is_official: boolean;
  score: number;
  message: string;
  primary_mood: string;
  extra_moods: string[] | null;
  weather: string | null;
  author_name: string | null;
  is_hidden: boolean;
  deleted_at: string | null;
  likes_count: number | null;
  comments_count: number | null;
  created_at: string;
}

function toAdminPost(row: FeedPostRow): AdminPost {
  return {
    id: row.id,
    isOfficial: row.is_official,
    score: row.score,
    message: row.message,
    primaryMood: row.primary_mood,
    extraMoods: row.extra_moods ?? [],
    weather: row.weather,
    authorName: row.author_name,
    isHidden: row.is_hidden,
    deletedAt: row.deleted_at,
    likesCount: row.likes_count ?? 0,
    commentsCount: row.comments_count ?? 0,
    createdAt: row.created_at,
  };
}

export async function GET() {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;

  const config = supabaseAdminConfig();
  if (!config) return NextResponse.json({ error: NOT_CONFIGURED }, { status: 503 });

  try {
    const rows =
      (await supabaseRest<FeedPostRow[]>(config, "feed_posts", {
        query: "select=*&order=created_at.desc&limit=200",
      })) ?? [];
    return NextResponse.json({ posts: rows.map(toAdminPost) });
  } catch (error) {
    return errorResponse(error);
  }
}

export async function POST(request: NextRequest) {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;

  const config = supabaseAdminConfig();
  if (!config) return NextResponse.json({ error: NOT_CONFIGURED }, { status: 503 });

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return NextResponse.json({ error: "요청 본문 형식이 올바르지 않습니다." }, { status: 400 });
  }

  const parsed = parseCreate(payload);
  if ("error" in parsed) return NextResponse.json({ error: parsed.error }, { status: 400 });

  try {
    const created = await supabaseRest<{ id: string }[]>(config, "posts", {
      method: "POST",
      body: [parsed.value],
      returning: true,
    });
    return NextResponse.json({ post: created?.[0] ?? null }, { status: 201 });
  } catch (error) {
    return errorResponse(error);
  }
}

// MARK: - Validation

interface CreatePayload {
  is_official: true;
  author_id: null;
  score: number;
  message: string;
  primary_mood: PostMood;
  extra_moods: PostMood[];
  weather: PostWeather | null;
}

/**
 * Postgres의 check 제약이 진짜 보증이고, 이 층은 오타가 원시 제약 위반 메시지
 * 대신 읽을 수 있는 문장으로 돌아오게 하려고 있다 (topics 라우트와 같은 이유).
 */
function parseCreate(input: unknown): { value: CreatePayload } | { error: string } {
  if (typeof input !== "object" || input === null) return { error: "요청 본문은 객체여야 합니다." };
  const body = input as Record<string, unknown>;

  const score = typeof body.score === "number" ? Math.trunc(body.score) : NaN;
  if (!Number.isFinite(score) || score < 0 || score > 100) {
    return { error: "점수는 0~100 사이여야 합니다." };
  }

  const message = typeof body.message === "string" ? body.message.trim() : "";
  if (message.length < 1 || message.length > 280) {
    return { error: "본문은 1~280자여야 합니다." };
  }

  const primaryMood = typeof body.primaryMood === "string" ? body.primaryMood : "";
  if (!POST_MOODS.includes(primaryMood as PostMood)) {
    return { error: `감정은 다음 중 하나여야 합니다: ${POST_MOODS.join(", ")}.` };
  }

  const extraRaw = Array.isArray(body.extraMoods) ? body.extraMoods : [];
  const extra: PostMood[] = [];
  for (const item of extraRaw) {
    if (typeof item !== "string" || !POST_MOODS.includes(item as PostMood)) {
      return { error: `추가 감정 값이 올바르지 않습니다: ${String(item)}.` };
    }
    if (item !== primaryMood && !extra.includes(item as PostMood)) extra.push(item as PostMood);
  }
  if (extra.length > 2) return { error: "추가 감정은 2개까지입니다." };

  const weatherRaw = typeof body.weather === "string" ? body.weather : "";
  if (weatherRaw && !POST_WEATHERS.includes(weatherRaw as PostWeather)) {
    return { error: `날씨 값이 올바르지 않습니다: ${weatherRaw}.` };
  }

  return {
    value: {
      is_official: true,
      author_id: null,
      score,
      message,
      primary_mood: primaryMood as PostMood,
      extra_moods: extra,
      weather: (weatherRaw as PostWeather) || null,
    },
  };
}

function errorResponse(error: unknown): NextResponse {
  if (error instanceof SupabaseRestError) {
    const status = error.status >= 400 && error.status < 500 ? 400 : 502;
    return NextResponse.json({ error: error.message }, { status });
  }
  return NextResponse.json({ error: "백엔드에 연결하지 못했습니다." }, { status: 502 });
}
