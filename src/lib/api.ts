export const API_BASE = process.env.NEXT_PUBLIC_API_BASE || "";

export function apiUrl(path: string) {
  // Expect callers to pass paths like "/api/projects" (existing code).
  // If NEXT_PUBLIC_API_BASE is set, prefix it; otherwise use the relative path.
  if (API_BASE && path.startsWith("/api/")) return `${API_BASE}${path}`;
  return path;
}

export function withAuth(init: RequestInit = {}): RequestInit {
  if (typeof window === "undefined") return init;
  const token = localStorage.getItem("bearer_token");
  const headers: Record<string, string> = {
    ...(init.headers as Record<string, string>),
  };
  if (token) headers["Authorization"] = `Bearer ${token}`;
  return { ...init, headers };
}

export async function apiFetch(path: string, init?: RequestInit) {
  const url = apiUrl(path);
  return fetch(url, init);
}