"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { Eye, EyeOff, ArrowRight, ShieldCheck } from "lucide-react";
import { signIn, AuthConfigError } from "@/lib/auth";
import { Input } from "@/components/ui/input";
export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState(""),
    [password, setPassword] = useState(""),
    [show, setShow] = useState(false),
    [loading, setLoading] = useState(false),
    [error, setError] = useState<string | null>(null);
  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (loading) return;
    setLoading(true);
    setError(null);
    try {
      const user = await signIn(email, password);
      if (!user) {
        setError("이메일 또는 비밀번호가 올바르지 않습니다.");
        return;
      }
      router.replace("/admin");
    } catch (e) {
      setError(
        e instanceof AuthConfigError
          ? "로그인을 사용할 수 없습니다. 관리자에게 연결 설정을 확인해 주세요."
          : "연결하지 못했습니다. 잠시 후 다시 시도해 주세요.",
      );
    } finally {
      setLoading(false);
    }
  }
  return (
    <main className="flex min-h-dvh flex-col bg-bg-base">
      <div className="flex items-center gap-2.5 px-7 py-6">
        <span className="flex h-7 w-7 items-center justify-center rounded-lg bg-brand text-lg font-bold text-white">
          s
        </span>
        <span className="font-semibold">Scoor</span>
        <span className="ml-2 text-xs text-text-tertiary">워크스페이스</span>
      </div>
      <div className="flex flex-1 items-center justify-center px-6 pb-20">
        <div className="w-full max-w-[340px]">
          <span className="mb-7 flex h-12 w-12 items-center justify-center rounded-xl border border-white/10 bg-white/3">
            <ShieldCheck
              size={22}
              strokeWidth={1.4}
              className="text-text-secondary"
            />
          </span>
          <h1 className="text-[26px] font-semibold tracking-[-.8px]">
            다시 만나 반가워요.
          </h1>
          <p className="mb-8 mt-2 text-sm text-text-secondary">
            Scoor 운영 워크스페이스에 로그인하세요.
          </p>
          <form onSubmit={submit} className="space-y-5">
            <Input
              label="이메일"
              type="email"
              autoComplete="username"
              placeholder="name@company.com"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
            <Input
              label="비밀번호"
              type={show ? "text" : "password"}
              autoComplete="current-password"
              placeholder="비밀번호를 입력하세요"
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              rightIcon={
                <button
                  type="button"
                  aria-label={show ? "비밀번호 숨기기" : "비밀번호 보기"}
                  onClick={() => setShow((v) => !v)}
                  className="ui-icon"
                >
                  {show ? <EyeOff size={15} /> : <Eye size={15} />}
                </button>
              }
            />
            {error && (
              <p role="alert" className="ui-error">
                {error}
              </p>
            )}
            <button
              className="ui-button primary !w-full !py-2.5"
              disabled={loading}
            >
              {loading ? "로그인 중…" : "로그인"}
              <ArrowRight size={14} />
            </button>
          </form>
          <p className="mt-6 text-center text-[11px] text-text-tertiary">
            등록된 관리자만 접근할 수 있습니다.
          </p>
        </div>
      </div>
      <footer className="px-7 py-5 text-[11px] text-text-tertiary">
        SCOOR · ADMIN WORKSPACE
      </footer>
    </main>
  );
}
