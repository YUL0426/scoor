import type { DashboardMetrics, ScoorTrendPoint, CountryPulse } from "@/types";

export const mockDashboardMetrics: DashboardMetrics = {
  dau: {
    label: "일간 활성 사용자",
    value: 24_871,
    formatted: "24.9K",
    delta: 12.4,
    deltaLabel: "vs yesterday",
    trend: "up",
    sparkline: [18200, 19400, 21000, 20100, 22400, 23100, 24871, 24100],
  },
  wau: {
    label: "주간 활성 사용자",
    value: 142_390,
    formatted: "142.4K",
    delta: 8.2,
    deltaLabel: "vs last week",
    trend: "up",
    sparkline: [120000, 128000, 131000, 135000, 138000, 140000, 142390, 141800],
  },
  todayScoorCount: {
    label: "오늘 기록된 점수",
    value: 31_204,
    formatted: "31.2K",
    delta: 5.7,
    deltaLabel: "vs yesterday",
    trend: "up",
    sparkline: [24000, 26000, 28000, 27500, 29000, 30100, 31204, 30800],
  },
  avgScoor: {
    label: "오늘 평균 점수",
    value: 67.3,
    formatted: "67.3",
    delta: -2.1,
    deltaLabel: "vs yesterday",
    trend: "down",
    sparkline: [71, 69, 68, 70, 67, 66, 67.3, 68],
  },
  activeAgendas: {
    label: "진행 중 아젠다",
    value: 18,
    formatted: "18",
    delta: 3,
    deltaLabel: "new this week",
    trend: "up",
    sparkline: [12, 13, 14, 15, 16, 17, 18, 18],
  },
  pendingReports: {
    label: "미처리 신고",
    value: 7,
    formatted: "7",
    delta: -4,
    deltaLabel: "vs yesterday",
    trend: "down",
    sparkline: [15, 12, 11, 9, 10, 11, 7, 8],
  },
};

export const mockScoorTrend: ScoorTrendPoint[] = (() => {
  const now = new Date();
  return Array.from({ length: 30 }, (_, i) => {
    const d = new Date(now);
    d.setDate(d.getDate() - (29 - i));
    const base = 65 + Math.sin(i * 0.4) * 8;
    return {
      date: d.toISOString().split("T")[0],
      avgScoor: parseFloat((base + (Math.random() - 0.5) * 6).toFixed(1)),
      scoorCount: Math.floor(24000 + Math.random() * 10000),
      globalAvg: parseFloat((62 + (Math.random() - 0.5) * 4).toFixed(1)),
    };
  });
})();

export const mockWorldPulse: CountryPulse[] = [
  {
    country: "일본",
    countryCode: "JP",
    avgScoor: 78.4,
    participantCount: 4820,
    trend: "up",
    delta: 3.2,
    emotionLevel: "high",
    topAgendaTitle: "벚꽃 시즌",
  },
  {
    country: "대한민국",
    countryCode: "KR",
    avgScoor: 72.1,
    participantCount: 3910,
    trend: "up",
    delta: 1.8,
    emotionLevel: "high",
    topAgendaTitle: "K-Pop World Tour",
  },
  {
    country: "브라질",
    countryCode: "BR",
    avgScoor: 81.2,
    participantCount: 5230,
    trend: "up",
    delta: 5.4,
    emotionLevel: "very_high",
    topAgendaTitle: "Copa América",
  },
  {
    country: "독일",
    countryCode: "DE",
    avgScoor: 58.9,
    participantCount: 2140,
    trend: "down",
    delta: -4.1,
    emotionLevel: "neutral",
    topAgendaTitle: "경제 불확실성",
  },
  {
    country: "미국",
    countryCode: "US",
    avgScoor: 63.7,
    participantCount: 8920,
    trend: "neutral",
    delta: 0.3,
    emotionLevel: "neutral",
    topAgendaTitle: "선거 시즌",
  },
  {
    country: "인도",
    countryCode: "IN",
    avgScoor: 70.5,
    participantCount: 6340,
    trend: "up",
    delta: 2.9,
    emotionLevel: "high",
    topAgendaTitle: "IPL 시즌",
  },
  {
    country: "프랑스",
    countryCode: "FR",
    avgScoor: 55.2,
    participantCount: 1820,
    trend: "down",
    delta: -2.8,
    emotionLevel: "low",
    topAgendaTitle: "정치적 긴장",
  },
  {
    country: "호주",
    countryCode: "AU",
    avgScoor: 74.8,
    participantCount: 2110,
    trend: "up",
    delta: 4.0,
    emotionLevel: "high",
    topAgendaTitle: "여름 분위기",
  },
];
