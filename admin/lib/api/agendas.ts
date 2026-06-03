import type { Agenda, PaginatedResponse } from "@/types";
import { mockAgendas } from "@/lib/mock/agendas";

export async function getAgendas(
  page = 1,
  pageSize = 20,
  status?: string
): Promise<PaginatedResponse<Agenda>> {
  await new Promise((r) => setTimeout(r, 100));

  let filtered = mockAgendas;
  if (status && status !== "all") {
    filtered = mockAgendas.filter((a) => a.status === status);
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

export async function getAgendaById(id: string): Promise<Agenda | null> {
  await new Promise((r) => setTimeout(r, 80));
  return mockAgendas.find((a) => a.id === id) ?? null;
}
