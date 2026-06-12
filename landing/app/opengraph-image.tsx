import { ImageResponse } from "next/og";

export const runtime = "edge";
export const alt = "Scoor — What score would you give it?";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function Og() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          padding: 72,
          background: "#0e0e12",
          fontFamily: "sans-serif",
          position: "relative",
        }}
      >
        <div
          style={{
            position: "absolute",
            top: -160,
            right: -120,
            width: 560,
            height: 560,
            borderRadius: 9999,
            background:
              "radial-gradient(circle, rgba(206,59,34,0.55), transparent 60%)",
            display: "flex",
          }}
        />
        <div
          style={{
            position: "absolute",
            bottom: -200,
            left: -120,
            width: 560,
            height: 560,
            borderRadius: 9999,
            background:
              "radial-gradient(circle, rgba(31,199,123,0.4), transparent 60%)",
            display: "flex",
          }}
        />

        <div style={{ display: "flex", alignItems: "center", gap: 16 }}>
          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              width: 64,
              height: 64,
              borderRadius: 18,
              background: "#ce3b22",
              color: "white",
              fontSize: 34,
              fontWeight: 800,
            }}
          >
            82
          </div>
          <div style={{ color: "white", fontSize: 34, fontWeight: 700 }}>Scoor</div>
        </div>

        <div style={{ display: "flex", flexDirection: "column" }}>
          <div
            style={{
              color: "white",
              fontSize: 78,
              fontWeight: 800,
              lineHeight: 1.02,
              letterSpacing: -2,
              maxWidth: 920,
            }}
          >
            What score would you give today?
          </div>
          <div style={{ color: "rgba(255,255,255,0.7)", fontSize: 32, marginTop: 24 }}>
            Score your day. Score the world. See how everyone feels.
          </div>
        </div>

        <div style={{ display: "flex", gap: 12 }}>
          {[
            ["0", "#e23a2e"],
            ["50", "#f5a623"],
            ["100", "#1fc77b"],
          ].map(([n, c]) => (
            <div
              key={n}
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                padding: "10px 22px",
                borderRadius: 9999,
                background: "rgba(255,255,255,0.08)",
                color: c,
                fontSize: 30,
                fontWeight: 700,
              }}
            >
              {n}
            </div>
          ))}
        </div>
      </div>
    ),
    { ...size }
  );
}
