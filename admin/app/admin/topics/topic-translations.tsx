"use client";

import { useState } from "react";
import { CreateDialog } from "@/components/admin/content-tools";
import { TOPIC_LANGUAGES, emptyTopicTranslation, parseTopicTranslations, type TopicLanguage, type TopicTranslations } from "@/lib/topic-translations";
import type { AdminTopic } from "@/types";

export function TopicTranslationFields({ value, onChange }: { value: TopicTranslations; onChange: (value: TopicTranslations) => void }) {
  const [language, setLanguage] = useState<TopicLanguage>("en");
  const translation = value[language] ?? emptyTopicTranslation();
  return <fieldset className="space-y-3 rounded-lg border border-white/10 p-3">
    <legend className="px-1 text-sm font-medium">다국어 번역</legend>
    <p className="text-xs text-text-secondary">한국어 원문의 의미를 유지해 주세요. 공개하려면 7개 언어의 번역이 필요합니다.</p>
    <label className="flex flex-col gap-1 text-xs">번역 언어
      <select className="w-full rounded-md border border-white/10 bg-bg-base px-3 py-2 text-sm outline-none focus:border-[#e36b59]" value={language} onChange={event => setLanguage(event.target.value as TopicLanguage)}>
        {Object.entries(TOPIC_LANGUAGES).map(([key, label]) => <option key={key} value={key}>{label}{value[key as TopicLanguage]?.title ? " · 작성됨" : ""}</option>)}
      </select>
    </label>
    {([
      ["title", "번역 제목", 160], ["subtitle", "번역 설명", 500],
      ["score_low_label", "번역 0점 기준", 80], ["score_high_label", "번역 100점 기준", 80],
    ] as const).map(([key, label, max]) => <label key={key} className="flex flex-col gap-1 text-xs">
      {label}
      <input className="w-full rounded-md border border-white/10 bg-bg-base px-3 py-2 text-sm outline-none focus:border-[#e36b59]" value={translation[key]} maxLength={max} lang={language}
        onChange={event => {
          const next = { ...translation, [key]: event.target.value };
          const updated = { ...value, [language]: next };
          if (Object.values(next).every(text => !text.trim())) delete updated[language];
          onChange(updated);
        }} />
    </label>)}
  </fieldset>;
}

export function EditTopicTranslations({ topic, onSaved }: { topic: AdminTopic; onSaved: () => Promise<void> }) {
  const [open, setOpen] = useState(false);
  const [translations, setTranslations] = useState(topic.translations);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  return <CreateDialog title="번역 관리" description={`${topic.title} · 원문과 기존 참여 기록은 유지됩니다.`}
    open={open} onOpenChange={next => {
      if (saving) return;
      if (next) { setTranslations(topic.translations); setError(""); }
      setOpen(next);
    }}>
    <form className="space-y-4" onSubmit={async event => {
      event.preventDefault(); setSaving(true); setError("");
      try {
        const value = parseTopicTranslations(translations, topic.origin === "admin" && ["live", "closed"].includes(topic.status));
        const response = await fetch(`/api/topics/${topic.id}`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ translations: value }) });
        const result = await response.json();
        if (!response.ok) throw new Error(result.error ?? "번역을 저장하지 못했습니다.");
        await onSaved(); setOpen(false);
      } catch (error) { setError(error instanceof Error ? error.message : "번역을 저장하지 못했습니다."); }
      finally { setSaving(false); }
    }}>
      <p className="text-sm">한국어: {topic.title}<br />{topic.subtitle}<br />0: {topic.lowLabel} · 100: {topic.highLabel}</p>
      <fieldset disabled={saving}><TopicTranslationFields value={translations} onChange={setTranslations} /></fieldset>
      {error && <p role="alert" className="ui-error">{error}</p>}
      <button type="submit" className="ui-button primary" disabled={saving}>{saving ? "저장 중…" : "번역 저장"}</button>
    </form>
  </CreateDialog>;
}
