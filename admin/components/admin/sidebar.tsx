"use client";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import * as Dialog from "@radix-ui/react-dialog";
import {
  Search,
  Settings,
  ChevronsUpDown,
  LogOut,
  ArrowUpRight,
  X,
  CornerDownLeft,
} from "lucide-react";
import { useAuth } from "@/providers/auth-provider";
import { navigation } from "./navigation";

export function Sidebar() {
  const pathname = usePathname(),
    router = useRouter();
  const { user, logout, error } = useAuth();
  const [mobile, setMobile] = useState(false),
    [open, setOpen] = useState(false),
    [query, setQuery] = useState("");
  const [selected, setSelected] = useState(0);
  const searchTrigger = useRef<HTMLButtonElement>(null);
  const results = navigation.filter(
    (n) =>
      n.label.includes(query.trim()) ||
      n.href.includes(query.trim().toLowerCase()),
  );
  useEffect(() => {
    const search = () => {
      setOpen(true);
      setQuery("");
      setSelected(0);
    };
    const menu = () => setMobile((v) => !v);
    const key = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        search();
      }
      if (e.key === "Escape") setMobile(false);
    };
    window.addEventListener("keydown", key);
    window.addEventListener("scoor:search", search);
    window.addEventListener("scoor:menu", menu);
    return () => {
      window.removeEventListener("keydown", key);
      window.removeEventListener("scoor:search", search);
      window.removeEventListener("scoor:menu", menu);
    };
  }, []);
  function navigate(href: string) {
    setOpen(false);
    setMobile(false);
    router.push(href);
  }
  return (
    <>
      {mobile && (
        <button
          aria-label="메뉴 닫기"
          className="fixed inset-0 z-40 bg-black/60 md:hidden"
          onClick={() => setMobile(false)}
        />
      )}
      <aside
        aria-label="워크스페이스 탐색"
        className={`fixed inset-y-0 left-0 z-50 flex w-[232px] shrink-0 flex-col border-r border-white/6 bg-[#111214] transition-transform md:relative md:translate-x-0 ${mobile ? "translate-x-0 visible" : "-translate-x-full invisible md:visible"}`}
      >
        <div className="flex h-16 items-center gap-2.5 px-5">
          <span className="flex h-7 w-7 items-center justify-center rounded-[8px] bg-brand text-lg font-bold text-white">
            s
          </span>
          <span className="flex-1 font-semibold tracking-tight">
            Scoor{" "}
            <span className="ml-1 text-xs font-normal text-text-tertiary">
              워크스페이스
            </span>
          </span>
          <ChevronsUpDown size={13} className="text-text-tertiary" />
        </div>
        <button
          ref={searchTrigger}
          onClick={() => {
            setQuery("");
            setSelected(0);
            setOpen(true);
          }}
          className="mx-3 mb-5 flex h-8 items-center gap-2 rounded-md border border-white/8 px-2.5 text-xs text-text-secondary hover:bg-white/5"
          aria-label="페이지 검색"
        >
          <Search size={13} />
          <span className="flex-1 text-left">빠른 이동</span>
          <kbd className="text-[10px] text-text-tertiary">⌘ K</kbd>
        </button>
        <nav className="flex-1 overflow-y-auto px-3" aria-label="주 메뉴">
          {["워크스페이스", "콘텐츠", "미리보기"].map((group) => (
            <div key={group} className="mb-6">
              <p className="mb-2 px-2 text-[11px] text-text-tertiary">
                {group}
              </p>
              {navigation
                .filter(
                  (n) => n.group === group && n.href !== "/admin/settings",
                )
                .map((n) => (
                  <Link
                    key={n.href}
                    href={n.href}
                    onClick={() => setMobile(false)}
                    aria-current={pathname === n.href ? "page" : undefined}
                    className={`my-0.5 flex items-center gap-2.5 rounded-md px-2.5 py-2 text-[13px] ${pathname === n.href ? "bg-white/7 text-text-primary" : "text-text-secondary hover:bg-white/4 hover:text-text-primary"}`}
                  >
                    <n.icon size={15} strokeWidth={1.7} />
                    <span>{n.label}</span>
                    {n.preview && (
                      <span className="ml-auto text-[10px] text-text-tertiary">
                        샘플
                      </span>
                    )}
                  </Link>
                ))}
            </div>
          ))}
        </nav>
        <div className="space-y-1 px-3 pb-4">
          <Link
            href="/admin/settings"
            onClick={() => setMobile(false)}
            aria-current={pathname === "/admin/settings" ? "page" : undefined}
            className="flex items-center gap-2.5 rounded-md px-2.5 py-2 text-text-secondary hover:bg-white/5"
          >
            <Settings size={15} />
            설정
          </Link>
          <a
            href="https://scoor.app"
            target="_blank"
            rel="noreferrer"
            className="flex items-center justify-between px-2.5 py-2 text-xs text-text-tertiary hover:text-text-primary"
          >
            Scoor 웹사이트
            <ArrowUpRight size={13} />
          </a>
        </div>
        {error && (
          <p role="alert" className="mx-4 mb-2 text-xs text-red-300">
            {error}
          </p>
        )}
        <div className="flex items-center gap-2.5 border-t border-white/6 px-4 py-4">
          <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full border border-white/10 bg-white/5 text-xs">
            {user?.name?.[0] ?? "S"}
          </span>
          <div className="min-w-0 flex-1">
            <p className="text-xs">{user?.name ?? "관리자"}</p>
            <p className="truncate text-[10px] text-text-tertiary">
              {user?.email ?? "세션 확인 중"}
            </p>
          </div>
          <button
            onClick={logout}
            className="ui-icon"
            aria-label="로그아웃"
            title="로그아웃"
          >
            <LogOut size={14} />
          </button>
        </div>
      </aside>
      <Dialog.Root open={open} onOpenChange={setOpen}>
        <Dialog.Portal>
          <Dialog.Overlay className="dialog-overlay" />
          <Dialog.Content
            className="dialog-content command-dialog"
            onCloseAutoFocus={(e) => {
              e.preventDefault();
              searchTrigger.current?.focus();
            }}
          >
            <Dialog.Title className="sr-only">페이지 빠른 이동</Dialog.Title>
            <Dialog.Description className="sr-only">
              페이지 이름으로 검색하고 위아래 방향키와 Enter로 이동하세요.
            </Dialog.Description>
            <div className="flex items-center gap-3 border-b border-white/10 p-4">
              <Search size={17} className="text-text-tertiary" />
              <input
                autoFocus
                role="combobox"
                aria-expanded={true}
                aria-controls="command-results"
                aria-activedescendant={
                  results[selected] ? `command-${selected}` : undefined
                }
                aria-label="페이지 이름 검색"
                value={query}
                onChange={(e) => {
                  setQuery(e.target.value);
                  setSelected(0);
                }}
                onKeyDown={(e) => {
                  if (e.key === "ArrowDown") {
                    e.preventDefault();
                    setSelected((v) => Math.min(v + 1, results.length - 1));
                  }
                  if (e.key === "ArrowUp") {
                    e.preventDefault();
                    setSelected((v) => Math.max(v - 1, 0));
                  }
                  if (e.key === "Enter" && results[selected]) {
                    e.preventDefault();
                    navigate(results[selected].href);
                  }
                }}
                placeholder="어디로 이동할까요?"
                className="flex-1 bg-transparent outline-none"
              />
              <Dialog.Close className="ui-icon" aria-label="검색 닫기">
                <X size={15} />
              </Dialog.Close>
            </div>
            <div
              className="p-2"
              id="command-results"
              role="listbox"
              aria-label="이동할 페이지"
            >
              {results.map((n, i) => (
                <button
                  key={n.href}
                  id={`command-${i}`}
                  role="option"
                  aria-selected={selected === i}
                  onClick={() => navigate(n.href)}
                  onMouseEnter={() => setSelected(i)}
                  className={`flex w-full items-center gap-3 rounded-md px-3 py-3 text-sm ${selected === i ? "bg-white/7" : ""}`}
                >
                  <n.icon size={16} />
                  <span>{n.label}</span>
                  <span className="ml-auto text-xs text-text-tertiary">
                    {n.preview ? "샘플 화면" : n.group}
                  </span>
                  {selected === i && <CornerDownLeft size={12} />}
                </button>
              ))}
              {!results.length && (
                <p className="p-8 text-center text-text-tertiary">
                  일치하는 페이지가 없습니다.
                </p>
              )}
            </div>
            <div className="border-t border-white/8 px-4 py-2.5 text-[11px] text-text-tertiary">
              ↑ ↓ 선택 <span className="mx-3">↵ 이동</span> esc 닫기
            </div>
          </Dialog.Content>
        </Dialog.Portal>
      </Dialog.Root>
    </>
  );
}
