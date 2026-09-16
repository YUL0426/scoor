"use client";
import { Menu, ChevronRight, Search } from "lucide-react";
import { usePathname } from "next/navigation";
import { navigation } from "./navigation";
export function Header({
  title,
  subtitle,
}: {
  title: string;
  subtitle?: string;
}) {
  const path = usePathname();
  const preview = navigation.find((n) => n.href === path)?.preview;
  return (
    <>
      <header className="flex h-14 shrink-0 items-center gap-3 border-b border-white/6 bg-[#191a1d]/60 px-4 md:px-7">
        <button
          className="ui-icon md:!hidden"
          aria-label="메뉴 열기"
          onClick={() => window.dispatchEvent(new Event("scoor:menu"))}
        >
          <Menu size={17} />
        </button>
        <span className="hidden text-xs text-text-tertiary sm:block">
          워크스페이스
        </span>
        <ChevronRight
          size={12}
          className="hidden text-text-tertiary sm:block"
        />
        <h1 className="text-[13px] font-medium">{title}</h1>
        <span className="flex-1" />
        {preview && <span className="ui-pill">샘플 데이터</span>}
        <button
          className="ui-icon"
          title="빠른 이동 (⌘K)"
          aria-label="빠른 이동"
          onClick={() => window.dispatchEvent(new Event("scoor:search"))}
        >
          <Search size={15} />
        </button>
      </header>
      {preview && (
        <div
          role="note"
          className="border-b border-white/8 bg-white/2 px-6 py-3 text-xs text-text-secondary"
        >
          미리보기 화면입니다. 표시된 수치는 샘플이며 실제 사용자·신고·알림
          상태를 반영하지 않습니다.
        </div>
      )}
      {subtitle && <p className="sr-only">{subtitle}</p>}
    </>
  );
}
