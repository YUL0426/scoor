"use client";
import * as Dialog from "@radix-ui/react-dialog";
import { X, Search, RefreshCw, Plus } from "lucide-react";
import type { ReactNode } from "react";
export function CreateDialog({
  title,
  description,
  open,
  onOpenChange,
  children,
}: {
  title: string;
  description: string;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  children: ReactNode;
}) {
  return (
    <Dialog.Root open={open} onOpenChange={onOpenChange}>
      <Dialog.Trigger asChild>
        <button className="ui-button primary">
          <Plus size={14} />
          {title}
        </button>
      </Dialog.Trigger>
      <Dialog.Portal>
        <Dialog.Overlay className="dialog-overlay" />
        <Dialog.Content className="dialog-content">
          <div className="mb-5 flex items-start gap-4">
            <div className="flex-1">
              <Dialog.Title className="text-lg font-semibold tracking-tight">
                {title}
              </Dialog.Title>
              <Dialog.Description className="mt-1 text-xs text-text-secondary">
                {description}
              </Dialog.Description>
            </div>
            <Dialog.Close className="ui-icon" aria-label="작성 창 닫기">
              <X size={17} />
            </Dialog.Close>
          </div>
          {children}
        </Dialog.Content>
      </Dialog.Portal>
    </Dialog.Root>
  );
}
export function ListToolbar({
  query,
  onQuery,
  filter,
  onFilter,
  tabs,
  onRefresh,
  loading,
}: {
  query: string;
  onQuery: (v: string) => void;
  filter: string;
  onFilter: (v: string) => void;
  tabs: { value: string; label: string; count: number }[];
  onRefresh: () => void;
  loading: boolean;
}) {
  return (
    <div className="ui-toolbar">
      <div className="ui-tabs" role="group" aria-label="상태 필터">
        {tabs.map((t) => (
          <button
            key={t.value}
            aria-pressed={filter === t.value}
            onClick={() => onFilter(t.value)}
          >
            {t.label}
            <span className="ml-1.5 text-[10px] text-text-tertiary">
              {loading ? "—" : t.count}
            </span>
          </button>
        ))}
      </div>
      <div className="flex items-center gap-2">
        <label className="flex items-center gap-2 rounded-md border border-white/10 bg-bg-base px-2.5 py-1.5">
          <Search size={13} className="text-text-tertiary" />
          <input
            aria-label="목록 검색"
            placeholder="목록 검색…"
            value={query}
            onChange={(e) => onQuery(e.target.value)}
            className="w-32 bg-transparent text-xs outline-none"
          />
          {query && (
            <button
              className="text-text-tertiary"
              aria-label="검색 지우기"
              onClick={() => onQuery("")}
            >
              <X size={12} />
            </button>
          )}
        </label>
        <button
          className="ui-icon"
          onClick={onRefresh}
          disabled={loading}
          aria-label="목록 새로고침"
          title="새로고침"
        >
          <RefreshCw size={14} className={loading ? "animate-spin" : ""} />
        </button>
      </div>
    </div>
  );
}
