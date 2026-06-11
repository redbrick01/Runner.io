import React, { useEffect, useState } from "react";
import { motion } from "framer-motion";
import {
  Activity,
  ArrowDown,
  AudioLines,
  Award,
  BarChart3,
  BadgeCheck,
  BellRing,
  Bot,
  BrainCircuit,
  CalendarDays,
  ChartColumnIncreasing,
  ChartNoAxesColumnIncreasing,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  CircleDot,
  CircleX,
  Cloud,
  Code2,
  ClipboardCheck,
  ClipboardList,
  Database,
  DatabaseZap,
  FileCheck2,
  FileText,
  Flag,
  FlagTriangleRight,
  Flame,
  Footprints,
  Gauge,
  Gift,
  GitBranch,
  Globe2,
  History,
  KeyRound,
  Landmark,
  Layers3,
  LineChart,
  Lock,
  LockKeyhole,
  LogOut,
  Mail,
  Map,
  MapPinned,
  MapPin,
  Medal,
  Mountain,
  Navigation,
  Navigation2,
  Network,
  NotebookTabs,
  Play,
  Pause,
  Radio,
  Route,
  RotateCw,
  ServerCog,
  ShieldCheck,
  Smartphone,
  Sparkles,
  Square,
  Star,
  Target,
  TestTube2,
  Timer,
  Trophy,
  UserCog,
  UserRound,
  UsersRound,
  WandSparkles,
  Zap,
} from "lucide-react";

const fadeUp = {
  hidden: { opacity: 0, y: 28 },
  visible: { opacity: 1, y: 0 },
};

const stagger = {
  hidden: {},
  visible: { transition: { staggerChildren: 0.07 } },
};

const appScreenCaptures = {
  auth: "./img/IMG_6088.PNG",
  map: "./img/IMG_6089.PNG",
  run: "./img/IMG_6090.PNG",
  result: "./img/IMG_6091.PNG",
  ai: "./img/IMG_6092.PNG",
  stats: "./img/IMG_6094.PNG",
  history: "./img/IMG_6093.PNG",
  points: "./img/IMG_6095.PNG",
  ranking: "./img/IMG_6096.PNG",
  territory: "./img/IMG_6097.PNG",
  profile: "./img/IMG_6098.PNG",
};

function Section({ id, eyebrow, title, description, children, className = "" }) {
  return (
    <section id={id} className={`relative px-5 py-24 sm:px-8 lg:px-12 ${className}`}>
      <div className="mx-auto max-w-7xl">
        <motion.div
          variants={fadeUp}
          initial="hidden"
          whileInView="visible"
          viewport={{ once: true, margin: "-120px" }}
          transition={{ duration: 0.65, ease: "easeOut" }}
          className="mb-12 max-w-4xl"
        >
          <p className="mb-4 text-sm font-semibold uppercase tracking-[0.28em] text-emerald-300">
            {eyebrow}
          </p>
          <h2 className="text-3xl font-semibold tracking-tight text-white sm:text-5xl">
            {title}
          </h2>
          {description && (
            <p className="mt-5 text-base leading-8 text-slate-300 min-[900px]:whitespace-nowrap sm:text-lg">
              {description}
            </p>
          )}
        </motion.div>
        {children}
      </div>
    </section>
  );
}

function GlassCard({ children, className = "" }) {
  return (
    <motion.div
      variants={fadeUp}
      className={`app-surface rounded-lg border border-white/10 bg-white/[0.055] p-6 shadow-2xl shadow-cyan-950/20 backdrop-blur-xl ${className}`}
    >
      {children}
    </motion.div>
  );
}

function Pill({ children, tone = "emerald" }) {
  const styles = {
    emerald: "border-emerald-300/30 bg-emerald-300/10 text-emerald-100",
    cyan: "border-cyan-300/30 bg-cyan-300/10 text-cyan-100",
    blue: "border-blue-300/30 bg-blue-300/10 text-blue-100",
  }[tone];

  return (
    <span className={`rounded-full border px-4 py-2 text-sm font-medium ${styles}`}>
      {children}
    </span>
  );
}

function IconBadge({ icon: Icon, tone = "cyan" }) {
  const styles = {
    emerald: "bg-emerald-400/10 text-emerald-300 ring-emerald-300/30",
    cyan: "bg-cyan-400/10 text-cyan-300 ring-cyan-300/30",
    blue: "bg-blue-400/10 text-blue-300 ring-blue-300/30",
  }[tone];

  return (
    <div className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-lg ring-1 ${styles}`}>
      <Icon size={22} />
    </div>
  );
}

const brandIconPaths = {
  android:
    "M17.523 15.3414c-.5511 0-.9993-.4486-.9993-.9997s.4483-.9993.9993-.9993c.5511 0 .9993.4483.9993.9993.0001.5511-.4482.9997-.9993.9997m-11.046 0c-.5511 0-.9993-.4486-.9993-.9997s.4482-.9993.9993-.9993c.5511 0 .9993.4483.9993.9993 0 .5511-.4483.9997-.9993.9997m11.4045-6.02l1.9973-3.4592a.416.416 0 00-.1521-.5676.416.416 0 00-.5676.1521l-2.0223 3.503C15.5902 8.2439 13.8533 7.8508 12 7.8508s-3.5902.3931-5.1367 1.0989L4.841 5.4467a.4161.4161 0 00-.5677-.1521.4157.4157 0 00-.1521.5676l1.9973 3.4592C2.6889 11.1867.3432 14.6589 0 18.761h24c-.3435-4.1021-2.6892-7.5743-6.1185-9.4396",
  apple:
    "M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701",
};

function BrandIcon({ path, title, size = 22, className = "" }) {
  return (
    <svg
      className={className}
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-label={`${title} icon`}
      role="img"
    >
      <title>{title}</title>
      <path d={path} />
    </svg>
  );
}

function AndroidIcon(props) {
  return <BrandIcon {...props} title="Android" path={brandIconPaths.android} />;
}

function AppleIcon(props) {
  return <BrandIcon {...props} title="Apple" path={brandIconPaths.apple} />;
}

function BrandMark({ brand, className = "" }) {
  const common = `h-7 w-7 ${className}`;

  if (brand === "flutter") {
    return (
      <svg className={common} viewBox="0 0 64 64" aria-label="Flutter logo" role="img">
        <path fill="#54C5F8" d="M34.8 4 6 32.8l8.9 8.9L52.6 4H34.8Z" />
        <path fill="#29B6F6" d="M35.1 31.1 20 46.2l8.9 8.9 15.1-15.1-8.9-8.9Z" />
        <path fill="#01579B" d="m28.9 55.1 6.3 6.3H53L37.8 46.2l-8.9 8.9Z" />
        <path fill="#0288D1" d="m20 46.2 8.9-8.9 8.9 8.9-8.9 8.9-8.9-8.9Z" />
      </svg>
    );
  }

  if (brand === "dart") {
    return (
      <svg className={common} viewBox="0 0 64 64" aria-label="Dart logo" role="img">
        <path fill="#00B4AB" d="M12 16 4 28v24h24L12 16Z" />
        <path fill="#22D3EE" d="M12 16h24l24 24v8H28L12 16Z" />
        <path fill="#0075C9" d="M36 16 60 40V16H36Z" />
        <path fill="#00599C" d="M28 52h32V40H16l12 12Z" />
      </svg>
    );
  }

  if (brand === "supabase") {
    return (
      <svg className={common} viewBox="0 0 64 64" aria-label="Supabase logo" role="img">
        <path fill="#3ECF8E" d="M37.6 4.8 12.8 35.2c-1.5 1.9-.2 4.8 2.3 4.8h17.2l-5.9 19.2c-.8 2.7 2.7 4.5 4.5 2.3l24.8-30.4c1.5-1.9.2-4.8-2.3-4.8H36.2l5.9-19.2c.8-2.7-2.7-4.5-4.5-2.3Z" />
        <path fill="#1EA672" d="M36.2 26.3h17.2c2.5 0 3.8 2.9 2.3 4.8L30.9 61.5c-1.8 2.2-5.3.4-4.5-2.3L36.2 26.3Z" opacity=".9" />
      </svg>
    );
  }

  if (brand === "google-maps") {
    return (
      <svg className={common} viewBox="0 0 64 64" aria-label="Google Maps logo" role="img">
        <path fill="#34A853" d="M32 4C20.4 4 11 13.4 11 25c0 15.7 21 35 21 35s21-19.3 21-35C53 13.4 43.6 4 32 4Z" />
        <path fill="#4285F4" d="M14.4 36.6C19.8 47.9 32 60 32 60V34.8L14.4 36.6Z" />
        <path fill="#FBBC04" d="M32 4v21l18.4-6.1C47.8 10.3 40.5 4 32 4Z" />
        <path fill="#EA4335" d="M11 25c0 4.1 1.4 8.1 3.4 11.6L32 25V4C20.4 4 11 13.4 11 25Z" />
        <circle cx="32" cy="25" r="7.5" fill="#fff" />
      </svg>
    );
  }

  if (brand === "postgresql") {
    return (
      <svg className={common} viewBox="0 0 64 64" aria-label="PostgreSQL logo" role="img">
        <path fill="#336791" d="M32 5c15 0 25 9.8 25 24.1 0 16.8-13.2 26.2-28.7 25.6C14.2 54.1 7 45.6 7 31.3 7 15.7 17.1 5 32 5Z" />
        <path fill="#fff" d="M21.8 23.4c0-5.6 4.1-9.5 10.1-9.5 6.4 0 10.6 4.3 10.6 10.9 0 5.8-3.2 9.7-8 10.8l.8 8.9h-5.6l.7-8.7c-5.2-.8-8.6-5.4-8.6-12.4Zm10.3 7.1c2.6 0 4.6-2.2 4.6-5.4 0-3.4-1.9-5.8-4.7-5.8-2.7 0-4.6 2.3-4.6 5.7 0 3.2 1.9 5.5 4.7 5.5Z" />
      </svg>
    );
  }

  if (brand === "postgis") {
    return (
      <svg className={common} viewBox="0 0 64 64" aria-label="PostGIS logo" role="img">
        <circle cx="31" cy="31" r="24" fill="#336791" />
        <path fill="#fff" d="M21.5 23.5c0-5.1 3.8-8.7 9.4-8.7 5.8 0 9.8 3.9 9.8 9.9 0 5.1-2.8 8.5-7.2 9.7l.7 7.1h-5.1l.6-7.1c-4.9-.8-8.2-4.8-8.2-10.9Zm9.6 6.2c2.4 0 4.2-1.9 4.2-4.8 0-3-1.7-5.1-4.3-5.1-2.5 0-4.2 2-4.2 5 0 2.9 1.8 4.9 4.3 4.9Z" />
        <rect x="33" y="39" width="25" height="14" rx="7" fill="#3ECF8E" />
        <text x="45.5" y="49" textAnchor="middle" fill="#083421" fontSize="8" fontWeight="900">GIS</text>
      </svg>
    );
  }

  return null;
}

function BrandBadge({ brand }) {
  return (
    <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg bg-white ring-1 ring-blue-300/30">
      <BrandMark brand={brand} />
    </div>
  );
}

function FeatureCard({ icon: Icon, brand, title, text, tone = "cyan" }) {
  return (
    <GlassCard>
      {brand ? <BrandBadge brand={brand} /> : <IconBadge icon={Icon} tone={tone} />}
      <h3 className="mt-5 text-xl font-semibold text-white">{title}</h3>
      <p className="mt-3 leading-7 text-slate-300">{text}</p>
    </GlassCard>
  );
}

function CompactCard({ title, text, icon: Icon, brand }) {
  return (
    <div className="rounded-lg border border-white/10 bg-slate-950/55 p-5">
      {brand ? <BrandMark brand={brand} className="mb-4" /> : <Icon className="mb-4 text-emerald-300" size={23} />}
      <h3 className="font-semibold text-white">{title}</h3>
      <p className="mt-2 text-sm leading-6 text-slate-300">{text}</p>
    </div>
  );
}

function Metric({ value, label }) {
  return (
    <div className="rounded-lg border border-white/10 bg-slate-950/60 p-5 text-center">
      <p className="text-3xl font-black text-white">{value}</p>
      <p className="mt-2 text-sm text-slate-400">{label}</p>
    </div>
  );
}

function FlowStep({ index, title, detail, icon: Icon }) {
  return (
    <motion.div variants={fadeUp} className="relative rounded-lg border border-white/10 bg-slate-950/60 p-5">
      <div className="mb-5 flex items-center justify-between gap-4">
        <IconBadge icon={Icon} tone={index % 2 === 0 ? "cyan" : "emerald"} />
        <span className="font-mono text-sm font-semibold text-cyan-300">0{index}</span>
      </div>
      <h3 className="text-lg font-semibold text-white">{title}</h3>
      <p className="mt-2 text-sm leading-6 text-slate-300">{detail}</p>
    </motion.div>
  );
}

function GuideCard({ icon: Icon, title, purpose, actions, result, tone = "blue" }) {
  return (
    <GlassCard className="h-full">
      <div className="flex items-start gap-4">
        <IconBadge icon={Icon} tone={tone} />
        <div>
          <h3 className="text-xl font-semibold text-white">{title}</h3>
          <p className="mt-2 text-sm leading-6 text-slate-300">{purpose}</p>
        </div>
      </div>
      <div className="mt-5 rounded-lg border border-white/10 bg-slate-950/60 p-4">
        <p className="mb-3 text-xs font-semibold uppercase tracking-[0.18em] text-emerald-300">사용자 조작</p>
        <ul className="space-y-2 text-sm leading-6 text-slate-300">
          {actions.map((action) => (
            <li key={action} className="flex gap-2">
              <CheckCircle2 className="mt-1 shrink-0 text-emerald-300" size={16} />
              <span>{action}</span>
            </li>
          ))}
        </ul>
      </div>
      <div className="mt-4 rounded-lg border border-cyan-300/20 bg-cyan-300/10 p-4">
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-cyan-300">Output</p>
        <p className="mt-2 text-sm leading-6 text-slate-300">{result}</p>
      </div>
    </GlassCard>
  );
}

function PhoneScreenMock({ type }) {
  if (type === "auth") {
    return (
      <div className="flex h-full flex-col justify-between bg-[#F2F2F7] p-5">
        <div className="pt-8 text-center">
          <div className="mx-auto mb-6 flex h-[84px] w-[84px] items-center justify-center rounded-full bg-[#EAF2FF] text-[#007AFF]">
            <Footprints size={48} />
          </div>
          <p className="text-4xl font-black tracking-[-0.05em] text-[#1C1C1E]">
            RUNNER<span className="text-[#007AFF]">.IO</span>
          </p>
          <p className="mt-2 text-sm font-medium text-[#8E8E93]">GPS Running Territory App</p>
        </div>
        <div className="space-y-4 pb-7">
          <div className="rounded-2xl border border-[#3C3C4320] bg-white p-4 text-sm text-[#8E8E93]">Email address</div>
          <div className="rounded-2xl border border-[#3C3C4320] bg-white p-4 text-sm text-[#8E8E93]">Password</div>
          <div className="rounded-2xl bg-[#007AFF] p-4 text-center text-lg font-bold text-white">Get Started</div>
          <p className="text-center text-sm text-[#8E8E93]">
            Don't have an account? <span className="font-bold text-[#007AFF]">Sign Up</span>
          </p>
        </div>
      </div>
    );
  }

  if (type === "map") {
    return (
      <div className="relative h-full overflow-hidden bg-[#F7FBFF]">
        <div className="absolute inset-0 opacity-60 [background-image:linear-gradient(rgba(0,122,255,.16)_1px,transparent_1px),linear-gradient(90deg,rgba(0,122,255,.16)_1px,transparent_1px)] [background-size:32px_32px]" />
        <svg viewBox="0 0 320 560" className="absolute inset-0 h-full w-full">
          <path d="M58 390 L116 330 L164 344 L213 254 L268 230 L288 302 L225 390 L135 424 Z" fill="rgba(0,122,255,.1)" stroke="rgba(0,122,255,.32)" strokeWidth="2" />
          <path d="M62 420 C115 390 105 318 162 306 C231 292 202 202 270 166" fill="none" stroke="#007AFF" strokeWidth="8" strokeLinecap="round" />
        </svg>
        <div className="absolute left-4 right-4 top-4 rounded-2xl bg-white/90 p-4 shadow-lg">
          <div className="grid grid-cols-3 gap-2 text-center">
            {[
              ["점령 면적", "2.40 km²"],
              ["랭킹", "12위"],
              ["포인트", "1280 P"],
            ].map(([label, value]) => (
              <div key={label}>
                <p className="text-[10px] font-bold text-[#8E8E93]">{label}</p>
                <p className="mt-1 text-sm font-black text-[#1C1C1E]">{value}</p>
              </div>
            ))}
          </div>
        </div>
        <div className="absolute left-[44%] top-[47%] flex h-12 w-12 items-center justify-center rounded-full bg-[#34C759] text-white shadow-xl">
          <MapPin fill="currentColor" size={22} />
        </div>
        <div className="absolute bottom-5 left-4 right-4">
          <div className="mx-auto mb-4 flex h-20 w-20 items-center justify-center rounded-full bg-[#007AFF] text-white shadow-xl">
            <Footprints size={34} />
          </div>
          <div className="rounded-full bg-white/95 px-4 py-3 shadow-xl">
            <div className="grid grid-cols-5 items-center text-center">
              {[
                ["분석", ChartNoAxesColumnIncreasing],
                ["통계", ChartColumnIncreasing],
                ["", null],
                ["소셜", UsersRound],
                ["마이", UserCog],
              ].map(([label, Icon]) => (
                <div key={label || "run"} className="text-[#8E8E93]">
                  {Icon && <Icon className="mx-auto mb-1" size={19} />}
                  <p className="text-[10px]">{label}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (type === "run") {
    return (
      <div className="relative h-full overflow-hidden bg-[#F7FBFF]">
        <div className="absolute inset-0 opacity-50 [background-image:linear-gradient(rgba(0,122,255,.16)_1px,transparent_1px),linear-gradient(90deg,rgba(0,122,255,.16)_1px,transparent_1px)] [background-size:32px_32px]" />
        <svg viewBox="0 0 320 560" className="absolute inset-0 h-full w-full">
          <path d="M58 420 C108 386 104 320 164 304 C224 287 204 214 270 166" fill="none" stroke="#007AFF" strokeWidth="8" strokeLinecap="round" />
        </svg>
        <div className="absolute bottom-5 left-4 right-4 rounded-[30px] bg-white/95 p-5 shadow-xl">
          <p className="text-center text-5xl font-black text-[#1C1C1E]">00:28:14</p>
          <div className="mt-5 grid grid-cols-3 text-center">
            {[
              ["거리", "4.82 km", "#007AFF"],
              ["페이스", "5'51\"", "#34C759"],
              ["속도", "10.2 km/h", "#FF9500"],
            ].map(([label, value, color]) => (
              <div key={label}>
                <p className="text-xs font-bold text-[#8E8E93]">{label}</p>
                <p className="mt-1 text-sm font-black" style={{ color }}>{value}</p>
              </div>
            ))}
          </div>
          <div className="mt-6 flex justify-center gap-4">
            {[
              ["×", "#8E8E93"],
              ["Ⅱ", "#FF9500"],
              ["■", "#FF3B30"],
            ].map(([icon, color]) => (
              <div key={icon} className="flex h-14 w-14 items-center justify-center rounded-full text-2xl font-black text-white" style={{ backgroundColor: color }}>
                {icon}
              </div>
            ))}
          </div>
        </div>
      </div>
    );
  }

  if (type === "result") {
    return (
      <div className="h-full overflow-hidden bg-[#F2F2F7]">
        <div className="relative h-[190px] bg-[#F7FBFF]">
          <div className="absolute inset-0 opacity-50 [background-image:linear-gradient(rgba(0,122,255,.16)_1px,transparent_1px),linear-gradient(90deg,rgba(0,122,255,.16)_1px,transparent_1px)] [background-size:30px_30px]" />
          <svg viewBox="0 0 320 190" className="absolute inset-0 h-full w-full">
            <path d="M45 144 C96 120 108 88 162 90 C210 94 224 54 285 36" fill="none" stroke="#007AFF" strokeWidth="7" strokeLinecap="round" />
            <path d="M82 134 L142 92 L212 98 L266 54 L290 120 L210 160 Z" fill="rgba(0,122,255,.1)" stroke="rgba(0,122,255,.36)" />
          </svg>
        </div>
        <div className="p-5">
          <div className="rounded-[28px] bg-[#EAF2FF] p-5">
            <p className="text-sm font-bold text-[#007AFF]">러닝 리포트</p>
            <p className="mt-2 text-4xl font-black">142 P</p>
            <p className="mt-1 text-xs text-[#8E8E93]">2026.05.24 07:20</p>
          </div>
          <p className="mb-3 mt-5 font-black">주요 기록</p>
          <div className="grid grid-cols-2 gap-3">
            {[
              ["거리", "5.01 km"],
              ["시간", "28:34"],
              ["평균 페이스", "5'42\""],
              ["칼로리", "318 kcal"],
            ].map(([label, value]) => (
              <div key={label} className="rounded-2xl bg-white p-4">
                <p className="text-xs text-[#8E8E93]">{label}</p>
                <p className="mt-1 text-lg font-black">{value}</p>
              </div>
            ))}
          </div>
          <div className="mt-3 rounded-2xl bg-white p-4">
            <div className="flex justify-between"><span className="text-[#8E8E93]">점령 면적</span><b>1.80 km²</b></div>
          </div>
        </div>
      </div>
    );
  }

  if (type === "ai") {
    return (
      <div className="h-full bg-[#F2F2F7] p-5">
        <div className="rounded-3xl bg-[#EAF2FF] p-5">
          <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-2xl bg-white text-[#007AFF]">
            <WandSparkles size={25} />
          </div>
          <p className="text-2xl font-black">AI 분석 리포트</p>
          <p className="mt-3 text-sm font-bold leading-6 text-[#1C1C1E]">비슷한 과거 러닝을 찾고 코칭 문구를 만드는 중이에요.</p>
        </div>
        <div className="mt-4 space-y-3">
          {[
            ["AI 요약", "후반 페이스 유지가 이전 기록보다 안정적"],
            ["개선점", "초반 1km 페이스를 10초 낮춰보세요."],
            ["다음 목표", "5km 28분대 안정 진입"],
            ["코칭 문구", "오늘은 리듬 유지가 좋은 러닝"],
          ].map(([label, text]) => (
            <div key={label} className="rounded-2xl bg-white p-4">
              <p className="text-xs font-bold text-[#007AFF]">{label}</p>
              <p className="mt-1 text-sm leading-6">{text}</p>
            </div>
          ))}
        </div>
      </div>
    );
  }

  if (type === "stats") {
    return (
      <div className="h-full bg-[#F2F2F7] p-5">
        <p className="text-2xl font-black">분석</p>
        <div className="mt-4 grid grid-cols-3 rounded-2xl bg-white p-1 text-center text-xs font-bold">
          {["주간", "월간", "전체"].map((item, index) => (
            <div key={item} className={`rounded-xl py-3 ${index === 0 ? "bg-[#007AFF] text-white" : "text-[#8E8E93]"}`}>{item}</div>
          ))}
        </div>
        <div className="mt-4 rounded-2xl bg-[#EAF2FF] p-4">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-white text-[#007AFF]">
              <ChartNoAxesColumnIncreasing size={20} />
            </div>
            <p className="text-sm font-black leading-5">이번 주 지난 기간보다 18% 더 달렸어요.</p>
          </div>
        </div>
        <div className="mt-4 grid grid-cols-2 gap-3">
          {[
            ["총 거리", "42.1 km"],
            ["러닝 시간", "4h 12m"],
            ["러닝 횟수", "12회"],
            ["평균 페이스", "5'48\""],
          ].map(([label, value]) => (
            <div key={label} className="rounded-2xl bg-white p-4">
              <p className="text-xs text-[#8E8E93]">{label}</p>
              <p className="mt-1 text-xl font-black">{value}</p>
            </div>
          ))}
        </div>
        <div className="mt-3 rounded-2xl bg-[#EAF2FF] p-4">
          <div className="flex items-center justify-between">
            <p className="font-black">최근 AI 분석</p>
            <p className="text-xs font-bold text-[#8E8E93]">유사 4개</p>
          </div>
          <p className="mt-2 text-xs font-semibold leading-5 text-[#1C1C1E]">후반 페이스 유지 개선, 다음 목표는 5km 28분대</p>
        </div>
        <div className="mt-4 rounded-3xl bg-white p-4">
          <p className="mb-4 font-bold">최근 7일 거리</p>
          <div className="flex h-28 items-end gap-2">
            {[28, 54, 38, 76, 44, 92, 63].map((h, i) => (
              <div key={i} className="flex-1 rounded-t-lg bg-[#007AFF]" style={{ height: `${h}%` }} />
            ))}
          </div>
        </div>
      </div>
    );
  }

  if (type === "history") {
    return (
      <div className="h-full bg-[#F2F2F7] p-5">
        <p className="text-2xl font-black">러닝 통계</p>
        <div className="mt-4 grid grid-cols-5 rounded-2xl bg-white p-1 text-center text-[10px] font-bold">
          {["일", "주", "월", "년", "전체"].map((item, index) => (
            <div key={item} className={`rounded-xl py-3 ${index === 1 ? "bg-[#007AFF] text-white" : "text-[#8E8E93]"}`}>{item}</div>
          ))}
        </div>
        <div className="mt-4 grid grid-cols-2 gap-3">
          {[
            ["총 러닝", "18회"],
            ["총 거리", "82.4 km"],
            ["총 획득 포인트", "2,840 P"],
            ["총 점령 넓이", "3.28 km²"],
          ].map(([label, value]) => (
            <div key={label} className="rounded-2xl bg-white p-4">
              <p className="text-[11px] text-[#8E8E93]">{label}</p>
              <p className="mt-1 text-lg font-black">{value}</p>
            </div>
          ))}
        </div>
        <div className="mt-4 space-y-3">
          {[
            ["5.01 km", "28:34", "142 P"],
            ["3.20 km", "18:12", "84 P"],
            ["7.42 km", "44:05", "210 P"],
          ].map(([distance, time, point]) => (
            <div key={distance} className="rounded-2xl bg-white p-4">
              <div className="flex items-center justify-between">
                <p className="font-black">{distance}</p>
                <p className="font-bold text-[#007AFF]">{point}</p>
              </div>
              <p className="mt-1 text-xs text-[#8E8E93]">{time}  |  평균 페이스 5'42"</p>
            </div>
          ))}
        </div>
      </div>
    );
  }

  if (type === "points") {
    return (
      <div className="h-full bg-[#F2F2F7] p-5">
        <p className="text-2xl font-black">포인트 내역</p>
        <div className="mt-4 rounded-3xl bg-[#EAF2FF] p-5">
          <p className="text-sm font-bold text-[#007AFF]">누적 포인트</p>
          <p className="mt-2 text-4xl font-black">8,420 P</p>
          <p className="mt-1 text-xs font-semibold text-[#8E8E93]">러닝 완료와 영토 점령 이벤트 반영</p>
        </div>
        <div className="mt-4 space-y-3">
          {[
            ["러닝 완료", "+142 P", "5.01 km 러닝 결과"],
            ["영토 점령", "+58 P", "신규 영역 0.18 km²"],
            ["러닝 완료", "+84 P", "3.20 km 러닝 결과"],
            ["영토 유지", "+24 P", "최근 7일 유지 이벤트"],
          ].map(([title, point, desc]) => (
            <div key={`${title}-${point}`} className="flex items-center gap-3 rounded-2xl bg-white p-4">
              <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-[#EAF2FF] text-[#007AFF]">
                <Star size={18} />
              </div>
              <div className="min-w-0 flex-1">
                <p className="font-black">{title}</p>
                <p className="truncate text-xs text-[#8E8E93]">{desc}</p>
              </div>
              <p className="font-black text-[#34C759]">{point}</p>
            </div>
          ))}
        </div>
      </div>
    );
  }

  if (type === "ranking") {
    return (
      <div className="h-full bg-[#F2F2F7] p-5">
        <p className="text-2xl font-black">랭킹</p>
        <div className="mt-4 grid grid-cols-5 rounded-2xl bg-white p-1 text-center text-[10px] font-bold">
          {["일", "주", "월", "년", "전체"].map((item, index) => (
            <div key={item} className={`rounded-xl py-3 ${index === 1 ? "bg-[#007AFF] text-white" : "text-[#8E8E93]"}`}>{item}</div>
          ))}
        </div>
        <div className="mt-5 rounded-3xl bg-[#007AFF] p-5 text-white">
          <p className="text-sm font-bold text-white/80">내 현재 순위</p>
          <p className="mt-2 text-5xl font-black">12위</p>
          <div className="mt-3 flex items-center justify-between rounded-2xl bg-white/15 px-4 py-3">
            <span className="font-bold">Runner</span>
            <span className="text-sm font-bold">누적 포인트 8,420 P</span>
          </div>
        </div>
        <p className="mb-3 mt-5 font-black">랭킹 리스트</p>
        <div className="mt-4 space-y-3">
          {["Runner A", "나", "Runner B", "Runner C"].map((name, i) => (
            <div key={name} className={`flex items-center justify-between rounded-2xl p-4 ${name === "나" ? "bg-[#EAF2FF]" : "bg-white"}`}>
              <span className="font-bold">#{11 + i} {name} {name === "나" && <span className="rounded-full bg-[#007AFF] px-2 py-1 text-[10px] text-white">나</span>}</span>
              <span className="font-bold text-[#007AFF]">{8420 - i * 42} P</span>
            </div>
          ))}
        </div>
      </div>
    );
  }

  if (type === "profile") {
    return (
      <div className="h-full bg-[#F2F2F7] p-5">
        <p className="text-2xl font-black">마이페이지</p>
        <div className="mt-5 rounded-3xl bg-white p-5">
          <div className="flex items-center gap-3">
            <div className="h-14 w-14 rounded-full border-[3px] border-white bg-[#007AFF] shadow-lg" />
            <div>
              <p className="text-xl font-black">Runner</p>
              <p className="text-sm font-bold text-[#8E8E93]">랭킹 12위</p>
            </div>
          </div>
          <div className="mt-4 grid grid-cols-2 gap-3">
            <div className="rounded-2xl bg-[#F2F2F7] p-4">
              <p className="text-xs text-[#8E8E93]">포인트</p>
              <p className="mt-1 font-black">8,420.0 P</p>
            </div>
            <div className="rounded-2xl bg-[#F2F2F7] p-4">
              <p className="text-xs text-[#8E8E93]">점령 면적</p>
              <p className="mt-1 font-black">2.40 km²</p>
            </div>
          </div>
        </div>
        <div className="mt-4 space-y-3">
          {[
            ["개인정보 수정", "닉네임, 비밀번호, 키/몸무게 수정"],
            ["러닝 통계", "주간/월간 요약과 개인 최고 기록"],
            ["러닝 리포트", "저장된 러닝 기록과 상세 결과 보기"],
            ["점령면적 상세", "면적 변화, 지도, 기여 러닝 보기"],
            ["포인트 내역", "포인트 획득/사용 기록 보기"],
          ].map(([title, desc]) => (
            <div key={title} className="rounded-2xl bg-white p-4">
              <p className="font-black">{title}</p>
              <p className="mt-1 text-xs font-semibold text-[#8E8E93]">{desc}</p>
            </div>
          ))}
        </div>
      </div>
    );
  }

  if (type === "territory") {
    return (
      <div className="h-full overflow-hidden bg-[#F2F2F7] p-5">
        <p className="text-2xl font-black">점령면적 상세</p>
        <div className="mt-4 grid grid-cols-2 gap-3 rounded-3xl bg-white p-4">
          {[
            ["현재 점령 면적", "2.40 km²"],
            ["오늘 증가", "0.18 km²"],
            ["주간 증가", "0.72 km²"],
            ["유지 일수", "9일"],
            ["최근 7일 유지율", "86%"],
            ["마지막 갱신", "05.24"],
          ].map(([label, value]) => (
            <div key={label} className="rounded-2xl bg-[#F2F2F7] p-3">
              <p className="text-[10px] font-bold text-[#8E8E93]">{label}</p>
              <p className="mt-1 text-sm font-black">{value}</p>
            </div>
          ))}
        </div>
        <div className="relative mt-4 h-36 overflow-hidden rounded-3xl bg-[#F7FBFF]">
          <div className="absolute inset-0 opacity-60 [background-image:linear-gradient(rgba(52,199,89,.18)_1px,transparent_1px),linear-gradient(90deg,rgba(52,199,89,.18)_1px,transparent_1px)] [background-size:26px_26px]" />
          <svg viewBox="0 0 320 144" className="absolute inset-0 h-full w-full">
            <path d="M30 110 L82 52 L150 65 L218 34 L292 74 L236 126 L122 132 Z" fill="rgba(52,199,89,.18)" stroke="#34C759" strokeWidth="2" />
            <path d="M38 124 C92 95 112 58 154 66 C198 74 220 45 282 38" fill="none" stroke="#007AFF" strokeWidth="5" strokeLinecap="round" />
          </svg>
        </div>
        <div className="mt-4 rounded-3xl bg-white p-4">
          <p className="font-black">영토 점령 러닝</p>
          <div className="mt-3 space-y-2">
            {["5.01 km  |  05.24", "3.20 km  |  05.21"].map((item, index) => (
              <div key={item} className="flex items-center justify-between rounded-2xl bg-[#F2F2F7] p-3">
                <span className="text-xs font-bold text-[#8E8E93]">{item}</span>
                <span className="font-black">{index === 0 ? "0.18" : "0.11"} km²</span>
              </div>
            ))}
          </div>
        </div>
        <div className="mt-3 rounded-3xl bg-white p-4">
          <p className="font-black">변화 타임라인</p>
          <div className="mt-3 flex items-center justify-between rounded-2xl bg-[#F2F2F7] p-3">
            <span className="text-xs font-bold">러닝 점령</span>
            <span className="font-black text-[#34C759]">+0.18 km²</span>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="relative h-full overflow-hidden bg-[#F7FBFF]">
      <div className="absolute inset-0 opacity-60 [background-image:linear-gradient(rgba(52,199,89,.18)_1px,transparent_1px),linear-gradient(90deg,rgba(52,199,89,.18)_1px,transparent_1px)] [background-size:34px_34px]" />
      <svg viewBox="0 0 320 560" className="absolute inset-0 h-full w-full">
        <path d="M46 388 L102 318 L160 328 L220 250 L284 286 L238 402 L126 450 Z" fill="rgba(52,199,89,.16)" stroke="rgba(52,199,89,.55)" strokeWidth="2" />
      </svg>
      <div className="absolute left-5 right-5 top-5 rounded-3xl bg-white/95 p-5 shadow-lg">
        <p className="text-sm font-bold text-[#34C759]">영토 상세</p>
        <p className="mt-2 text-3xl font-black">2.4㎢</p>
        <p className="mt-1 text-sm text-[#8E8E93]">유지율 86%</p>
      </div>
      <div className="absolute bottom-5 left-5 right-5 rounded-3xl bg-white/95 p-5 shadow-lg">
        <p className="mb-3 font-bold">프로필</p>
        <div className="flex items-center gap-3">
          <div className="h-12 w-12 rounded-full bg-[#007AFF]" />
          <div><p className="font-bold">Runner</p><p className="text-sm text-[#8E8E93]">총 포인트 8,420</p></div>
        </div>
      </div>
    </div>
  );
}

function IPhoneFrame({ guide }) {
  const captureSrc = guide.screenshotSrc ?? appScreenCaptures[guide.screen];

  return (
    <div className="mx-auto flex w-full max-w-[305px] flex-col items-center">
      <div className="iphone-17-shell w-full rounded-[46px] border border-[#3C3C4320] bg-[#FDFDFE] p-[10px] shadow-[0_28px_70px_rgba(28,28,30,0.16)]">
        <div className="iphone-17-screen relative overflow-hidden rounded-[36px] border border-[#3C3C431F] bg-[#F2F2F7]">
          <div className="absolute left-1/2 top-[10px] z-20 h-[18px] w-[78px] -translate-x-1/2 rounded-full bg-[#1C1C1E] shadow-[inset_0_0_0_1px_rgba(255,255,255,0.08)]" />
          {guide.videoSrc ? (
            <video className="absolute inset-0 h-full w-full object-cover" src={guide.videoSrc} autoPlay muted loop playsInline />
          ) : captureSrc ? (
            <img className="absolute inset-0 h-full w-full object-cover" src={captureSrc} alt={`${guide.title} 실제 구현 화면 캡처`} />
          ) : (
            <div className="absolute inset-0">
              <PhoneScreenMock type={guide.screen} />
            </div>
          )}
        </div>
      </div>
      <p className="mt-4 text-center text-xs font-semibold uppercase tracking-[0.18em] text-slate-400">
        iPhone 17 frame
      </p>
    </div>
  );
}

function FeatureGuideSlide({ guide, index }) {
  const Icon = guide.icon;
  const metaBlocks = [
    ["구현 포인트", guide.implementation, CheckCircle2, "emerald"],
    ["연동 데이터/API", guide.dataFlow, DatabaseZap, "cyan"],
    ["검증 기준", guide.validation, ClipboardCheck, "blue"],
  ].filter(([, items]) => items?.length);

  useEffect(() => {
    window.MathJax?.typesetPromise?.();
  }, [guide.result]);

  return (
    <motion.article
      key={guide.title}
      initial={{ opacity: 0, x: 38 }}
      animate={{ opacity: 1, x: 0 }}
      exit={{ opacity: 0, x: -38 }}
      transition={{ duration: 0.42, ease: "easeOut" }}
      variants={fadeUp}
      className="feature-guide-slide app-surface grid min-h-[680px] items-stretch gap-8 rounded-[32px] border border-white/10 bg-white/[0.055] p-5 shadow-2xl shadow-cyan-950/20 backdrop-blur-xl min-[700px]:grid-cols-[minmax(0,1fr)_minmax(270px,0.72fr)] min-[700px]:p-6 lg:grid-cols-[minmax(0,1fr)_minmax(310px,0.72fr)] lg:p-8"
    >
      <div className="flex min-h-full flex-col justify-center">
        <div className="mb-6 flex items-start gap-4">
          <IconBadge icon={Icon} tone={guide.tone} />
          <div className="min-w-0">
            <p className="font-mono text-sm font-semibold text-emerald-300">Feature {String(index + 1).padStart(2, "0")}</p>
            <h3 className="mt-1 whitespace-nowrap text-2xl font-black text-white sm:text-3xl lg:text-4xl">{guide.title}</h3>
          </div>
        </div>
        <p className="max-w-2xl text-base leading-8 text-slate-300 sm:text-lg">{guide.purpose}</p>

        <div className="mt-6 grid gap-3 md:grid-cols-3">
          {metaBlocks.map(([label, items, MetaIcon, tone]) => (
            <div key={label} className="rounded-lg border border-white/10 bg-slate-950/55 p-4">
              <div className="mb-3 flex items-center gap-2">
                <MetaIcon
                  className={
                    tone === "emerald"
                      ? "text-emerald-300"
                      : tone === "cyan"
                        ? "text-cyan-300"
                        : "text-blue-300"
                  }
                  size={16}
                />
                <p className="text-xs font-semibold uppercase tracking-[0.16em] text-slate-400">{label}</p>
              </div>
              <div className="flex flex-wrap gap-2">
                {items.map((item) => (
                  <span
                    key={item}
                    className="rounded-full border border-white/10 bg-white/[0.07] px-3 py-1.5 text-[12px] font-semibold leading-tight text-slate-200"
                  >
                    {item}
                  </span>
                ))}
              </div>
            </div>
          ))}
        </div>

        <div className="mt-4 grid flex-1 gap-4 min-[700px]:grid-cols-2">
          <div className="flex h-full flex-col rounded-lg border border-white/10 bg-slate-950/60 p-5">
            <p className="mb-4 text-xs font-semibold uppercase tracking-[0.18em] text-emerald-300">사용자 조작</p>
            <ul className="space-y-3 text-sm leading-6 text-slate-300">
              {guide.actions.map((action) => (
                <li key={action} className="flex gap-3">
                  <CheckCircle2 className="mt-1 shrink-0 text-emerald-300" size={17} />
                  <span>{action}</span>
                </li>
              ))}
            </ul>
          </div>
          <div className="flex h-full flex-col rounded-lg border border-cyan-300/20 bg-cyan-300/10 p-5">
            <p className="mb-4 text-xs font-semibold uppercase tracking-[0.18em] text-cyan-300">{guide.resultLabel ?? "처리 결과"}</p>
            <p className="text-sm leading-7 text-slate-300">{guide.result}</p>
            <div className="mt-auto space-y-3 pt-5">
              {guide.note && (
                <div className="rounded-lg border border-emerald-300/20 bg-emerald-300/10 p-4">
                  <p className="text-xs font-semibold text-emerald-300">핵심 포인트</p>
                  <p className="mt-2 text-sm leading-6 text-slate-300">{guide.note}</p>
                </div>
              )}
            </div>
          </div>
        </div>
      </div>

      <div className="flex min-h-full items-start justify-center rounded-[28px] border border-white/10 bg-white/45 p-5 pt-6">
        <IPhoneFrame guide={guide} />
      </div>
    </motion.article>
  );
}

function FeatureGuideCarousel({ guides }) {
  const [activeIndex, setActiveIndex] = useState(0);
  const activeGuide = guides[activeIndex];

  const goTo = (nextIndex) => {
    const length = guides.length;
    setActiveIndex((nextIndex + length) % length);
  };

  return (
    <motion.div
      variants={stagger}
      initial="hidden"
      whileInView="visible"
      viewport={{ once: true, margin: "-120px" }}
      className="feature-carousel"
    >
      <div className="relative">
        <div className="overflow-hidden">
          <FeatureGuideSlide guide={activeGuide} index={activeIndex} />
        </div>

        <div className="pointer-events-none absolute inset-y-0 -left-3 -right-3 flex items-center justify-between sm:-left-8 sm:-right-8 lg:-left-16 lg:-right-16 xl:-left-20 xl:-right-20">
          <button
            type="button"
            aria-label="이전 기능"
            onClick={() => goTo(activeIndex - 1)}
            className="pointer-events-auto flex h-12 w-12 items-center justify-center text-[#007AFF] transition hover:-translate-y-0.5 hover:text-[#0056CC] sm:h-14 sm:w-14"
          >
            <ChevronLeft size={34} strokeWidth={2.4} />
          </button>
          <button
            type="button"
            aria-label="다음 기능"
            onClick={() => goTo(activeIndex + 1)}
            className="pointer-events-auto flex h-12 w-12 items-center justify-center text-[#007AFF] transition hover:-translate-y-0.5 hover:text-[#0056CC] sm:h-14 sm:w-14"
          >
            <ChevronRight size={34} strokeWidth={2.4} />
          </button>
        </div>
      </div>

      <div className="mt-5 flex flex-wrap justify-center gap-2">
        {guides.map((guide, index) => (
          <button
            key={guide.title}
            type="button"
            aria-label={`${guide.title} 보기`}
            onClick={() => goTo(index)}
            className={`h-2.5 rounded-full transition-all ${
              index === activeIndex ? "w-10 bg-[#007AFF]" : "w-2.5 bg-[#3C3C4326] hover:bg-[#007AFF66]"
            }`}
          />
        ))}
      </div>
    </motion.div>
  );
}

function DiagramNode({ icon: Icon, brand, title, detail }) {
  return (
    <div className="rounded-lg border border-white/10 bg-slate-950/75 p-5 shadow-blue-glow">
      <div className="flex items-center gap-3">
        {brand ? <BrandMark brand={brand} /> : <Icon className="text-emerald-300" size={22} />}
        <h3 className="font-semibold text-white">{title}</h3>
      </div>
      <p className="mt-3 text-sm leading-6 text-slate-300">{detail}</p>
    </div>
  );
}

function ArrowConnector() {
  return (
    <div className="hidden items-center justify-center text-cyan-300 lg:flex">
      <ChevronRight size={28} />
    </div>
  );
}

function MiniNode({ icon: Icon, brand, title, subtitle, tone = "blue" }) {
  const toneClass = tone === "green" ? "text-emerald-300" : "text-cyan-300";

  return (
    <div className="min-h-[116px] rounded-lg border border-white/10 bg-slate-950/60 p-4">
      {brand ? <BrandMark brand={brand} className="mb-3" /> : <Icon className={`mb-3 ${toneClass}`} size={22} />}
      <p className="font-semibold text-white">{title}</p>
      <p className="mt-1 text-xs leading-5 text-slate-400">{subtitle}</p>
    </div>
  );
}

function ArchitectureMap() {
  return (
    <div className="relative overflow-hidden rounded-lg border border-white/10 bg-slate-950/60 p-5">
      <div className="absolute inset-0 opacity-40 [background-image:linear-gradient(rgba(0,122,255,.16)_1px,transparent_1px),linear-gradient(90deg,rgba(0,122,255,.16)_1px,transparent_1px)] [background-size:34px_34px]" />
      <div className="relative grid gap-4 lg:grid-cols-[1fr_1.2fr_1.2fr_1fr]">
        <div className="space-y-4">
          <MiniNode icon={Footprints} title="Runner" subtitle="러닝 시작, 종료, 결과 확인" tone="green" />
          <MiniNode icon={Navigation2} brand="google-maps" title="GPS / Maps" subtitle="위치 stream, 지도, 경로 표시" />
        </div>

        <div className="rounded-lg border border-cyan-300/20 bg-cyan-300/10 p-4">
          <p className="mb-4 font-mono text-sm font-semibold text-cyan-300">Flutter Client</p>
          <div className="grid gap-3">
            <MiniNode icon={Smartphone} brand="flutter" title="Presentation Layer" subtitle="RunningMap, Result, History, Ranking" />
            <MiniNode icon={Timer} title="RunSessionEngine" subtitle="상태, 거리, pace, split, 고도 계산" tone="green" />
            <MiniNode icon={Route} title="Service Layer" subtitle="Auth, Run, History, AI report API 호출" />
          </div>
        </div>

        <div className="rounded-lg border border-emerald-300/20 bg-emerald-300/10 p-4">
          <p className="mb-4 font-mono text-sm font-semibold text-emerald-300">Supabase Backend</p>
          <div className="grid gap-3">
            <MiniNode icon={LockKeyhole} brand="supabase" title="Auth" subtitle="email/password, session" tone="green" />
            <MiniNode icon={ServerCog} brand="supabase" title="Edge Functions" subtitle="create-run, leaderboard, AI report" />
            <MiniNode icon={DatabaseZap} brand="postgis" title="PostgreSQL / PostGIS" subtitle="runs, points, territories, AI features" tone="green" />
          </div>
        </div>

        <div className="space-y-4">
          <MiniNode icon={Radio} title="Android Native" subtitle="Foreground service, notification actions" />
          <MiniNode icon={BellRing} title="iOS Native" subtitle="Live Activity, Dynamic Island" tone="green" />
        </div>
      </div>
      <div className="relative mt-5 grid gap-3 text-center text-xs font-semibold text-slate-400 md:grid-cols-4">
        <div className="rounded-full bg-white/70 px-4 py-2">GPS samples</div>
        <div className="rounded-full bg-white/70 px-4 py-2">JSON API</div>
        <div className="rounded-full bg-white/70 px-4 py-2">Trigger / RPC</div>
        <div className="rounded-full bg-white/70 px-4 py-2">Native status bridge</div>
      </div>
    </div>
  );
}

function RuntimeFlowDiagram() {
  const steps = [
    ["GPS", "위치 샘플", Navigation2],
    ["Filter", "오차/속도 필터", BadgeCheck],
    ["Engine", "거리/pace/split", Timer],
    ["Save", "create-run", Cloud],
    ["DB", "runs/splits insert", DatabaseZap],
    ["Derive", "포인트/영토/RPC", GitBranch],
    ["Views", "결과/랭킹/분석", ClipboardList],
  ];

  return (
    <GlassCard>
      <div className="grid gap-3 lg:grid-cols-7">
        {steps.map(([title, text, Icon], index) => (
          <div key={title} className="relative rounded-lg border border-white/10 bg-slate-950/60 p-4">
            <div className="mb-5 flex items-center justify-between">
              <Icon className={index % 2 === 0 ? "text-cyan-300" : "text-emerald-300"} size={22} />
              <span className="font-mono text-xs text-slate-400">{index + 1}</span>
            </div>
            <p className="font-semibold text-white">{title}</p>
            <p className="mt-1 text-xs leading-5 text-slate-400">{text}</p>
            {index < steps.length - 1 && (
              <div className="absolute -right-2 top-1/2 z-10 hidden h-4 w-4 -translate-y-1/2 rotate-45 border-r border-t border-cyan-300/40 bg-white lg:block" />
            )}
          </div>
        ))}
      </div>
      <div className="mt-6 rounded-lg border border-emerald-300/20 bg-emerald-300/10 p-5">
        <p className="font-semibold text-emerald-300">핵심 포인트</p>
        <p className="mt-2 leading-7 text-slate-300">
          클라이언트는 실시간 계산과 UX 담당. 저장 이후의 포인트, 영토, 랭킹 파생 처리는 DB trigger/RPC가 일관되게 처리
        </p>
      </div>
    </GlassCard>
  );
}

function RagPipelineDiagram() {
  const rows = [
    ["Source", "runs, run_splits, territories, point_history", DatabaseZap],
    ["Feature", "summary text, numeric features, route centroid/bbox", Layers3],
    ["Retrieval", "embedding + numeric + spatial similarity", Network],
    ["Context", "현재 러닝 + 유사 과거 러닝 3~5개", FileCheck2],
    ["Generation", "summary, improvements, next goal, coaching", WandSparkles],
    ["Report", "run_ai_reports 저장 후 UI 표시", ClipboardList],
  ];

  return (
    <div className="rounded-lg border border-white/10 bg-slate-950/60 p-5">
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
        {rows.map(([title, text, Icon], index) => (
          <div key={title} className="rounded-lg border border-white/10 bg-white/70 p-4">
            <div className="mb-4 flex items-center justify-between">
              <Icon className={index < 3 ? "text-emerald-300" : "text-cyan-300"} size={23} />
              <span className="font-mono text-xs text-slate-400">{String(index + 1).padStart(2, "0")}</span>
            </div>
            <p className="font-semibold text-white">{title}</p>
            <p className="mt-2 text-xs leading-5 text-slate-400">{text}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

function TimelineItem({ phase, title, items }) {
  return (
    <motion.div variants={fadeUp} className="relative grid gap-4 md:grid-cols-[170px_1fr]">
      <div className="flex items-start gap-4">
        <div className="mt-1 flex h-9 w-9 items-center justify-center rounded-full border border-emerald-300/40 bg-slate-950 text-emerald-300">
          <CircleDot size={16} />
        </div>
        <p className="font-mono text-sm font-semibold text-cyan-300">{phase}</p>
      </div>
      <div className="rounded-lg border border-white/10 bg-white/[0.055] p-5 backdrop-blur-xl">
        <h3 className="text-lg font-semibold text-white">{title}</h3>
        <ul className="mt-3 space-y-2 text-sm leading-6 text-slate-300">
          {items.map((item) => (
            <li key={item} className="flex gap-2">
              <span className="mt-2 h-1.5 w-1.5 shrink-0 rounded-full bg-emerald-300" />
              <span>{item}</span>
            </li>
          ))}
        </ul>
      </div>
    </motion.div>
  );
}

function DevelopmentProcess({ timeline }) {
  return (
    <GlassCard className="overflow-hidden p-0">
      <div className="relative p-6 lg:p-8">
        <div className="mb-6 grid grid-cols-8 gap-3 xl:gap-4">
          <div className="col-span-4">
            <div className="flex items-center gap-2 text-[#007AFF]">
              <ChevronRight className="rotate-180" size={15} />
              <div className="h-px flex-1 bg-[#007AFF]" />
              <ChevronRight size={15} />
            </div>
            <p className="mt-2 text-center text-xs font-black text-[#007AFF]">졸업작품 1 · Phase 01-04</p>
          </div>
          <div className="col-start-2 col-span-7">
            <div className="flex items-center gap-2 text-[#34C759]">
              <ChevronRight className="rotate-180" size={15} />
              <div className="h-px flex-1 bg-[#34C759]" />
              <ChevronRight size={15} />
            </div>
            <p className="mt-2 text-center text-xs font-black text-[#34C759]">졸업작품 2 · Phase 02-08</p>
          </div>
        </div>
        <div className="grid grid-cols-8 gap-3 xl:gap-4">
          {timeline.map(([phase, title, items, keywords], index) => (
            <motion.div key={phase} variants={fadeUp} className="relative">
              {index < timeline.length - 1 && (
                <ChevronRight className="absolute -right-4 top-[11px] z-20 hidden text-[#007AFF80] xl:block" size={20} strokeWidth={2.4} />
              )}
              <div className="mb-2 grid min-h-[76px] grid-rows-[36px_40px] justify-items-center text-center">
                <div className="relative z-10 flex h-9 w-9 shrink-0 items-center justify-center rounded-full border border-[#3C3C4320] bg-white text-[11px] font-black text-[#007AFF] shadow-[0_10px_24px_rgba(28,28,30,0.08)]">
                  {String(index + 1).padStart(2, "0")}
                </div>
                <h3 className="max-w-full px-1 text-[13px] font-black leading-5 text-white">{title}</h3>
              </div>
              <div className="min-h-[168px] rounded-[18px] border border-white/10 bg-white/75 p-3 shadow-[0_14px_34px_rgba(28,28,30,0.06)]">
                <div className="flex flex-col gap-2">
                  {(keywords ?? items).map((item) => (
                    <span key={item} className="rounded-full border border-[#007AFF26] bg-[#EAF2FF] px-2 py-1.5 text-center text-[10px] font-bold leading-tight text-[#007AFF] shadow-[0_4px_10px_rgba(0,122,255,0.05)] [overflow-wrap:anywhere]">
                      {item}
                    </span>
                  ))}
                </div>
              </div>
            </motion.div>
          ))}
        </div>
      </div>
      <div className="border-t border-white/10 bg-white/55 px-6 py-4">
        <div className="grid gap-3 text-xs font-semibold text-slate-400 md:grid-cols-4">
          <span>기획/인증</span>
          <span>러닝 기록/백엔드</span>
          <span>분석/네이티브/AI</span>
          <span>테스트/안정화</span>
        </div>
      </div>
    </GlassCard>
  );
}

function HeroVisual() {
  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.96, y: 30 }}
      animate={{ opacity: 1, scale: 1, y: 0 }}
      transition={{ duration: 0.9, ease: "easeOut", delay: 0.15 }}
      className="relative mx-auto aspect-[0.86] w-full max-w-[540px]"
    >
      <div className="absolute -inset-8 rounded-full bg-cyan-300/10 blur-3xl" />
      <div className="absolute inset-0 rounded-[32px] border border-white/10 bg-white/[0.045] p-5 shadow-2xl shadow-cyan-950/50 backdrop-blur-2xl">
        <div className="relative h-full overflow-hidden rounded-[24px] border border-white/10 bg-[#07111f]">
          <div className="absolute inset-0 opacity-25 [background-image:linear-gradient(rgba(34,211,238,.8)_1px,transparent_1px),linear-gradient(90deg,rgba(34,211,238,.8)_1px,transparent_1px)] [background-size:38px_38px]" />
          <svg viewBox="0 0 500 580" className="absolute inset-0 h-full w-full">
            <path
              className="territory-pulse origin-center"
              d="M105 420 L170 365 L245 375 L315 285 L395 255 L430 335 L330 440 L205 480 Z"
              fill="rgba(34,211,238,0.42)"
              stroke="rgba(34,211,238,0.7)"
              strokeWidth="2"
            />
            <path
              d="M80 460 C150 420 130 330 210 320 C310 306 275 190 370 160 C420 145 435 100 450 70"
              fill="none"
              stroke="rgba(52,211,153,0.95)"
              strokeWidth="10"
              strokeLinecap="round"
            />
            <path
              className="route-dash"
              d="M80 460 C150 420 130 330 210 320 C310 306 275 190 370 160 C420 145 435 100 450 70"
              fill="none"
              stroke="rgba(255,255,255,0.65)"
              strokeWidth="2"
              strokeLinecap="round"
            />
          </svg>

          <div className="absolute left-6 right-6 top-6 rounded-lg border border-white/10 bg-slate-950/70 p-4 backdrop-blur">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-xs text-slate-400">FINAL PROJECT</p>
                <p className="text-lg font-bold text-white">Runner.io</p>
              </div>
              <div className="flex h-10 w-10 items-center justify-center rounded-full bg-emerald-300 text-slate-950">
                <Play size={18} fill="currentColor" />
              </div>
            </div>
            <div className="mt-4 grid grid-cols-3 gap-2">
              {["GPS", "PostGIS", "AI"].map((item) => (
                <div key={item} className="rounded-md bg-white/5 px-3 py-2 text-center text-xs font-semibold text-cyan-100">
                  {item}
                </div>
              ))}
            </div>
          </div>

          <div className="absolute bottom-6 left-6 right-6 grid grid-cols-3 gap-3">
            {[
              ["TESTS", "54"],
              ["FLOW", "E2E"],
              ["AREA", "PostGIS"],
            ].map(([label, value]) => (
              <div key={label} className="rounded-lg border border-white/10 bg-slate-950/70 p-4 backdrop-blur">
                <p className="text-[11px] text-slate-400">{label}</p>
                <p className="mt-1 text-base font-bold text-white">{value}</p>
              </div>
            ))}
          </div>

          <div className="float-slow absolute left-[40%] top-[48%] flex h-12 w-12 items-center justify-center rounded-full bg-emerald-300 text-slate-950 shadow-[0_0_34px_rgba(52,211,153,.7)]">
            <MapPin size={22} fill="currentColor" />
          </div>
        </div>
      </div>
    </motion.div>
  );
}

export default function RunningPresentationPage() {
  const finalFeatures = [
    ["인증/프로필", "회원가입, 로그인, 세션 체크, 프로필 수정, 로그아웃", UserCog, "emerald"],
    ["러닝 기록", "시작, 일시정지, 재개, 종료, GPS 필터링, split 계산", Footprints, "cyan"],
    ["지도/영토", "경로 폴리라인, 영토 폴리곤, PostGIS 기반 병합/차감", MapPinned, "blue"],
    ["결과/분석", "결과 리포트, 주간/월간/전체 통계, 최근 7일 그래프", ClipboardList, "emerald"],
    ["게임화", "포인트 이력, 기간별 랭킹, 내 주변 순위, 영토 상세", Star, "cyan"],
    ["네이티브 연동", "Android foreground service, iOS Live Activity, Dynamic Island", Smartphone, "blue"],
    ["AI 분석 + RAG형 검색", "유사 러닝 retrieval, AI 요약, 개선점, 다음 목표, 코칭 문구", WandSparkles, "emerald"],
    ["소셜/경쟁", "기간별 랭킹, 내 주변 순위, 포인트 경쟁, 영토 점령 경쟁", UsersRound, "cyan"],
  ];

  const userGuides = [
    {
      title: "회원가입 / 로그인",
      icon: Mail,
      tone: "emerald",
      screen: "auth",
      purpose: "Supabase Auth의 이메일/비밀번호 인증 사용. 앱 시작 시 세션을 확인해 로그인 화면 또는 메인 지도 화면으로 분기",
      implementation: ["Supabase Auth", "session check", "profile bootstrap"],
      dataFlow: ["auth.users", "profiles", "update-profile"],
      validation: ["잘못된 비밀번호 처리", "재실행 세션 유지", "로그아웃 분기"],
      actions: ["이메일/비밀번호 입력", "회원가입 또는 로그인 실행", "로그아웃 시 로그인 화면으로 복귀"],
      result: "profiles를 기준으로 러닝 기록, 포인트, 랭킹, 영토 데이터가 사용자 단위로 연결",
      note: "인증 성공 이후 모든 러닝/포인트/영토 데이터의 기준이 되는 user id 확정",
    },
    {
      title: "메인 러닝 지도",
      icon: MapPinned,
      tone: "cyan",
      screen: "map",
      purpose: "Google Map 위에 현재 위치, 경로, 영토 폴리곤, 사용자 요약 정보를 표시하는 메인 화면",
      implementation: ["google_maps_flutter", "geolocator", "polygon overlay"],
      dataFlow: ["territory-geojson", "profiles summary", "current position"],
      validation: ["권한 거부 상태", "지도 재진입", "폴리곤 렌더링"],
      actions: ["위치 권한 허용", "지도에서 현재 위치 확인", "주변 영토 폴리곤과 마커 확인", "필요 시 지도 확대/축소 및 이동"],
      result: "러닝 시작 전 지도 상태, 누적 포인트, 랭킹, 점령 면적을 같은 화면에서 확인",
      note: "사용자가 달린 경로가 이후 어떤 공간 데이터로 바뀌는지 보여주는 진입 화면",
    },
    {
      title: "러닝 세션 제어",
      icon: Footprints,
      tone: "blue",
      screen: "run",
      purpose: "러닝 상태를 시작, 일시정지, 재개, 종료, 취소로 관리하고 km당 페이스, AI 실시간 분석을 음성안내 제공",
      implementation: ["RunSessionEngine", "GPS filter", "pause segment"],
      dataFlow: ["location stream", "split buffer", "session metrics"],
      validation: ["GPS 튐 제거", "일시정지 시간 제외", "재개 후 거리 보정"],
      actions: ["러닝 시작 버튼 선택", "러닝 중 거리, 시간, 페이스 확인", "일시정지 후 재개", "종료 시 저장 여부 확인"],
      result: "GPS 샘플 누적 후 거리, 속도, 페이스, 상승고도, split 데이터 실시간 계산",
      note: "실시간 계산값과 저장용 raw 경로 데이터를 동시에 관리하는 핵심 모듈",
    },
    {
      title: "러닝 결과 리포트",
      icon: ClipboardList,
      tone: "emerald",
      screen: "result",
      purpose: "러닝 종료 후 저장된 기록을 지도, 주요 지표, split, 포인트, 점령 면적으로 표시",
      implementation: ["create-run response", "route polyline", "split list"],
      dataFlow: ["runs", "run_splits", "point_history", "territories"],
      validation: ["저장 실패 처리", "포인트 반영", "split 값 일치"],
      actions: ["거리, 시간, 평균 페이스 확인", "포인트, 칼로리, 상승고도, 점령면적 확인", "지도 경로와 split 목록 확인"],
      resultLabel: "결과 포인트 산정",
      result: "$P = d_{km} \\times \\left(1 + 0.3 \\times \\frac{v_{km/h}}{10}\\right) \\times 10$",
      note: "러닝거리와 페이스를 반영하여 폐곡선 형태의 영토를 생성하지 않더라도 충분한 포인트로 다른 유저와의 경쟁이 가능하게 설계",
    },
    {
      title: "AI 러닝 분석",
      icon: WandSparkles,
      tone: "cyan",
      screen: "ai",
      purpose: "현재 러닝과 유사한 과거 기록 검색 후, 검색 결과를 context로 사용해 AI 리포트 생성",
      implementation: ["embedding", "retrieval", "structured output"],
      dataFlow: ["run_ai_features", "run_ai_reports", "generate-run-ai-report"],
      validation: ["유사 러닝 없음", "schema 오류 복구", "재시도 처리"],
      actions: ["AI 분석 버튼 선택", "생성 중 상태 확인", "요약, 개선점, 다음 목표, 코칭 문구 확인", "실패 시 재시도"],
      result: "run_ai_features와 run_ai_reports에 검색 기준과 생성 결과 저장",
      note: "벡터화된 과거 러닝 기록 결과의 유사도 비교를 통해 가장 과거의 유사한 러닝 기록과 비교하여 현재 러닝 피드백",
    },
    {
      title: "러닝 분석",
      icon: ChartNoAxesColumnIncreasing,
      tone: "blue",
      screen: "stats",
      purpose: "저장된 러닝 기록을 주간, 월간, 전체 기준으로 집계해 통계 카드와 그래프로 표시",
      implementation: ["period filter", "client aggregation", "recent AI summary"],
      dataFlow: ["run-history", "run_ai_reports", "runs"],
      validation: ["기간 변경", "빈 기록 상태", "그래프 범위"],
      actions: ["주간/월간/전체 기간 선택", "총 거리, 러닝 시간, 러닝 횟수, 평균 페이스 확인", "최근 7일 거리와 개인 최고 기록 확인", "최근 AI 분석 요약 확인"],
      result: "클라이언트 집계 결과와 최신 AI 리포트 요약이 분석 화면에 표시",
      note: "사용자의 누적 변화와 최근 AI 피드백을 한 화면에서 확인하는 분석 허브",
    },
    {
      title: "러닝 기록 조회",
      icon: History,
      tone: "cyan",
      screen: "history",
      purpose: "run-history API로 저장된 러닝 목록을 불러오고, 기간 필터에 맞게 요약 지표 계산",
      implementation: ["history fetch", "period summary", "detail navigation"],
      dataFlow: ["run-history", "runs", "run_splits"],
      validation: ["필터별 합계", "상세 재사용", "빈 목록 UI"],
      actions: ["일/주/월/년/전체 필터 선택", "총 러닝, 총 거리, 총 포인트, 총 점령 넓이 확인", "러닝 카드 선택 후 상세 결과 확인"],
      result: "선택한 러닝 raw 데이터를 RunResultPage로 전달해 상세 화면 재사용",
      note: "기록 목록은 단순 로그가 아니라 결과 리포트와 분석 화면으로 이어지는 탐색 경로",
    },
    {
      title: "포인트 내역",
      icon: Star,
      tone: "blue",
      screen: "points",
      purpose: "point_history 데이터를 조회해 포인트 발생 이벤트와 연결된 러닝 기록 표시",
      implementation: ["event log", "linked run", "point delta"],
      dataFlow: ["point-history", "point_history", "runs"],
      validation: ["증감 부호", "이벤트 유형", "기록 연결"],
      actions: ["누적 포인트 확인", "포인트 이벤트 유형 확인", "연결된 러닝 결과로 이동", "획득/사용 흐름 점검"],
      result: "포인트 증감 내역과 이벤트 유형을 기록 단위로 추적",
      note: "게임화 보상이 실제 어떤 러닝 또는 영토 이벤트에서 발생했는지 추적",
    },
    {
      title: "포인트 / 랭킹",
      icon: Trophy,
      tone: "emerald",
      screen: "ranking",
      purpose: "profile-leaderboard API와 일별 포인트 집계를 사용해 기간별 순위 표시",
      implementation: ["daily aggregate", "leaderboard query", "my rank window"],
      dataFlow: ["profile-leaderboard", "user_point_daily", "profiles"],
      validation: ["기간별 순위", "내 주변 순위", "동점 정렬"],
      actions: ["포인트 이력 조회", "포인트가 발생한 러닝 결과로 이동", "일/주/월/년/전체 랭킹 확인", "내 주변 순위 확인"],
      result: "선택 기간의 누적 포인트, 내 순위, 랭킹 리스트가 화면에 반영",
      note: "전체 누적값뿐 아니라 KST 기준 일별 집계로 기간별 경쟁 구성",
    },
    {
      title: "영토 상세",
      icon: Landmark,
      tone: "cyan",
      screen: "territory",
      purpose: "영토 점령과 관련된 데이터를 조회해 면적 지표, 지도 미리보기, 변화 기록 구성",
      implementation: ["PostGIS geometry", "area metric", "change timeline"],
      dataFlow: ["territories", "territory-geojson", "runs"],
      validation: ["면적 단위", "폴리곤 병합", "최근 변화 표시"],
      actions: ["현재 점령 면적, 오늘 증가, 주간 증가 확인", "지도에서 영토 폴리곤과 경로 확인", "영토 점령 러닝과 변화 타임라인 확인"],
      result: "PostGIS로 계산된 영토 geometry와 면적 변화가 사용자별로 표시",
      note: "GPS 경로가 앱의 차별점인 점령 영역으로 변환되는 결과 화면",
    },
    {
      title: "마이페이지 / 프로필",
      icon: UserCog,
      tone: "emerald",
      screen: "profile",
      purpose: "profiles 데이터를 기반으로 사용자 요약과 설정 진입점을 표시하는 화면",
      implementation: ["profile form", "summary cards", "settings links"],
      dataFlow: ["profiles", "update-profile", "auth signOut"],
      validation: ["닉네임 수정", "신체정보 반영", "로그아웃"],
      actions: ["프로필 요약 확인", "개인정보 수정으로 닉네임, 색상, 키/몸무게, 비밀번호 변경", "러닝 통계, 리포트, 점령면적, 포인트 내역 이동", "로그아웃 실행"],
      result: "프로필 수정, 주요 기록 화면 이동, 로그아웃을 마이페이지에서 처리",
      note: "러닝 기록과 포인트 계산에 필요한 사용자 기본 정보를 관리하는 설정 화면",
    },
  ];

  const stack = [
    ["Flutter / Dart", "Android/iOS 화면, 상태, 러닝 세션, 서비스 계층 구현", Code2, "flutter"],
    ["Google Maps / Geolocator", "현재 위치, 경로, 영토 지도 표시와 GPS 샘플 수집", Navigation2, "google-maps"],
    ["Supabase Auth", "이메일/비밀번호 인증과 앱 시작 세션 분기", LockKeyhole, "supabase"],
    ["Supabase Edge Functions", "러닝 저장, 기록 조회, 랭킹, 프로필, AI 분석 API", ServerCog, "supabase"],
    ["PostgreSQL / PostGIS", "러닝 기록, 포인트, 영토 geometry, 공간 연산", DatabaseZap, "postgis"],
    ["Android / iOS Native", "Foreground service, Notification action, ActivityKit, Widget Extension", Smartphone, null],
  ];

  const dataTables = [
    ["profiles", "닉네임, 색상, 신체정보, 총 포인트, 랭킹 기준 데이터"],
    ["runs", "러닝 단위 기록, 거리, 시간, 페이스, 칼로리, 포인트, 경로 geometry"],
    ["run_splits", "구간별 거리, 시간, 페이스, 속도, 고도 상승"],
    ["point_history", "러닝 완료, 영토 유지 등 포인트 이벤트 로그"],
    ["user_point_daily", "KST 기준 일별 포인트 집계와 기간 랭킹 기준"],
    ["territories", "사용자별 점유 영토 geometry, 면적, 갱신 시각"],
    ["run_ai_features", "embedding, 수치 feature, route centroid/bbox, summary text"],
    ["run_ai_reports", "AI 요약, 개선점, 다음 목표, 코칭 문구, 유사 기록 id"],
  ];

  const functions = [
    "create-run",
    "run-history",
    "point-history",
    "profile-leaderboard",
    "update-profile",
    "territory-geojson",
    "generate-run-ai-report",
    "run-ai-report",
    "backfill-run-embeddings",
  ];

  const timeline = [
    ["Phase 1", "기획 및 문제 정의", ["러닝 앱 시장과 기록 중심 서비스의 한계 분석", "GPS 경로와 게임화 요소를 결합한 기능 범위 정의"], ["문제 정의", "시장 분석", "기능 범위"]],
    ["Phase 2", "핵심 앱 구조 구현", ["Flutter 프로젝트 구성", "Supabase Auth 연동", "로그인/회원가입/세션 체크 구현"], ["Flutter", "Auth", "Session", "Profile"]],
    ["Phase 3", "러닝 기록 엔진 구현", ["RunSessionEngine 상태 관리", "GPS 필터링, 거리/속도/페이스/고도/split 계산"], ["RunEngine", "GPS Filter", "Pace", "Split"]],
    ["Phase 4", "백엔드와 영토 시스템", ["Supabase Edge Function 구성", "PostGIS 기반 영토 생성, 병합, 차감 처리"], ["Edge Function", "PostGIS", "Territory", "RPC"]],
    ["Phase 5", "게임화와 분석 화면", ["결과 리포트, 기록, 포인트 이력, 랭킹, 영토 상세 구현", "주간/월간/전체 통계와 최근 7일 그래프 추가"], ["Report", "Point", "Ranking", "Stats"]],
    ["Phase 6", "네이티브 기능 고도화", ["Android foreground service와 알림 제어", "iOS Live Activity, Dynamic Island 상태 표시"], ["Android Service", "Notification", "Live Activity", "Dynamic Island"]],
    ["Phase 7", "AI 러닝 분석 추가", ["embedding 기반 유사 러닝 검색", "OpenAI 기반 요약, 개선점, 다음 목표 생성"], ["Embedding", "Retrieval", "OpenAI", "AI Report"]],
    ["Phase 8", "테스트 및 안정화", ["flutter analyze / flutter test 통과", "API/DB E2E, 실제 iPhone release 실행 검증"], ["Analyze", "Unit Test", "API E2E", "Device Test"]],
  ];

  const teamMembers = [
    ["202133304", "권민지"],
    ["202135546", "송영우"],
    ["202336133", "최윤영"],
  ];

  const challenges = [
    ["GPS 오차 필터링", "부정확한 위치, 비정상 고속 이동, 러닝 시작 직후 튐을 필터링해 기록 품질 확보"],
    ["러닝 상태 보정", "일시정지 시간을 제외하고 재개 후 먼 위치는 새 segment로 처리해 거리 왜곡 감소"],
    ["영토 geometry 처리", "경로를 PostGIS geometry로 변환하고 사용자 영토를 생성, 병합, 차감하는 서버 로직 구성"],
    ["백그라운드 실행", "Flutter 앱 외부에서 Android foreground service와 iOS Live Activity를 연동해 실제 러닝 환경 보조"],
    ["AI 분석 안정화", "유사도 underflow와 structured output schema 오류를 수정하고 실제 기기에서 리포트 생성 검증"],
    ["데이터 정합성", "user_point_daily.run_points 미반영 문제를 migration과 backfill로 수정하고 E2E 테스트로 확인"],
  ];

  return (
    <main className="presentation-light min-h-screen overflow-hidden bg-[#F2F2F7] text-[#1C1C1E] selection:bg-[#007AFF] selection:text-white">
      <div className="pointer-events-none fixed inset-0 z-0">
        <div className="presentation-backdrop absolute inset-0" />
        <div className="presentation-grid absolute inset-0" />
      </div>

      <section className="relative z-10 flex min-h-screen items-center px-5 py-20 sm:px-8 lg:px-12">
        <div className="mx-auto grid max-w-7xl items-center gap-14 lg:grid-cols-[1.05fr_0.95fr]">
          <motion.div initial="hidden" animate="visible" variants={stagger} className="max-w-4xl">
            <motion.p variants={fadeUp} className="mb-5 inline-flex items-center gap-2 rounded-full border border-emerald-300/30 bg-emerald-300/10 px-4 py-2 text-sm font-semibold text-emerald-200">
              <Sparkles size={16} />
              Graduation Project Implementation Review
            </motion.p>
            <motion.h1 variants={fadeUp} className="whitespace-nowrap text-[clamp(3.1rem,12vw,8rem)] font-black leading-none text-white">
              RUNNER
              <span className="bg-gradient-to-r from-emerald-300 via-cyan-300 to-blue-400 bg-clip-text text-transparent">
                .IO
              </span>
            </motion.h1>
            <motion.p variants={fadeUp} className="mt-7 max-w-3xl text-xl leading-9 text-slate-300 sm:text-2xl">
              Flutter 기반 게임형 러닝 앱
            </motion.p>
            <motion.div variants={fadeUp} className="mt-9 flex flex-wrap gap-3">
              <Pill>Flutter</Pill>
              <Pill tone="cyan">GPS Tracking</Pill>
              <Pill tone="blue">PostGIS Territory</Pill>
              <Pill>Supabase</Pill>
              <Pill tone="cyan">AI Running Report</Pill>
              <Pill tone="blue">RAG Retrieval</Pill>
            </motion.div>
            <motion.div variants={fadeUp} className="mt-7 text-sm font-semibold leading-7 text-slate-400">
              <p className="uppercase tracking-[0.22em] text-[#007AFF]">Team 1 · Graduation Project 2</p>
              <p className="mt-2">
                {teamMembers.map(([studentId, name], index) => (
                  <React.Fragment key={studentId}>
                    <span className="font-mono text-slate-400">{studentId}</span>
                    <span className="ml-1 text-white">{name}</span>
                    {index < teamMembers.length - 1 && <span className="mx-3 text-slate-400">/</span>}
                  </React.Fragment>
                ))}
              </p>
            </motion.div>
            <motion.div variants={fadeUp} className="mt-12 flex items-center gap-4 text-slate-300">
              <div className="flex h-12 w-12 items-center justify-center rounded-full border border-white/15 bg-white/5">
                <ArrowDown size={20} />
              </div>
              <span className="text-sm font-medium uppercase tracking-[0.24em]">Scroll through implementation sections</span>
            </motion.div>
          </motion.div>
          <HeroVisual />
        </div>
      </section>

      <div className="relative z-10">
        <Section
          id="background"
          eyebrow="01 Background"
          title="기록중심의 러닝앱 + 게임성"
          description="거리, 시간, 페이스 측정 중심의 러닝 앱에서 포인트, 랭킹, 영토점령 요소를 추가한 게임형 러닝 앱으로 확장"
        >
          <motion.div variants={stagger} initial="hidden" whileInView="visible" viewport={{ once: true, margin: "-120px" }} className="grid gap-5 md:grid-cols-3">
            <FeatureCard icon={Route} title="기록 데이터" text="거리, 시간, 페이스 기본 지표와 후속 처리 구조 필요" tone="emerald" />
            <FeatureCard icon={Star} title="포인트/랭킹" text="러닝 결과 점수화와 기간별 집계 조회 기능 추가" />
            <FeatureCard icon={MapPinned} title="공간 데이터" text="경로를 PostGIS geometry로 변환해 사용자별 영토 데이터로 저장" tone="blue" />
          </motion.div>
        </Section>

        <Section
          id="goals"
          eyebrow="02 Goals"
          title="러닝 분석 시스템"
          description="피드백을 반영하여 러닝 기록 및 분석 처리 시스템 고도화"
          className="bg-white/[0.025]"
        >
          <motion.div variants={stagger} initial="hidden" whileInView="visible" viewport={{ once: true, margin: "-120px" }} className="grid gap-5 md:grid-cols-2 lg:grid-cols-4">
            <Metric value="AI" label="러닝 분석 리포트 추가" />
            <Metric value="기록" label="거리, 페이스, split 정확도 보강" />
            <Metric value="분석" label="이력, 통계, 결과 리포트 강화" />
            <Metric value="편의" label="백그라운드 추적과 AI 피드백 추가" />
          </motion.div>
        </Section>

        <Section
          id="features"
          eyebrow="03 Final Scope"
          title="최종 구현 범위"
          description="인증, 러닝 세션, 지도, 결과 저장, 포인트/랭킹, 영토, 네이티브 연동, AI 리포트"
        >
          <motion.div variants={stagger} initial="hidden" whileInView="visible" viewport={{ once: true, margin: "-120px" }} className="grid gap-5 md:grid-cols-2 lg:grid-cols-4">
            {finalFeatures.map(([title, text, icon, tone]) => (
              <FeatureCard key={title} title={title} text={text} icon={icon} tone={tone} />
            ))}
          </motion.div>
        </Section>

        <Section
          id="user-guide"
          eyebrow="04 User Guide"
          title="유저 워크플로우"
          description="인증부터 러닝 기록, 결과 확인, 분석 리포트, 랭킹/영토 확인까지 이어지는 사용자 워크플로우"
          className="bg-white/[0.025] py-16"
        >
          <FeatureGuideCarousel guides={userGuides} />
        </Section>

        <Section
          id="stack"
          eyebrow="05 Technology Stack"
          title="Technology Stack"
          description="클라이언트는 Flutter/Dart, 인증과 DB, Edge Function은 Supabase, GPS 경로와 영토 계산은 PostGIS 기반"
        >
          <motion.div variants={stagger} initial="hidden" whileInView="visible" viewport={{ once: true, margin: "-120px" }} className="grid gap-5 md:grid-cols-2 lg:grid-cols-3">
            {stack.map(([title, text, icon, brand]) => (
              <FeatureCard key={title} title={title} text={text} icon={icon} brand={brand} />
            ))}
          </motion.div>
        </Section>

        <Section
          id="architecture"
          eyebrow="06 System Architecture"
          title="Flutter Client + Supabase Backend"
          description="앱은 화면 상태와 실시간 러닝 세션 처리. 서버는 기록 저장, 파생 데이터 계산, 랭킹 조회, AI 리포트 생성 담당"
        >
          <GlassCard>
            <ArchitectureMap />
            <div className="my-6 h-px bg-gradient-to-r from-transparent via-cyan-300/30 to-transparent" />
            <div className="grid items-stretch gap-4 lg:grid-cols-[1fr_auto_1fr_auto_1fr_auto_1fr]">
              <DiagramNode icon={Footprints} title="User" detail="러닝 시작, 일시정지, 종료, 결과 확인" />
              <ArrowConnector />
              <DiagramNode icon={Smartphone} brand="flutter" title="Flutter App" detail="화면, 지도, 러닝 상태, 서비스 계층" />
              <ArrowConnector />
              <DiagramNode icon={Cloud} brand="supabase" title="Edge Functions" detail="create-run, history, ranking, AI report" />
              <ArrowConnector />
              <DiagramNode icon={DatabaseZap} brand="postgis" title="PostgreSQL + PostGIS" detail="기록, 포인트, 랭킹, 영토 geometry" />
            </div>
            <div className="mt-6 grid gap-4 md:grid-cols-4">
              <CompactCard icon={LockKeyhole} brand="supabase" title="Supabase Auth" text="인증과 세션 분기" />
              <CompactCard icon={Navigation2} brand="google-maps" title="Geolocator" text="GPS 샘플 수집" />
              <CompactCard icon={Radio} title="Android Service" text="백그라운드 위치와 알림 제어" />
              <CompactCard icon={BellRing} title="iOS Live Activity" text="잠금화면과 Dynamic Island 표시" />
            </div>
          </GlassCard>
        </Section>

        <Section
          id="runtime-flow"
          eyebrow="07 Runtime Data Flow"
          title="러닝 데이터 처리 워크플로우"
          description="GPS 샘플은 RunSessionEngine에서 계산. 종료 후 create-run 저장, 포인트, 일별 집계, 랭킹, 영토, AI 분석용 feature 순차 갱신"
          className="bg-white/[0.025]"
        >
          <RuntimeFlowDiagram />
          <motion.div variants={stagger} initial="hidden" whileInView="visible" viewport={{ once: true, margin: "-120px" }} className="mt-6 grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            <FlowStep index={1} icon={Navigation2} title="GPS Stream" detail="Geolocator 위치 샘플 수집" />
            <FlowStep index={2} icon={Timer} title="RunSessionEngine" detail="필터링, 거리, 페이스, split 계산" />
            <FlowStep index={3} icon={Cloud} title="create-run" detail="runs와 run_splits 저장" />
            <FlowStep index={4} icon={GitBranch} title="DB Trigger/RPC" detail="포인트, 랭킹, 영토 파생 처리" />
            <FlowStep index={5} icon={ClipboardList} title="Result / History" detail="결과, 기록, 분석 화면 반영" />
            <FlowStep index={6} icon={Trophy} title="Point / Ranking" detail="포인트 이력과 기간별 순위 갱신" />
            <FlowStep index={7} icon={Layers3} title="Territory" detail="영토 geometry 생성, 병합, 차감" />
            <FlowStep index={8} icon={WandSparkles} title="AI Report" detail="유사 러닝 검색과 코칭 리포트 생성" />
          </motion.div>
        </Section>

        <Section
          id="engine"
          eyebrow="08 Core Logic"
          title="GPS 기반 실시간 데이터 처리"
          description="위치 샘플은 정확도, 이동 거리, 파생 속도 기준으로 필터링. 일시정지 시간과 split 계산은 엔진 내부 상태로 관리"
        >
          <div className="grid gap-6 lg:grid-cols-[0.9fr_1.1fr]">
            <GlassCard>
              <h3 className="text-2xl font-semibold text-white">상태 관리</h3>
              <div className="mt-6 grid grid-cols-2 gap-3">
                {[
                  { state: "idle", icon: CircleDot, tone: "text-slate-300" },
                  { state: "running", icon: Play, tone: "text-emerald-300" },
                  { state: "paused", icon: Pause, tone: "text-amber-300" },
                  { state: "resumed", icon: RotateCw, tone: "text-cyan-300" },
                  { state: "stopped", icon: Square, tone: "text-blue-300" },
                  { state: "cancelled", icon: CircleX, tone: "text-rose-300" },
                ].map(({ state, icon: Icon, tone }) => (
                  <div key={state} className="flex items-center gap-3 rounded-lg border border-white/10 bg-slate-950/60 p-4 font-mono text-sm text-cyan-100">
                    <Icon className={tone} size={18} />
                    <span>{state}</span>
                  </div>
                ))}
              </div>
            </GlassCard>
            <GlassCard>
              <h3 className="text-2xl font-semibold text-white">샘플 처리 기준</h3>
              <div className="mt-6 grid gap-3 sm:grid-cols-2">
                {[
                  "Maximum accuracy filtering",
                  "Minimum movement threshold",
                  "Abnormal derived-speed filtering",
                  "Warm-up sample handling",
                  "Paused-time compensation",
                  "Split / ascent accumulation",
                ].map((item) => (
                  <div key={item} className="flex items-center gap-3 rounded-lg border border-white/10 bg-slate-950/60 p-4">
                    <BadgeCheck className="text-emerald-300" size={18} />
                    <span className="text-sm text-slate-200">{item}</span>
                  </div>
                ))}
              </div>
            </GlassCard>
          </div>
        </Section>

        <Section
          id="data-api"
          eyebrow="09 Data & API"
          title="Supabase Tables / Edge Function"
          description="러닝 결과는 runs와 run_splits에 저장. 이후 point_history, user_point_daily, territories, run_ai_features, run_ai_reports로 파생 데이터 분리"
          className="bg-white/[0.025]"
        >
          <div className="grid gap-6 lg:grid-cols-[1fr_0.82fr]">
            <GlassCard>
              <h3 className="text-2xl font-semibold text-white">Main Tables</h3>
              <div className="mt-6 grid gap-3 md:grid-cols-2">
                {dataTables.map(([name, desc]) => (
                  <div key={name} className="rounded-lg border border-white/10 bg-slate-950/60 p-4">
                    <p className="font-mono text-sm font-semibold text-emerald-300">{name}</p>
                    <p className="mt-2 text-sm leading-6 text-slate-300">{desc}</p>
                  </div>
                ))}
              </div>
            </GlassCard>
            <GlassCard>
              <h3 className="text-2xl font-semibold text-white">Edge Functions</h3>
              <div className="mt-6 flex flex-wrap gap-3">
                {functions.map((name) => (
                  <span key={name} className="rounded-lg border border-cyan-300/20 bg-cyan-300/10 px-3 py-2 font-mono text-sm text-cyan-100">
                    {name}
                  </span>
                ))}
              </div>
              <div className="mt-8 rounded-lg border border-emerald-300/20 bg-emerald-300/10 p-5">
                <p className="font-semibold text-emerald-100">주요 RPC / Trigger</p>
                <p className="mt-3 text-sm leading-7 text-slate-300">
                  process_run_geometry, upsert_or_merge_territory, subtract_territory_and_update,
                  handle_run_points, match_similar_runs
                </p>
              </div>
            </GlassCard>
          </div>
        </Section>

        <Section
          id="territory"
          eyebrow="10 Territory Processing"
          title="러닝 경로 데이터 처리 / 영토 계산 로직"
          description="사용자 경로를 공간 geometry로 처리. 기존 영토와 병합하거나 다른 사용자 영토와 겹치는 영역 차감"
        >
          <GlassCard>
            <motion.div variants={stagger} initial="hidden" whileInView="visible" viewport={{ once: true, margin: "-120px" }} className="grid gap-4 md:grid-cols-5">
              {[
                ["Route", "GPS path", Route],
                ["Geometry", "path conversion", MapPinned],
                ["Merge", "same user area", Layers3],
                ["Subtract", "overlap area", Network],
                ["GeoJSON", "map polygon", Map],
              ].map(([title, detail, Icon]) => (
                <motion.div key={title} variants={fadeUp} className="rounded-lg border border-white/10 bg-slate-950/60 p-5">
                  <Icon className="mb-4 text-cyan-300" size={24} />
                  <h3 className="font-semibold text-white">{title}</h3>
                  <p className="mt-2 text-sm text-slate-300">{detail}</p>
                </motion.div>
              ))}
            </motion.div>
          </GlassCard>
        </Section>

        <Section
          id="native"
          eyebrow="11 Native Integration"
          title="Android / iOS Native"
          description="러닝 중 백그라운드 전환 대응을 위해 Android foreground service와 iOS Live Activity 연결"
          className="bg-white/[0.025]"
        >
          <div className="grid gap-6 lg:grid-cols-2">
            <GlassCard>
              <IconBadge icon={AndroidIcon} tone="emerald" />
              <h3 className="mt-5 text-2xl font-semibold text-white">Android</h3>
              <ul className="mt-5 space-y-3 text-slate-300">
                {["Foreground Service 기반 백그라운드 위치 추적", "Notification action으로 pause / resume / stop", "RunLockScreenService와 RunActionReceiver 구성", "TTS split 안내와 러닝 상태 유지"].map((item) => (
                  <li key={item} className="flex gap-3"><BadgeCheck className="mt-1 text-emerald-300" size={17} /><span>{item}</span></li>
                ))}
              </ul>
            </GlassCard>
            <GlassCard>
              <IconBadge icon={AppleIcon} tone="cyan" />
              <h3 className="mt-5 text-2xl font-semibold text-white">iOS</h3>
              <ul className="mt-5 space-y-3 text-slate-300">
                {["ActivityKit 기반 Live Activity", "Dynamic Island 러닝 상태 표시", "Widget Extension과 Intent 구성", "실제 iPhone release 실행 및 서명 이슈 해결"].map((item) => (
                  <li key={item} className="flex gap-3"><BadgeCheck className="mt-1 text-cyan-300" size={17} /><span>{item}</span></li>
                ))}
              </ul>
            </GlassCard>
          </div>
        </Section>

        <Section
          id="ai"
          eyebrow="12 AI Running Analysis"
          title="RAG형 AI 리포트 생성 흐름"
          description="현재 러닝과 유사한 과거 기록 조회 후 context로 전달. 요약, 개선점, 다음 목표, 코칭 문구 생성"
        >
          <div className="grid gap-6 lg:grid-cols-[1.05fr_0.95fr]">
            <GlassCard>
              <h3 className="text-2xl font-semibold text-white">Implemented RAG-like Pipeline</h3>
              <div className="mt-6">
                <RagPipelineDiagram />
              </div>
              <div className="mt-6 grid gap-3 md:grid-cols-2">
                {[
                  ["1. Trigger", "RunResultPage에서 AI 분석 버튼 클릭"],
                  ["2. Feature Store", "run_ai_features에 embedding, 수치 feature, 경로 요약 저장"],
                  ["3. Retrieval", "match_similar_runs RPC로 유사 러닝 3~5개 검색"],
                  ["4. Context", "현재 기록, split, 과거 유사 기록을 LLM context로 구성"],
                  ["5. Generation", "OpenAI Responses API로 요약, 개선점, 다음 목표 생성"],
                  ["6. Persistence", "run_ai_reports 저장 후 결과/분석 화면에 표시"],
                ].map(([label, item]) => (
                  <div key={label} className="rounded-lg border border-white/10 bg-slate-950/60 p-4">
                    <p className="font-mono text-sm font-bold text-emerald-300">{label}</p>
                    <p className="mt-2 text-sm leading-6 text-slate-200">{item}</p>
                  </div>
                ))}
              </div>
            </GlassCard>
            <GlassCard>
              <h3 className="text-2xl font-semibold text-white">Similarity Score</h3>
              <div className="mt-6 rounded-lg border border-cyan-300/20 bg-cyan-300/10 p-5 font-mono text-sm leading-8 text-cyan-50">
                total_score =<br />
                embedding_score * 0.45<br />
                + numeric_score * 0.35<br />
                + spatial_score * 0.20
              </div>
              <div className="mt-6 grid grid-cols-2 gap-3">
                <Metric value="49" label="embedding backfill" />
                <Metric value="200" label="기기 테스트 API 응답" />
              </div>
              <div className="mt-6 rounded-lg border border-white/10 bg-slate-950/60 p-5">
                <div className="mb-4 flex items-center gap-3">
                  <IconBadge icon={Bot} tone="emerald" />
                  <div>
                    <p className="font-mono text-xs font-semibold uppercase tracking-[0.18em] text-emerald-300">Prompt to GPT API</p>
                    <h4 className="text-lg font-black text-white">리포트 생성 프롬프트</h4>
                  </div>
                </div>
                <div className="space-y-3">
                  <div className="flex justify-start">
                    <div className="max-w-[92%] rounded-[22px] rounded-tl-md border border-white/10 bg-white/80 px-4 py-3 shadow-[0_10px_24px_rgba(28,28,30,0.06)]">
                      <p className="font-mono text-[10px] font-black uppercase tracking-[0.18em] text-[#007AFF]">System</p>
                      <p className="mt-2 text-sm font-semibold leading-6 text-slate-300">
                        러닝 코치처럼 현재 기록을 분석하고, 바로 적용할 수 있는 피드백을 한국어로 작성하세요.
                      </p>
                    </div>
                  </div>
                  {[
                    ["User", "{distance}, {duration}, {avgPace}, split 데이터를 참고하세요."],
                    ["Context", "{similarRuns}와 비교해 현재 러닝의 특징을 찾으세요."],
                    ["Format", "요약, 개선점, 다음 목표, 코칭 문구로 반환하세요."],
                  ].map(([label, text]) => (
                    <div key={label} className="flex justify-start">
                      <div className="max-w-[92%] rounded-[22px] rounded-tl-md border border-white/10 bg-white/80 px-4 py-3 shadow-[0_10px_24px_rgba(28,28,30,0.06)]">
                        <p className="font-mono text-[10px] font-black uppercase tracking-[0.18em] text-[#007AFF]">
                          {label}
                        </p>
                        <p className="mt-2 text-sm font-semibold leading-6 text-slate-300">
                          {text}
                        </p>
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </GlassCard>
          </div>
        </Section>

        <Section
          id="workflow"
          eyebrow="15 Development Workflow"
          title="개발 진행 방식"
          description="기능 계획서, 구현 보고서, 테스트 계획을 남기며 기능 단위 구현과 검증 진행"
        >
          <GlassCard>
            <div className="grid gap-4 md:grid-cols-3 lg:grid-cols-5">
              {[
                ["Discovery", "기존 코드/문서 분석"],
                ["Feature Plan", "목표, 범위, 데이터/API 정의"],
                ["Implementation", "단계별 기능 구현"],
                ["Verification", "자동 테스트와 실제 기기 검증"],
                ["Report", "결과와 한계 문서화"],
              ].map(([title, text], index) => (
                <div key={title} className="rounded-lg border border-white/10 bg-slate-950/60 p-5">
                  <p className="font-mono text-sm text-emerald-300">0{index + 1}</p>
                  <h3 className="mt-3 font-semibold text-white">{title}</h3>
                  <p className="mt-2 text-sm leading-6 text-slate-300">{text}</p>
                </div>
              ))}
            </div>
          </GlassCard>
        </Section>

        <Section
          id="timeline"
          eyebrow="16 Development Timeline"
          title="개발 일정"
          description="기획, 인증, 러닝 엔진, 백엔드, 지도/영토, 분석 화면, 네이티브 기능, AI 분석, 테스트 순서로 범위 확장"
          className="bg-white/[0.025]"
        >
          <motion.div variants={stagger} initial="hidden" whileInView="visible" viewport={{ once: true, margin: "-120px" }}>
            <DevelopmentProcess timeline={timeline} />
          </motion.div>
        </Section>

        <Section
          id="challenges"
          eyebrow="18 Key Challenges"
          title="구현 중 처리한 주요 문제"
          description="GPS 정확도, 공간 DB 연산, 백그라운드 실행, AI 응답 형식처럼 계층별 오류 가능 지점 확인과 수정"
          className="bg-white/[0.025]"
        >
          <motion.div variants={stagger} initial="hidden" whileInView="visible" viewport={{ once: true, margin: "-120px" }} className="grid gap-5 md:grid-cols-2 lg:grid-cols-3">
            {challenges.map(([title, text]) => (
              <GlassCard key={title}>
                <BadgeCheck className="mb-4 text-emerald-300" size={22} />
                <h3 className="text-lg font-semibold text-white">{title}</h3>
                <p className="mt-3 text-sm leading-7 text-slate-300">{text}</p>
              </GlassCard>
            ))}
          </motion.div>
        </Section>

        <Section
          id="limits"
          eyebrow="20 Results & Future Work"
          title="구현 결과와 향후 보완"
          description="핵심 사용자 흐름은 실제 앱 시연 가능 상태. 향후 GPS 보정, 장시간 러닝 성능, 서버 집계, RAG 질의 기능 보완"
          className="bg-white/[0.025]"
        >
          <div className="grid gap-6 lg:grid-cols-2">
            <GlassCard>
              <h3 className="text-2xl font-semibold text-white">현재 성과</h3>
              <ul className="mt-5 space-y-3 text-slate-300">
                {["인증부터 러닝 저장, 결과 확인까지 핵심 흐름 완성", "GPS 기반 실시간 기록과 지도 경로 시각화", "PostGIS 기반 영토 점령 구조 구현", "포인트, 랭킹, 분석, AI 리포트 연결", "Android/iOS 네이티브 백그라운드 기능 연동"].map((item) => (
                  <li key={item} className="flex gap-3"><BadgeCheck className="mt-1 text-emerald-300" size={17} /><span>{item}</span></li>
                ))}
              </ul>
            </GlassCard>
            <GlassCard>
              <h3 className="text-2xl font-semibold text-white">향후 보완</h3>
              <ul className="mt-5 space-y-3 text-slate-300">
                {["도심/터널 환경 GPS 보정 고도화", "장거리 러닝과 다량 데이터 성능 최적화", "통계 집계 서버 API 분리", "친구/그룹 랭킹과 시즌제 영토", "문서 기반 RAG와 자연어 기록 질의 확장"].map((item) => (
                  <li key={item} className="flex gap-3"><Target className="mt-1 text-cyan-300" size={17} /><span>{item}</span></li>
                ))}
              </ul>
            </GlassCard>
          </div>
        </Section>

        <section className="relative px-5 py-28 sm:px-8 lg:px-12">
          <div className="mx-auto max-w-7xl">
            <motion.div initial={{ opacity: 0, y: 34 }} whileInView={{ opacity: 1, y: 0 }} viewport={{ once: true, margin: "-120px" }} transition={{ duration: 0.8, ease: "easeOut" }} className="overflow-hidden rounded-lg border border-emerald-300/20 bg-gradient-to-br from-emerald-300/12 via-cyan-300/8 to-blue-500/12 p-8 shadow-2xl shadow-emerald-950/30 backdrop-blur-xl sm:p-12 lg:p-16">
              <p className="mb-4 text-sm font-semibold uppercase tracking-[0.28em] text-emerald-300">Conclusion</p>
              <h2 className="max-w-5xl text-4xl font-black tracking-tight text-white sm:text-6xl">
                Flutter 기반 영토 점령 게임화 러닝 앱
              </h2>
              <p className="mt-8 max-w-4xl text-lg leading-9 text-slate-300">
                Runner.io는 GPS 러닝 기록을 저장하고, 경로 지도, 영토 geometry, 포인트/랭킹, AI 리포트로 파생 처리하는 Flutter 기반 모바일 애플리케이션
              </p>
              <div className="mt-10 grid gap-5 md:grid-cols-3">
                {[
                  ["Mobile", "Flutter와 네이티브 기능을 결합한 실제 러닝 앱"],
                  ["Spatial Data", "PostGIS 기반 경로/영토 처리와 지도 시각화"],
                  ["Validation", "테스트, 배포 함수 검증, 실제 기기 확인까지 수행"],
                ].map(([title, text]) => (
                  <div key={title} className="rounded-lg border border-white/10 bg-slate-950/55 p-6">
                    <h3 className="text-xl font-semibold text-white">{title}</h3>
                    <p className="mt-4 leading-7 text-slate-300">{text}</p>
                  </div>
                ))}
              </div>
            </motion.div>
          </div>
        </section>
      </div>
    </main>
  );
}
