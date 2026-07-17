/** Ambient gradient-mesh background with animated color blobs + grain. */
export function MeshBackground() {
  return (
    <div aria-hidden className="pointer-events-none fixed inset-0 -z-10 overflow-hidden">
      <div className="absolute -left-[10%] top-[-8%] h-[46vw] w-[46vw] rounded-full bg-[radial-gradient(circle,rgba(206,59,34,0.22),transparent_62%)] blur-3xl animate-blob" />
      <div className="absolute right-[-8%] top-[18%] h-[40vw] w-[40vw] rounded-full bg-[radial-gradient(circle,rgba(245,166,35,0.20),transparent_62%)] blur-3xl animate-blob [animation-delay:-6s]" />
      <div className="absolute bottom-[-12%] left-[24%] h-[44vw] w-[44vw] rounded-full bg-[radial-gradient(circle,rgba(31,199,123,0.16),transparent_62%)] blur-3xl animate-blob [animation-delay:-11s]" />
      <div className="grain absolute inset-0 opacity-[0.035] mix-blend-multiply" />
    </div>
  );
}
