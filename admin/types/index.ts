// ─────────────────────────────────────────────
// Core Domain Types — Scoor Admin
// ─────────────────────────────────────────────

export type EmotionLevel = "very_low" | "low" | "neutral" | "high" | "very_high";
export type AgendaCategory = "politics" | "culture" | "economy" | "environment" | "sports" | "technology" | "health";
export type AgendaStatus = "active" | "trending" | "closed" | "draft";
export type ReportReason = "spam" | "hate_speech" | "misinformation" | "harassment" | "inappropriate";
export type ReportStatus = "pending" | "reviewed" | "resolved" | "dismissed";
export type UserStatus = "active" | "suspended" | "banned" | "pending";
export type FeedType = "score" | "agenda_reaction" | "comment" | "share";

// ─────────────────────────────────────────────
// World topics (real backend — public.topics)
//
// Distinct from the mock `Agenda` types above: these mirror the live schema the
// iOS app reads. `TOPIC_CATEGORIES` must stay in sync with the iOS
// `WorldCategory` enum and the DB check constraint on `topics.category` — all
// three list the same raw values.
// ─────────────────────────────────────────────

export const TOPIC_CATEGORIES = [
  "sports",
  "politics",
  "society",
  "entertainment",
  "stocks",
  "crypto",
  "tech",
  "love",
  "work",
  "students",
  "night",
] as const;

/// 화면 표시용 한국어 라벨. 키(원시 값)는 iOS `WorldCategory`·DB check 제약과
/// 묶여 있으므로 절대 바꾸지 않는다 — 번역은 표시 계층에서만 한다.
export const TOPIC_CATEGORY_LABELS: Record<(typeof TOPIC_CATEGORIES)[number], string> = {
  sports: "스포츠",
  politics: "정치",
  society: "사회",
  entertainment: "연예",
  stocks: "주식",
  crypto: "코인",
  tech: "테크",
  love: "연애",
  work: "직장",
  students: "학생",
  night: "밤",
};

export const TOPIC_STATUSES = ["draft", "live", "closed"] as const;

export type TopicStatus = (typeof TOPIC_STATUSES)[number];

export interface AdminTopic {
  id: string;
  category: string;
  title: string;
  subtitle: string | null;
  coverEmoji: string | null;
  status: TopicStatus;
  createdAt: string;
  startsAt: string | null;
  endsAt: string | null;
  /** From `topic_stats`; 0 for a topic nobody has scored yet. */
  postsCount: number;
  globalScore: number;
}

// ─────────────────────────────────────────────
// User
// ─────────────────────────────────────────────

export interface User {
  id: string;
  username: string;
  email: string;
  avatarUrl: string | null;
  status: UserStatus;
  country: string;
  countryCode: string;
  lastScoor: number | null;
  totalScoors: number;
  streakDays: number;
  joinedAt: string;
  lastActiveAt: string;
  deviceOs: "ios" | "android" | "web";
}

export interface AdminUser {
  id: string;
  email: string;
  name: string;
  role: "super_admin" | "admin" | "moderator" | "viewer";
  avatarUrl: string | null;
  lastLoginAt: string;
}

// ─────────────────────────────────────────────
// Agenda (World Agenda)
// ─────────────────────────────────────────────

export interface Agenda {
  id: string;
  title: string;
  description: string;
  category: AgendaCategory;
  status: AgendaStatus;
  tags: string[];
  coverImageUrl: string | null;
  reactionCount: number;
  participantCount: number;
  avgScoor: number;
  trendDelta: number;
  createdAt: string;
  expiresAt: string | null;
  createdBy: string;
}

// ─────────────────────────────────────────────
// Feed Entry
// ─────────────────────────────────────────────

export interface FeedEntry {
  id: string;
  userId: string;
  username: string;
  avatarUrl: string | null;
  type: FeedType;
  scoorValue: number | null;
  reason: string | null;
  agendaId: string | null;
  agendaTitle: string | null;
  likeCount: number;
  commentCount: number;
  country: string;
  countryCode: string;
  isVisible: boolean;
  createdAt: string;
}

// ─────────────────────────────────────────────
// Report / Moderation
// ─────────────────────────────────────────────

export interface Report {
  id: string;
  reporterId: string;
  reporterUsername: string;
  targetType: "user" | "feed" | "agenda" | "comment";
  targetId: string;
  targetSummary: string;
  reason: ReportReason;
  status: ReportStatus;
  reviewedBy: string | null;
  createdAt: string;
  resolvedAt: string | null;
}

// ─────────────────────────────────────────────
// Notification
// ─────────────────────────────────────────────

export interface AdminNotification {
  id: string;
  type: "new_report" | "spike_detected" | "agenda_expired" | "system_alert" | "user_flagged";
  title: string;
  body: string;
  isRead: boolean;
  severity: "info" | "warning" | "critical";
  createdAt: string;
  meta: Record<string, string | number>;
}

// ─────────────────────────────────────────────
// Dashboard Metrics
// ─────────────────────────────────────────────

export interface KPIMetric {
  label: string;
  value: number;
  formatted: string;
  delta: number;
  deltaLabel: string;
  trend: "up" | "down" | "neutral";
  sparkline: number[];
}

export interface DashboardMetrics {
  dau: KPIMetric;
  wau: KPIMetric;
  todayScoorCount: KPIMetric;
  avgScoor: KPIMetric;
  activeAgendas: KPIMetric;
  pendingReports: KPIMetric;
}

// ─────────────────────────────────────────────
// World Pulse
// ─────────────────────────────────────────────

export interface CountryPulse {
  country: string;
  countryCode: string;
  avgScoor: number;
  participantCount: number;
  trend: "up" | "down" | "neutral";
  delta: number;
  emotionLevel: EmotionLevel;
  topAgendaTitle: string | null;
}

// ─────────────────────────────────────────────
// Scoor Trend (chart data)
// ─────────────────────────────────────────────

export interface ScoorTrendPoint {
  date: string;
  avgScoor: number;
  scoorCount: number;
  globalAvg: number;
}

// ─────────────────────────────────────────────
// Auth Session
// ─────────────────────────────────────────────

export interface AuthSession {
  user: AdminUser;
  token: string;
  expiresAt: string;
}

// ─────────────────────────────────────────────
// API Response wrappers
// ─────────────────────────────────────────────

export interface ApiResponse<T> {
  data: T;
  success: boolean;
  error?: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

// ─────────────────────────────────────────────
// Feed (spec-13 §3.3 — public.posts / feed_posts)
// ─────────────────────────────────────────────

/**
 * `Mood` rawValue와 1:1로 맞춰야 한다 (iOS `Scoor/Models/FeedModels.swift`).
 * 여기 없는 값을 넣으면 앱이 `.calm`으로 떨어뜨려 조용히 잘못된 태그가 붙는다.
 */
export const POST_MOODS = [
  "happy", "burnout", "lonely", "calm", "healing",
  "work", "love", "night", "students",
] as const;

export type PostMood = (typeof POST_MOODS)[number];

export const POST_MOOD_LABELS: Record<PostMood, string> = {
  happy: "행복",
  burnout: "번아웃",
  lonely: "외로움",
  calm: "고요",
  healing: "회복",
  work: "일",
  love: "사랑",
  night: "새벽",
  students: "학생",
};

/** `Weather` rawValue와 동일. */
export const POST_WEATHERS = ["sunny", "cloudy", "rainy", "snowy", "night"] as const;

export type PostWeather = (typeof POST_WEATHERS)[number];

/** `public.feed_posts` 한 행 (어드민은 service_role이라 숨김·삭제 글도 본다). */
export interface AdminPost {
  id: string;
  isOfficial: boolean;
  score: number;
  message: string;
  primaryMood: string;
  extraMoods: string[];
  weather: string | null;
  authorName: string | null;
  isHidden: boolean;
  deletedAt: string | null;
  likesCount: number;
  commentsCount: number;
  createdAt: string;
}
