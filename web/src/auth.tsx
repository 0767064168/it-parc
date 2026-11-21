import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react';
import { apiRequest } from './api';

export type User = {
  id: number;
  username: string;
  nom?: string;
  prenom?: string;
  role: 'admin' | 'technicien' | 'lecteur' | string;
  email?: string | null;
  avatarUrl?: string | null;
};

type Session = {
  token: string;
  user: User;
};

type AuthContextValue = {
  user: User | null;
  token: string | null;
  login: (username: string, password: string) => Promise<void>;
  logout: () => void;
};

const storageKey = 'parc-it-session';
const AuthContext = createContext<AuthContextValue | null>(null);

function readSession(): Session | null {
  try {
    const raw = localStorage.getItem(storageKey);
    if (!raw) return null;
    const value = JSON.parse(raw) as Session;
    return value.token && value.user ? value : null;
  } catch {
    return null;
  }
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(readSession);

  const logout = useCallback(() => {
    setSession(null);
    localStorage.removeItem(storageKey);
  }, []);

  useEffect(() => {
    window.addEventListener('parc-it:unauthorized', logout);
    return () => window.removeEventListener('parc-it:unauthorized', logout);
  }, [logout]);

  const login = useCallback(async (username: string, password: string) => {
    const result = await apiRequest<{ token: string; user: User }>('/auth/login', {
      method: 'POST',
      body: { username, password },
    });
    const nextSession = { token: result.token, user: result.user };
    localStorage.setItem(storageKey, JSON.stringify(nextSession));
    setSession(nextSession);
  }, []);

  const value = useMemo(
    () => ({
      user: session?.user ?? null,
      token: session?.token ?? null,
      login,
      logout,
    }),
    [session, login, logout],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) throw new Error('useAuth must be used within AuthProvider');
  return value;
}
