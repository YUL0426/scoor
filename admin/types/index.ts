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
