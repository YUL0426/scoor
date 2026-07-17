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
}

const AuthContext = createContext<AuthContextValue>({
  user: null,
  isLoading: true,
  logout: () => {},
});

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AdminUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    let cancelled = false;
    // proxy.ts already blocks unauthenticated access server-side; this fetch
    // only hydrates the user object for the UI (avatar, email, role).
    fetchSessionUser().then((sessionUser) => {
      if (cancelled) return;
      setUser(sessionUser);
      setIsLoading(false);
      if (!sessionUser) router.replace("/login");
    });
    return () => {
      cancelled = true;
    };
  }, [router]);

  const logout = useCallback(() => {
    signOut().finally(() => {
      setUser(null);
      router.replace("/login");
    });
  }, [router]);

  return (
    <AuthContext.Provider value={{ user, isLoading, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}
