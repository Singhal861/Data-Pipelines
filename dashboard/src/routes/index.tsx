import { useEffect, useState } from "react";
import { Moon, Sun, Github, Mail, Phone } from "lucide-react";
import { createFileRoute } from "@tanstack/react-router";
import { TournamentSummary } from "@/components/fifa/TournamentSummary";
import { TournamentBracket } from "@/components/fifa/TournamentBracket";
import { TopScorers } from "@/components/fifa/TopScorers";
import { LiveOrResults } from "@/components/fifa/LiveOrResults";
import { FinishedMatchesTable } from "@/components/fifa/FinishedMatchesTable";
import { PointsTable } from "@/components/fifa/PointsTable";
import { GoldenBootProgression } from "@/components/fifa/GoldenBootProgression";

export const Route = createFileRoute("/")({
  head: () => ({
    meta: [
      { title: "FIFA World Cup 2026 — Live Dashboard" },
      {
        name: "description",
        content:
          "Live bracket, top scorers, points table, golden boot race and tournament summary for FIFA World Cup 2026.",
      },
      { property: "og:title", content: "FIFA World Cup 2026 — Live Dashboard" },
      {
        property: "og:description",
        content: "Bracket, scorers, points, and golden boot progression for FIFA World Cup 2026.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: DashboardPage,
});

function ThemeToggle() {
  const [theme, setTheme] = useState("light");

  useEffect(() => {
    const saved = window.localStorage.getItem("theme");
    const initialTheme =
      saved ?? (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");

    setTheme(initialTheme);
    document.documentElement.classList.toggle("dark", initialTheme === "dark");
  }, []);

  const handleToggle = () => {
    const nextTheme = theme === "dark" ? "light" : "dark";
    setTheme(nextTheme);
    document.documentElement.classList.toggle("dark", nextTheme === "dark");
    window.localStorage.setItem("theme", nextTheme);
  };

  return (
    <button
      type="button"
      onClick={handleToggle}
      aria-label="Toggle dark mode"
      className="inline-flex items-center gap-2 rounded-full border border-border bg-card px-3 py-2 text-sm font-medium text-primary transition hover:border-primary/80 hover:bg-primary/10"
    >
      {theme === "dark" ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
      <span>{theme === "dark" ? "Light" : "Dark"}</span>
    </button>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="space-y-3 rounded-3xl border border-border bg-card p-4 shadow-sm">
      <h2 className="text-lg font-semibold tracking-tight">{title}</h2>
      {children}
    </section>
  );
}

const NAV_ITEMS = [
  { id: "summary", label: "Summary" },
  { id: "live", label: "Live & Upcoming" },
  { id: "bracket", label: "Bracket" },
  { id: "scorers", label: "Top Scorers" },
  { id: "golden-boot", label: "Golden Boot" },
  { id: "points", label: "Points Table" },
  { id: "finished", label: "Finished Matches" },
];

function SectionNav() {
  return (
    <nav className="sticky top-0 z-40 border-b bg-background/85 backdrop-blur">
      <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
        <ul className="flex gap-1 overflow-x-auto py-2 pl-2 sm:pl-6 lg:pl-10 [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
          {NAV_ITEMS.map((item) => (
            <li key={item.id} className="shrink-0">
              <a
                href={`#${item.id}`}
                className="inline-block whitespace-nowrap rounded-full border border-transparent px-3 py-1.5 text-xs font-medium text-muted-foreground transition hover:border-primary/40 hover:bg-primary/10 hover:text-primary sm:text-sm"
              >
                {item.label}
              </a>
            </li>
          ))}
        </ul>
      </div>
    </nav>
  );
}

function DashboardPage() {
  return (
    <main className="min-h-screen bg-background text-foreground [scroll-behavior:smooth]">
      <header className="border-b bg-card">
        <div className="mx-auto flex max-w-7xl flex-col gap-3 px-4 py-3 sm:flex-row sm:items-center sm:justify-between sm:px-6">
          <div className="flex items-center gap-2">
            <div className="flex-shrink-0">
              <img
                src="/FIFA-2026-World-Cup-White-Logo.png"
                alt="FIFA logo (white)"
                className="hidden dark:block h-16 w-16"
              />
              <img
                src="/FIFA-2026-World-dark-Cup-Logo.png"
                alt="FIFA logo (dark)"
                className="block dark:hidden h-16 w-16"
              />
            </div>
            <div>
              <h1 className="text-2xl font-bold sm:text-3xl">FIFA World Cup 2026 Dashboard</h1>
              <p className="mt-1 max-w-2xl text-sm text-muted-foreground sm:text-base">
                Real-time bracket, standings, and player analytics.
              </p>
            </div>
          </div>
          <div className="flex items-center justify-start sm:justify-end">
            <ThemeToggle />
          </div>
        </div>
      </header>
      <SectionNav />
      <div className="mx-auto max-w-7xl space-y-8 px-4 py-6 sm:px-6 lg:px-8 scroll-mt-16">
        <section id="summary" className="scroll-mt-20">
          <TournamentSummary />
        </section>
        <section id="live" className="scroll-mt-20">
          <LiveOrResults />
        </section>
        <section id="bracket" className="scroll-mt-20">
          <Section title="Tournament Bracket">
            <TournamentBracket />
          </Section>
        </section>
        <section id="scorers" className="scroll-mt-20">
          <Section title="Top Scorers">
            <TopScorers />
          </Section>
        </section>
        <section id="golden-boot" className="scroll-mt-20">
          <Section title="Golden Boot Race">
            <GoldenBootProgression />
          </Section>
        </section>
        <section id="points" className="scroll-mt-20">
          <Section title="Points Table">
            <PointsTable />
          </Section>
        </section>
        <section id="finished" className="scroll-mt-20">
          <Section title="Finished Matches Table">
            <FinishedMatchesTable />
          </Section>
        </section>
      </div>

      <footer className="border-t py-6 text-center text-xs text-muted-foreground">
        <div className="flex flex-col items-center gap-2">
          <p>
            Created &amp; designed by <span className="font-medium text-foreground">Abhishek Singhal</span>
          </p>
          <div className="flex flex-wrap items-center justify-center gap-4">
            <a
              href="https://github.com/Singhal861"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1.5 hover:text-foreground"
            >
              <Github className="h-3.5 w-3.5" />
              github.com/Singhal861
            </a>
            <a
              href="mailto:abhisheksinghal861@gmail.com"
              className="flex items-center gap-1.5 hover:text-foreground"
            >
              <Mail className="h-3.5 w-3.5" />
              abhisheksinghal861@gmail.com
            </a>
            <a href="tel:+918171576670" className="flex items-center gap-1.5 hover:text-foreground">
              <Phone className="h-3.5 w-3.5" />
              +91 81715 76670
            </a>
          </div>
        </div>
      </footer>
    </main>
  );
}