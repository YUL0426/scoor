"use client";

import {
  createContext,
  useContext,
  useEffect,
  useState,
  useCallback,
  type ReactNode,
} from "react";
import { useRouter } from "next/navigation";
import { fetchSessionUser, signOut } from "@/lib/auth";
import type { AdminUser } from "@/types";

interface AuthContextValue {
  user: AdminUser | null;
  isLoading: boolean;
  logout: () => void;
  error: string | null;
}

const AuthContext = createContext<AuthContextValue>({
  user: null,
  isLoading: true,
  logout: () => {},
  error: null,
});

export function AuthProvider({ children }: { children: ReactNode }) {
  const [error, setError] = useState<string | null>(null);
  const [user, setUser] = useState<AdminUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    let cancelled = false;
    // proxy.ts already blocks unauthenticated access server-side; this fetch
    // only hydrates the user object for the UI (avatar, email, role).
    fetchSessionUser()
      .then((sessionUser) => {
        if (cancelled) return;
        setUser(sessionUser);
        setIsLoading(false);
        if (!sessionUser) router.replace("/login");
      })
      .catch(() => {
        if (!cancelled) {
          setError("세션 확인에 실패했습니다. 페이지를 새로고침해 주세요.");
          setIsLoading(false);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [router]);

  const logout = useCallback(() => {
    setError(null);
    signOut()
      .then(() => {
        setUser(null);
        router.replace("/login");
      })
      .catch(() => setError("로그아웃에 실패했습니다. 다시 시도해 주세요."));
  }, [router]);

  return (
    <AuthContext.Provider value={{ user, isLoading, logout, error }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
