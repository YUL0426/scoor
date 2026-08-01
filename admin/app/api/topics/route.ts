/**
 * World topic curation (spec-13 §12 Phase 1, decision §15-4: 3–5 topics/day).
 *
 * The app can only read topics and submit scores; creating and closing them is
 * an ops action, which is why it lives here behind the service-role key instead
 * of in the client. Before this route existed, adding the day's topics meant
 * hand-running SQL.
 */

import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { requireAdmin } from "@/lib/server/guard";
import { supabaseAdminConfig, supabaseRest, SupabaseRestError } from "@/lib/server/supabase";
import { TOPIC_CATEGORIES, TOPIC_STATUSES, type AdminTopic, type TopicStatus } from "@/types";

/** Mirrors `public.topics` plus the aggregate columns of `topics_feed`. */
interface TopicRow {
  id: string;
  category: string;
  title: string;
  subtitle: string | null;
  cover_emoji: string | null;
  status: TopicStatus;
  starts_at: string | null;
  ends_at: string | null;
  created_at: string;
}

interface StatsRow {
  topic_id: string;
  posts_count: number | null;
  global_score: number | null;
}

export async function GET() {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;

  const config = supabaseAdminConfig();
  if (!config) {
    return NextResponse.json({ error: "Backend is not configured." }, { status: 503 });
  }

  try {
    // Read `topics` directly rather than `topics_feed`: the view hides drafts by
    // design, and drafts are exactly what an editor needs to see.
    const rows =
      (await supabaseRest<TopicRow[]>(config, "topics", {
        query: "select=*&order=created_at.desc&limit=200",
      })) ?? [];

    const stats =
      (await supabaseRest<StatsRow[]>(config, "topic_stats", {
        query: "select=topic_id,posts_count,global_score",
      })) ?? [];
    const byTopic = new Map(stats.map((s) => [s.topic_id, s]));

    const topics: AdminTopic[] = rows.map((row) => ({
      id: row.id,
      category: row.category,
      title: row.title,
      subtitle: row.subtitle,
      coverEmoji: row.cover_emoji,
      status: row.status,
      createdAt: row.created_at,
      startsAt: row.starts_at,
      endsAt: row.ends_at,
      postsCount: byTopic.get(row.id)?.posts_count ?? 0,
      globalScore: byTopic.get(row.id)?.global_score ?? 0,
    }));

    return NextResponse.json({ topics });
  } catch (error) {
    return errorResponse(error);
  }
}

export async function POST(request: NextRequest) {
  const auth = await requireAdmin();
  if (!auth.ok) return auth.response;

  const config = supabaseAdminConfig();
  if (!config) {
    return NextResponse.json({ error: "Backend is not configured." }, { status: 503 });
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return NextResponse.json({ error: "Malformed JSON body." }, { status: 400 });
  }

  const parsed = parseCreate(payload);
  if ("error" in parsed) {
    return NextResponse.json({ error: parsed.error }, { status: 400 });
  }

  try {
    const created = await supabaseRest<TopicRow[]>(config, "topics", {
      method: "POST",
      body: [parsed.value],
      returning: true,
    });
    return NextResponse.json({ topic: created?.[0] ?? null }, { status: 201 });
  } catch (error) {
    return errorResponse(error);
  }
}

// MARK: - Validation

interface CreatePayload {
  category: string;
  title: string;
  subtitle: string | null;
  cover_emoji: string | null;
  status: TopicStatus;
}

/**
 * Validated here as well as in Postgres. The DB check constraints are the real
 * guarantee; this layer exists so a typo comes back as a readable message
 * instead of a raw constraint violation.
 */
function parseCreate(input: unknown): { value: CreatePayload } | { error: string } {
  if (typeof input !== "object" || input === null) return { error: "Body must be an object." };
  const body = input as Record<string, unknown>;

  const title = typeof body.title === "string" ? body.title.trim() : "";
  if (title.length < 1 || title.length > 80) {
    return { error: "Title must be 1–80 characters." };
  }

  const category = typeof body.category === "string" ? body.category : "";
  if (!TOPIC_CATEGORIES.includes(category as (typeof TOPIC_CATEGORIES)[number])) {
    return { error: `Category must be one of: ${TOPIC_CATEGORIES.join(", ")}.` };
  }

  const status = typeof body.status === "string" ? body.status : "draft";
  if (!TOPIC_STATUSES.includes(status as TopicStatus)) {
    return { error: `Status must be one of: ${TOPIC_STATUSES.join(", ")}.` };
  }

  const subtitleRaw = typeof body.subtitle === "string" ? body.subtitle.trim() : "";
  if (subtitleRaw.length > 200) return { error: "Subtitle must be 200 characters or fewer." };

  const emojiRaw = typeof body.coverEmoji === "string" ? body.coverEmoji.trim() : "";

  return {
    value: {
      category,
      title,
      subtitle: subtitleRaw || null,
      cover_emoji: emojiRaw || null,
      status: status as TopicStatus,
    },
  };
}

function errorResponse(error: unknown): NextResponse {
  if (error instanceof SupabaseRestError) {
    // 4xx from PostgREST is a bad request on our side; anything else is upstream.
    const status = error.status >= 400 && error.status < 500 ? 400 : 502;
    return NextResponse.json({ error: error.message }, { status });
  }
  return NextResponse.json({ error: "Could not reach the backend." }, { status: 502 });
}
