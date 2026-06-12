/** Static demo content that mirrors the real Scoor app surfaces. */

export type ScoreCard = {
  id: string;
  label: string;
  emoji: string;
  score: number;
  reason: string;
  when: string;
};

export const DAILY_CARDS: ScoreCard[] = [
  { id: "today", label: "Today", emoji: "☀️", score: 82, reason: "Shipped the thing. Felt good.", when: "now" },
  { id: "coffee", label: "Coffee", emoji: "☕️", score: 91, reason: "Single-origin, perfect pull.", when: "8:14 AM" },
  { id: "work", label: "Work", emoji: "💼", score: 64, reason: "Long standup, then deep focus.", when: "11:02 AM" },
  { id: "gym", label: "Gym", emoji: "🏋️", score: 77, reason: "New PB on deadlift.", when: "6:30 PM" },
  { id: "mood", label: "Mood", emoji: "🧠", score: 70, reason: "Calm, a little tired.", when: "9:10 PM" },
  { id: "date", label: "Date", emoji: "💘", score: 95, reason: "Couldn't stop laughing.", when: "9:40 PM" },
];

export type WorldTopic = {
  id: string;
  name: string;
  emoji: string;
  score: number;
  votes: number;
  delta: number;
};

export const WORLD_TOPICS: WorldTopic[] = [
  { id: "apple", name: "Apple", emoji: "", score: 74, votes: 248_300, delta: 2.1 },
  { id: "tesla", name: "Tesla", emoji: "⚡️", score: 58, votes: 191_044, delta: -3.4 },
  { id: "ai", name: "AI", emoji: "🤖", score: 69, votes: 502_887, delta: 5.8 },
  { id: "climate", name: "Climate", emoji: "🌍", score: 41, votes: 333_120, delta: -1.2 },
  { id: "politics", name: "Politics", emoji: "🏛️", score: 33, votes: 421_905, delta: 0.6 },
  { id: "sports", name: "Sports", emoji: "🏟️", score: 81, votes: 288_410, delta: 4.2 },
  { id: "music", name: "Music", emoji: "🎧", score: 88, votes: 176_220, delta: 1.9 },
  { id: "crypto", name: "Crypto", emoji: "🪙", score: 52, votes: 263_770, delta: -6.1 },
];

/** Heatmap grid — 30 days of a single person's daily score. */
export const HEATMAP: number[] = [
  62, 70, 48, 81, 90, 55, 30, 66, 74, 88, 92, 60, 45, 58, 77, 83, 95, 71, 64, 52,
  40, 68, 79, 86, 91, 73, 59, 66, 82, 88,
];

/** Sparkline trend for the stats screen (weekly average). */
export const WEEKLY_TREND = [54, 61, 58, 72, 66, 80, 76];
export const MONTHLY_TREND = [60, 58, 63, 71, 69, 74, 78, 72, 81, 79, 83, 80];

export type FeedPost = {
  id: string;
  user: string;
  handle: string;
  avatar: string;
  target: string;
  score: number;
  reason: string;
  likes: number;
  comments: number;
  when: string;
};

export const FEED: FeedPost[] = [
  {
    id: "1",
    user: "Maya",
    handle: "@mayadraws",
    avatar: "🦊",
    target: "Sunday reset",
    score: 89,
    reason: "Cleaned, cooked, called mom. 10/10 would Sunday again.",
    likes: 1240,
    comments: 88,
    when: "12m",
  },
  {
    id: "2",
    user: "Deon",
    handle: "@deon",
    avatar: "🐧",
    target: "The new Dune",
    score: 94,
    reason: "Saw it in IMAX. The sound design alone.",
    likes: 3410,
    comments: 240,
    when: "1h",
  },
  {
    id: "3",
    user: "Ivy",
    handle: "@ivy",
    avatar: "🐝",
    target: "Monday commute",
    score: 22,
    reason: "Train delayed 40 min. Rough start.",
    likes: 512,
    comments: 41,
    when: "3h",
  },
];

export const STAT_TILES = [
  { label: "Daily", value: "76", sub: "avg this week", trend: WEEKLY_TREND },
  { label: "Streak", value: "48", sub: "days in a row", trend: [40, 42, 43, 45, 46, 47, 48] },
  { label: "Scores", value: "1,204", sub: "all time", trend: [3, 6, 9, 12, 18, 24, 31] },
];

export const SHOWCASE_SCREENS = [
  { id: "home", title: "Home", caption: "Your daily score, front and center." },
  { id: "daily", title: "Daily Score", caption: "Tap a number. Add a reason. Done." },
  { id: "world", title: "World", caption: "How the planet feels, right now." },
  { id: "timeline", title: "Timeline", caption: "Every score you've ever given." },
  { id: "stats", title: "Statistics", caption: "Trends, streaks, and patterns." },
  { id: "profile", title: "Profile", caption: "Your scoring identity." },
] as const;

export type ScreenId = (typeof SHOWCASE_SCREENS)[number]["id"];
