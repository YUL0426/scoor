import { Navbar } from "@/components/layout/Navbar";
import { Footer } from "@/components/layout/Footer";
import { SmartBanner } from "@/components/layout/SmartBanner";
import { MeshBackground } from "@/components/sections/Background";
import { Hero } from "@/components/sections/Hero";
import { HowItWorks } from "@/components/sections/HowItWorks";
import { DailyLife } from "@/components/sections/DailyLife";
import { WorldScores } from "@/components/sections/WorldScores";
import { Insights } from "@/components/sections/Insights";
import { SocialLayer } from "@/components/sections/SocialLayer";
import { ScreensShowcase } from "@/components/sections/ScreensShowcase";
import { DownloadCTA } from "@/components/sections/DownloadCTA";

export default function Home() {
  return (
    <>
      <SmartBanner />
      <Navbar />
      <MeshBackground />
      <main>
        <Hero />
        <HowItWorks />
        <DailyLife />
        <WorldScores />
        <Insights />
        <SocialLayer />
        <ScreensShowcase />
        <DownloadCTA />
      </main>
      <Footer />
    </>
  );
}
