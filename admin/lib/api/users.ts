import type { User, PaginatedResponse } from "@/types";
import { mockUsers } from "@/lib/mock/users";

export async function getUsers(
  page = 1,
  pageSize = 20,
  search?: string
): Promise<PaginatedResponse<User>> {
  await new Promise((r) => setTimeout(r, 100));

  let filtered = mockUsers;
  if (search) {
    const q = search.toLowerCase();
    filtered = mockUsers.filter(
      (u) =>
        u.username.toLowerCase().includes(q) ||
        u.email.toLowerCase().includes(q) ||
        u.country.toLowerCase().includes(q)
    );
  }

  const start = (page - 1) * pageSize;
  return {
    data: filtered.slice(start, start + pageSize),
    total: filtered.length,
    page,
    pageSize,
    hasMore: start + pageSize < filtered.length,
  };
}

export async function getUserById(id: string): Promise<User | null> {
  await new Promise((r) => setTimeout(r, 80));
  return mockUsers.find((u) => u.id === id) ?? null;
}
