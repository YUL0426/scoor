"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { Eye, EyeOff, Zap, AlertCircle } from "lucide-react";
import { signIn, AuthConfigError } from "@/lib/auth";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPass, setShowPass] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [mounted, setMounted] = useState(false);

  // Already-authenticated visitors are redirected to /admin by proxy.ts
  // before this page renders — no client-side session check needed.
  useEffect(() => {
    setMounted(true);
  }, []);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      const user = await signIn(email, password);
      if (!user) {
        setError("Invalid credentials. Please check your email and password.");
        setLoading(false);
        return;
      }
      router.replace("/admin");
    } catch (err) {
      setError(
        err instanceof AuthConfigError
          ? "Admin auth is not configured. Set ADMIN_EMAIL, ADMIN_PASSWORD_SHA256, and ADMIN_SESSION_SECRET."
          : "An unexpected error occurred. Please try again."
      );
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center relative overflow-hidden bg-[#060610]">
      {/* Ambient gradients */}
      <div className="absolute inset-0 pointer-events-none">
        <div className="absolute top-0 left-1/2 -translate-x-1/2 w-[800px] h-[400px] bg-[#f42525] rounded-full opacity-[0.04] blur-[100px]" />
        <div className="absolute bottom-0 left-0 w-[500px] h-[300px] bg-[#4f8ef7] rounded-full opacity-[0.04] blur-[80px]" />
        <div className="absolute bottom-0 right-0 w-[400px] h-[300px] bg-[#a855f7] rounded-full opacity-[0.03] blur-[80px]" />
      </div>

      {/* Grid overlay */}
      <div
        className="absolute inset-0 pointer-events-none opacity-[0.02]"
        style={{
          backgroundImage: `linear-gradient(rgba(255,255,255,0.3) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.3) 1px, transparent 1px)`,
          backgroundSize: "40px 40px",
        }}
      />

      {/* Login card */}
      <div
        className={cn(
          "relative w-full max-w-sm mx-4 transition-all duration-500",
          mounted ? "opacity-100 translate-y-0" : "opacity-0 translate-y-4"
        )}
      >
        {/* Card */}
        <div className="bg-[#0d0d1f]/90 backdrop-blur-xl border border-white/8 rounded-2xl p-8 shadow-2xl">
          {/* Logo */}
          <div className="flex flex-col items-center mb-8">
            <div className="flex items-center justify-center w-12 h-12 rounded-2xl bg-[#f42525] shadow-[0_0_24px_rgba(244,37,37,0.4)] mb-4">
              <Zap className="h-6 w-6 text-white" strokeWidth={2.5} />
            </div>
            <h1 className="text-xl font-bold text-[#f4f4f6] tracking-tight">
              scoor admin
            </h1>
            <p className="text-xs text-[#52526c] mt-1">Operations Control Center</p>
          </div>

          {/* Status bar */}
          <div className="flex items-center justify-center gap-6 mb-8 py-3 px-4 bg-white/3 rounded-xl border border-white/6">
            <div className="flex flex-col items-center gap-1">
              <span className="text-base font-bold text-emerald-400 tabular-nums">24.9K</span>
              <span className="text-[10px] text-[#52526c] uppercase tracking-wider">DAU</span>
            </div>
            <div className="w-px h-8 bg-white/8" />
            <div className="flex flex-col items-center gap-1">
              <span className="text-base font-bold text-[#f42525] tabular-nums">67.3</span>
              <span className="text-[10px] text-[#52526c] uppercase tracking-wider">Avg Scoor</span>
            </div>
            <div className="w-px h-8 bg-white/8" />
            <div className="flex flex-col items-center gap-1">
              <div className="flex items-center gap-1">
                <span className="w-1.5 h-1.5 bg-emerald-400 rounded-full animate-pulse" />
                <span className="text-base font-bold text-[#f4f4f6] tabular-nums">18</span>
              </div>
              <span className="text-[10px] text-[#52526c] uppercase tracking-wider">Agendas</span>
            </div>
          </div>

          {/* Form */}
          <form onSubmit={handleSubmit} className="space-y-4">
            <Input
              label="Email"
              type="email"
              placeholder="admin@scoor.app"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="email"
              required
            />

            <Input
              label="Password"
              type={showPass ? "text" : "password"}
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              required
              rightIcon={
                <button
                  type="button"
                  onClick={() => setShowPass(!showPass)}
                  className="text-[#52526c] hover:text-[#8b8ba4] transition-colors"
                >
                  {showPass ? (
                    <EyeOff className="h-4 w-4" />
                  ) : (
                    <Eye className="h-4 w-4" />
                  )}
                </button>
              }
            />

            {error && (
              <div className="flex items-start gap-2.5 px-3 py-2.5 bg-red-500/8 border border-red-500/20 rounded-lg">
                <AlertCircle className="h-4 w-4 text-red-400 flex-shrink-0 mt-0.5" />
                <p className="text-xs text-red-400">{error}</p>
              </div>
            )}

            <Button
              type="submit"
              className="w-full mt-2"
              size="lg"
              loading={loading}
            >
              {loading ? "Authenticating…" : "Sign In"}
            </Button>
          </form>

          {/* Hint */}
          <p className="text-center text-[10px] text-[#52526c] mt-6">
            Protected access · Scoor Admin v1.0
          </p>
        </div>
      </div>
    </div>
  );
}
