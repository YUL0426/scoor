import "server-only";
import { NextResponse } from "next/server";
export function checkOrigin(request: Request): NextResponse | null {
  const origin = request.headers.get("origin");
  if (request.headers.get("sec-fetch-site") === "cross-site") return denied();
  if (origin) {
    try {
      if (new URL(origin).host !== request.headers.get("host")) return denied();
    } catch {
      return denied();
    }
  }
  return null;
}
function denied() {
  return NextResponse.json(
    { error: "허용되지 않은 요청 출처입니다." },
    { status: 403 },
  );
}
