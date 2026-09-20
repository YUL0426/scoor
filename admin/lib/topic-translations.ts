export const TOPIC_LANGUAGES = {
  en: "English", ja: "日本語", "zh-Hans": "简体中文", de: "Deutsch",
  fr: "Français", "pt-BR": "Português (Brasil)", es: "Español",
} as const;
export type TopicLanguage = keyof typeof TOPIC_LANGUAGES;
export interface TopicTranslation {
  title: string;
  subtitle: string;
  score_low_label: string;
  score_high_label: string;
}
export type TopicTranslations = Partial<Record<TopicLanguage, TopicTranslation>>;
export const emptyTopicTranslation = (): TopicTranslation => ({ title: "", subtitle: "", score_low_label: "", score_high_label: "" });

/** Same bounds as the database; preserve a complete translated question as one unit. */
export function parseTopicTranslations(input: unknown, requireAll = false): TopicTranslations {
  if (input === undefined) input = {};
  if (!input || typeof input !== "object" || Array.isArray(input)) throw new Error("번역은 언어별 객체여야 합니다.");
  const output: TopicTranslations = {};
  for (const [language, raw] of Object.entries(input)) {
    if (!Object.hasOwn(TOPIC_LANGUAGES, language)) throw new Error("지원하지 않는 번역 언어입니다.");
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) throw new Error(`${language}: 번역 형식이 올바르지 않습니다.`);
    const row = raw as Record<string, unknown>;
    const fields = ["title", "subtitle", "score_low_label", "score_high_label"] as const;
    if (Object.keys(row).some(key => !fields.includes(key as typeof fields[number]))) throw new Error(`${language}: 알 수 없는 번역 항목입니다.`);
    const translated = emptyTopicTranslation();
    for (const field of fields) {
      const value = row[field];
      if (field === "subtitle" && (value === undefined || value === null)) continue;
      if (typeof value !== "string") throw new Error(`${language}: 제목과 점수 기준을 모두 입력해 주세요.`);
      translated[field] = value.trim();
      const max = field === "title" ? 160 : field === "subtitle" ? 500 : 80;
      if ([...translated[field]].length > max || (field !== "subtitle" && !translated[field])) throw new Error(`${language}: ${field} 입력 길이를 확인해 주세요 (최대 ${max}자).`);
    }
    if (translated.score_low_label === translated.score_high_label) throw new Error(`${language}: 0점과 100점 기준을 다르게 입력해 주세요.`);
    output[language as TopicLanguage] = translated;
  }
  if (requireAll && Object.keys(TOPIC_LANGUAGES).some(language => !output[language as TopicLanguage])) throw new Error("공개 전에 7개 언어의 제목과 점수 기준을 모두 번역해 주세요.");
  return output;
}
