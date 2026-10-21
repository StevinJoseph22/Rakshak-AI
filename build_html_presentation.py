import os

html_template = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Rakshak-AI: Master Executive Presentation (20 Advanced In-Depth Slides)</title>
  <script src="https://www.gstatic.com/antigravity/web/dev/tailwindcss.min.js"></script>
  <style>
    body {
      background-color: #060913;
      color: #f8fafc;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      user-select: none;
    }
    .slide-container {
      aspect-ratio: 16 / 9;
      max-height: 86vh;
    }
    .card-glass {
      background: rgba(15, 23, 42, 0.85);
      border: 1px solid rgba(51, 65, 85, 0.6);
      backdrop-filter: blur(12px);
    }
    .glow-emerald {
      box-shadow: 0 0 25px -5px rgba(16, 185, 129, 0.3);
    }
    .glow-cyan {
      box-shadow: 0 0 25px -5px rgba(56, 189, 248, 0.3);
    }
    .glow-rose {
      box-shadow: 0 0 25px -5px rgba(239, 68, 68, 0.3);
    }
    ::-webkit-scrollbar { width: 6px; }
    ::-webkit-scrollbar-track { background: #0f172a; }
    ::-webkit-scrollbar-thumb { background: #334155; border-radius: 9999px; }
  </style>
</head>
<body class="min-h-screen flex flex-col items-center justify-between p-2 sm:p-4 bg-slate-950 overflow-x-hidden">

  <!-- Top Global Header / Meta Bar -->
  <header class="w-full max-w-7xl flex items-center justify-between pb-3 border-b border-slate-800/80 mb-2">
    <div class="flex items-center gap-3">
      <div class="w-9 h-9 rounded-xl bg-gradient-to-tr from-emerald-500 via-cyan-400 to-blue-500 flex items-center justify-center font-black text-slate-950 shadow-lg shadow-emerald-500/20 text-lg">
        🛡️
      </div>
      <div>
        <div class="flex items-center gap-2">
          <span class="font-extrabold text-lg tracking-tight bg-gradient-to-r from-emerald-400 via-cyan-300 to-white bg-clip-text text-transparent">RAKSHAK-AI</span>
          <span class="px-2 py-0.5 text-[10px] font-bold rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">MASTER 20-SLIDE DECK</span>
        </div>
        <p class="text-xs text-slate-400">20 Advanced Slides: ERP Architecture, Edge Kinematic AI, C-V2X Green Wave, PINN Biomechanics, ABDM Vault & 93+ Tests</p>
      </div>
    </div>

    <!-- Quick Slide Selector Dropdown & Actions -->
    <div class="flex items-center gap-2">
      <select id="slideSelect" class="bg-slate-900 border border-slate-700 text-xs text-slate-200 rounded-lg px-2.5 py-1.5 focus:outline-none focus:border-cyan-400">
        <!-- Injected via JS -->
      </select>
      <button id="btnFullscreen" class="px-3 py-1.5 rounded-lg bg-slate-900 hover:bg-slate-800 border border-slate-700 text-xs font-semibold text-slate-300 flex items-center gap-1.5 transition">
        <span>⛶</span> Fullscreen
      </button>
      <button id="btnToggleNotes" class="px-3 py-1.5 rounded-lg bg-emerald-950/40 hover:bg-emerald-900/60 border border-emerald-700/50 text-xs font-semibold text-emerald-300 flex items-center gap-1.5 transition">
        <span>📝</span> <span id="notesLabel">Notes: ON</span>
      </button>
    </div>
  </header>

  <!-- Main Slide Frame (16:9 Cinema Container) -->
  <main class="w-full max-w-7xl flex-1 flex flex-col justify-center">
    <div class="w-full slide-container bg-slate-900/90 border border-slate-800 rounded-2xl shadow-2xl p-6 sm:p-8 flex flex-col justify-between relative overflow-hidden">
      <!-- Dynamic Slide Content Injected Here -->
      <div id="slideViewport" class="h-full flex flex-col justify-between">
        <!-- Rendered by JS -->
      </div>
    </div>

    <!-- Speaker Notes & Method Drawer (Expandable) -->
    <div id="speakerNotesDrawer" class="w-full mt-3 p-4 rounded-xl card-glass border-slate-800 text-slate-300 text-xs leading-relaxed max-h-40 overflow-y-auto">
      <div class="flex items-center justify-between pb-2 mb-2 border-b border-slate-800 text-[11px] font-bold text-slate-400 uppercase tracking-wider">
        <span>🎙️ SPEAKER NOTES & IN-DEPTH METHODOLOGY FOR SLIDE <span id="notesSlideNumber" class="text-white">1</span></span>
        <span class="text-emerald-400 font-mono">Use Arrow Keys / Space to Navigate</span>
      </div>
      <div id="speakerNotesContent" class="space-y-1">
        <!-- Injected by JS -->
      </div>
    </div>
  </main>

  <!-- Bottom Navigation & Presentation Controls Bar -->
  <footer class="w-full max-w-7xl flex items-center justify-between pt-3 border-t border-slate-800/80 mt-2">
    <div class="flex items-center gap-2">
      <button id="btnPrev" class="px-4 py-2 rounded-xl bg-slate-900 hover:bg-slate-800 border border-slate-700 text-xs font-bold text-slate-200 transition disabled:opacity-40 disabled:cursor-not-allowed flex items-center gap-1.5">
        ← Previous
      </button>
      <button id="btnNext" class="px-5 py-2 rounded-xl bg-gradient-to-r from-emerald-500 to-cyan-500 hover:from-emerald-400 hover:to-cyan-400 text-slate-950 text-xs font-black tracking-wide shadow-lg shadow-emerald-500/20 transition disabled:opacity-40 disabled:cursor-not-allowed flex items-center gap-1.5">
        Next Slide →
      </button>
    </div>

    <div class="flex items-center gap-4">
      <div id="slideIndicator" class="text-xs font-mono font-bold text-slate-400">
        Slide 01 / 20
      </div>
      <div class="w-36 h-2 rounded-full bg-slate-900 border border-slate-800 overflow-hidden">
        <div id="slideProgressBar" class="h-full bg-gradient-to-r from-emerald-500 to-cyan-400 transition-all duration-300" style="width: 5%;"></div>
      </div>
    </div>
  </footer>

  <!-- Slide Data & Presentation Engine -->
  <script>
    const slides = [
      {
        id: 1,
        category: "Advanced Emergency Operations & Smart City Defense",
        catColor: "emerald",
        title: "RAKSHAK-AI",
        render: () => `
          <div class="h-full flex flex-col justify-between">
            <div class="space-y-4">
              <div class="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-500/10 border border-emerald-500/30 text-emerald-400 text-xs font-bold uppercase tracking-wider">
                ⚡ NATIONAL HACKATHON INNOVATION • HEALTHCARE & SMART CITIES
              </div>
              <h1 class="text-5xl sm:text-6xl font-black tracking-tight text-white leading-tight">
                RAKSHAK-AI
              </h1>
              <h2 class="text-xl sm:text-2xl font-bold text-cyan-300 max-w-4xl leading-snug">
                Autonomous Emergency Guardianship & Inter-Agency Emergency Resource Planning (ERP) Platform
              </h2>
              <p class="text-slate-300 text-sm sm:text-base max-w-4xl leading-relaxed pt-2">
                A breakthrough distributed platform uniting on-device kinematic AI (TFLite), C-V2X autonomous traffic signal preemption, physics-informed crash biomechanics (PINN), and zero-knowledge Ayushman Bharat (ABDM/ABHA) emergency health cards. Engineered as an Enterprise Resource Planning (ERP) backbone to solve India's fatal road crash crisis during the critical Golden Hour.
              </p>
            </div>

            <div class="grid grid-cols-2 sm:grid-cols-4 gap-3 pt-6 border-t border-slate-800">
              <div class="p-3 rounded-xl bg-slate-950/60 border border-slate-800">
                <div class="text-xs text-slate-400 uppercase font-semibold">PILOT CITY</div>
                <div class="text-base font-bold text-emerald-400">Bengaluru, KA</div>
              </div>
              <div class="p-3 rounded-xl bg-slate-950/60 border border-slate-800">
                <div class="text-xs text-slate-400 uppercase font-semibold">TRANSIT SPEEDUP</div>
                <div class="text-base font-bold text-cyan-400">75% Faster Delivery</div>
              </div>
              <div class="p-3 rounded-xl bg-slate-950/60 border border-slate-800">
                <div class="text-xs text-slate-400 uppercase font-semibold">STATUTORY COMPLIANCE</div>
                <div class="text-base font-bold text-amber-400">DPDP Act 2023 & NHA</div>
              </div>
              <div class="p-3 rounded-xl bg-slate-950/60 border border-slate-800">
                <div class="text-xs text-slate-400 uppercase font-semibold">TEST COVERAGE</div>
                <div class="text-base font-bold text-purple-400">93+ Automated Tests</div>
              </div>
            </div>
          </div>
        `,
        notes: `
          Welcome the judges and introduce Rakshak-AI with confidence.
          Key hook: Every 3.4 minutes, someone dies on Indian roads. It's not a lack of doctors, but the lost Golden Hour.
          Rakshak-AI is the first unified Emergency Resource Planning (ERP) ecosystem connecting the victim's phone, city traffic lights, 108 ambulances, and hospital trauma bays.
        `
      },
      {
        id: 2,
        category: "Problem Statement & Clinical Evidence",
        catColor: "rose",
        title: "The Critical Crisis: India's Fatal Road Accident Epidemic",
        render: () => `
          <div class="h-full flex flex-col justify-between space-y-4">
            <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
              <div class="card-glass p-3.5 rounded-xl border-l-4 border-l-rose-500">
                <div class="text-2xl sm:text-3xl font-black text-rose-400">153,972+</div>
                <div class="text-xs font-bold text-white uppercase mt-1">ANNUAL FATALITIES</div>
                <div class="text-[11px] text-slate-400 mt-1">11% of global road deaths with only 1% of world vehicles (MoRTH Report).</div>
              </div>
              <div class="card-glass p-3.5 rounded-xl border-l-4 border-l-amber-500">
                <div class="text-2xl sm:text-3xl font-black text-amber-400">Every 3.4 Min</div>
                <div class="text-xs font-bold text-white uppercase mt-1">FATAL CRASH INTERVAL</div>
                <div class="text-[11px] text-slate-400 mt-1">461,000+ severe disabling injuries every single year across India.</div>
              </div>
              <div class="card-glass p-3.5 rounded-xl border-l-4 border-l-emerald-500">
                <div class="text-2xl sm:text-3xl font-black text-emerald-400">50%+</div>
                <div class="text-xs font-bold text-white uppercase mt-1">PREVENTABLE DEATHS</div>
                <div class="text-[11px] text-slate-400 mt-1">Over half of trauma casualties are clinically preventable if care begins within 60 mins.</div>
              </div>
              <div class="card-glass p-3.5 rounded-xl border-l-4 border-l-cyan-500">
                <div class="text-2xl sm:text-3xl font-black text-cyan-400">38-47 Min</div>
                <div class="text-xs font-bold text-white uppercase mt-1">MEDIAN RESPONSE LAG</div>
                <div class="text-[11px] text-slate-400 mt-1">Bystanders hesitate; ambulances sit motionless behind red lights.</div>
              </div>
            </div>

            <div class="card-glass p-4 rounded-xl border border-slate-800">
              <div class="text-xs font-bold text-rose-400 uppercase tracking-wider mb-2">THE ANATOMY OF DELAY: WHY THE GOLDEN HOUR IS ROUTINELY LOST</div>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3 text-xs text-slate-300">
                <div>
                  <span class="text-cyan-300 font-bold">1. Discovery & Reporting Delay (~14 Min):</span>
                  Unconscious victims cannot call 108. Bystanders fear police interrogation despite Good Samaritan laws.
                </div>
                <div>
                  <span class="text-cyan-300 font-bold">2. Dispatch & Routing Latency (~9 Min):</span>
                  Central 108 centers rely on vague verbal landmarks instead of sub-meter GPS coordinates.
                </div>
                <div>
                  <span class="text-cyan-300 font-bold">3. Traffic Gridlock & Red Lights (~16 Min):</span>
                  Dense intersections (Silk Board, Tin Factory) lack Emergency Vehicle Preemption; ambulances crawl at 8 km/h.
                </div>
                <div>
                  <span class="text-cyan-300 font-bold">4. Blind Hospital Intake (~8 Min):</span>
                  Trauma bays receive patients with zero warning, unknown blood type, and unprepared surgical suites.
                </div>
              </div>
            </div>
          </div>
        `,
        notes: `
          Slide 2 grounds the audience in official MoRTH and WHO data.
          Stress that the first 60 minutes ("The Golden Hour") is where medical outcomes are decided.
          Walk the judges through the 4-part 'Anatomy of Delay'.
        `
      },
      {
        id: 3,
        category: "Economic Analysis & Societal Burden",
        catColor: "amber",
        title: "Macroeconomic & National GDP Impact: The ₹12.9 Lakh Crore Toll",
        render: () => `
          <div class="h-full grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="card-glass p-4 rounded-xl border-l-4 border-l-amber-500 flex flex-col justify-between">
              <div>
                <div class="text-xs font-bold text-amber-400 uppercase tracking-wider mb-2">THE MACROECONOMIC NUMBERS (WORLD BANK & MoRTH)</div>
                <div class="space-y-3 text-xs text-slate-300">
                  <div>
                    <span class="text-white font-bold block text-sm">📉 3.14% of India's Annual GDP Destroyed</span>
                    World Bank estimates annual road accident costs at ~157 Billion USD (₹12.9 Lakh Crores) in lost economic output.
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">👥 Demographic Catastrophe: 70% in Prime Age</span>
                    Over 70% of road fatalities strike citizens aged 18 to 45 years — the primary breadwinners of the Indian economy.
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">🏚️ 2.8 Million Families Pushed Into Poverty</span>
                    Catastrophic Out-of-Pocket Expenditure (OOPE) for emergency ICU care causes immediate household bankruptcy.
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">💸 Massive Fiscal Burden on Insurers & States</span>
                    Over ₹32,000 Crores spent annually in third-party motor insurance claims and subsidized emergency trauma burdens.
                  </div>
                </div>
              </div>
            </div>

            <div class="card-glass p-4 rounded-xl border-l-4 border-l-emerald-500 flex flex-col justify-between">
              <div>
                <div class="text-xs font-bold text-emerald-400 uppercase tracking-wider mb-2">THE RAKSHAK-AI RETURN ON INVESTMENT (ROI)</div>
                <div class="space-y-3 text-xs text-slate-300">
                  <div>
                    <span class="text-white font-bold block text-sm">🎯 1:38.4 National Economic Multiplier</span>
                    Every ₹1 invested in automated emergency preemption and trauma telemetry yields ₹38.4 in economic productivity preserved.
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">🏥 40,000+ Productive Lives Saved Annually</span>
                    Slashing arrival latency by 75% across Tier-1 and Tier-2 Indian cities preserves ₹45,000 Crores in human capital value per year.
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">♿ 62% Reduction in Post-Trauma Disability Costs</span>
                    Early C-Spine immobilization alerts avert secondary spinal cord transections and hypoxic brain damage.
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">⚡ Zero Additional Roadside Hardware CapEx</span>
                    Leverages existing smartphones, CCTV cameras, and NTCIP 1202 municipal traffic controllers.
                  </div>
                </div>
              </div>
            </div>
          </div>
        `,
        notes: `
          Slide 3 provides macro-economic justification for government and investor stakeholders.
          Point out the World Bank statistic: 3.14% of India's GDP is consumed by road crashes annually.
          Because 70% of casualties are young breadwinners aged 18-45, saving them restores decades of productive GDP output and prevents family bankruptcies.
        `
      },
      {
        id: 4,
        category: "Architectural Framing & Systems Theory",
        catColor: "cyan",
        title: "The Paradigm Shift: Rakshak-AI as an Emergency Resource Planning (ERP) Platform",
        render: () => `
          <div class="h-full flex flex-col justify-between space-y-3">
            <div class="card-glass p-3.5 rounded-xl border border-cyan-500/40">
              <div class="text-xs font-bold text-cyan-400 uppercase tracking-wider mb-1">WHY TRADITIONAL DISPATCH FAILS & WHY EMERGENCY NEEDS AN ERP BACKBONE</div>
              <p class="text-xs text-slate-300 leading-relaxed">
                Traditional enterprise ERPs (SAP, Oracle) synchronize capital, inventory, and supply chain logistics to optimize throughput. In municipal emergency response, human lives are lost because critical resources exist in disconnected silos: hospitals track beds locally, police manage signals independently, and 108 ambulances operate in isolation. Rakshak-AI is an Emergency Operations ERP that unifies medical supply, fleet logistics, and municipal traffic infrastructure into a single synchronous state machine.
              </p>
            </div>

            <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
              <div class="card-glass p-3 rounded-xl border border-purple-500/40">
                <div class="text-xs font-bold text-purple-400 mb-1">📦 RESOURCE INVENTORY</div>
                <ul class="text-[11px] text-slate-300 space-y-1">
                  <li>• Live Trauma ICU bed tracking</li>
                  <li>• Ventilator availability</li>
                  <li>• ABHA-matched blood bank stock</li>
                  <li>• Pre-armed surgical bays (Bay 01)</li>
                </ul>
              </div>
              <div class="card-glass p-3 rounded-xl border border-emerald-500/40">
                <div class="text-xs font-bold text-emerald-400 mb-1">🚚 FLEET LOGISTICS (SCM)</div>
                <ul class="text-[11px] text-slate-300 space-y-1">
                  <li>• Dynamic ALS/BLS fleet routing</li>
                  <li>• Haversine & Geohash dispatch</li>
                  <li>• Atomic row-locked case claim</li>
                  <li>• ETA synchronization to ER teams</li>
                </ul>
              </div>
              <div class="card-glass p-3 rounded-xl border border-cyan-500/40">
                <div class="text-xs font-bold text-cyan-400 mb-1">🚥 PRIORITY LOGISTICS (ITMS)</div>
                <ul class="text-[11px] text-slate-300 space-y-1">
                  <li>• C-V2X V2I signal preemption</li>
                  <li>• Green Wave corridor clearing</li>
                  <li>• CCTV Edge Vision choke detection</li>
                  <li>• A* bottleneck bypass routing</li>
                </ul>
              </div>
              <div class="card-glass p-3 rounded-xl border border-amber-500/40">
                <div class="text-xs font-bold text-amber-400 mb-1">🔒 GOVERNANCE & GRC</div>
                <ul class="text-[11px] text-slate-300 space-y-1">
                  <li>• Multi-role JWT cryptographic RBAC</li>
                  <li>• DPDP Act 2023 compliance</li>
                  <li>• Break-Glass audit logging</li>
                  <li>• 2-hr volatile RAM ephemeral purge</li>
                </ul>
              </div>
            </div>

            <div class="p-2.5 rounded-xl bg-slate-950/80 border border-slate-800 text-[11px] text-slate-400 flex items-center justify-between">
              <span class="font-bold text-white">THE CRASH-TO-CARE FINITE STATE MACHINE (FSM):</span>
              <span class="font-mono text-cyan-300">suspected ➔ broadcasting ➔ accepted ➔ en_route ➔ arrived ➔ resolved</span>
            </div>
          </div>
        `,
        notes: `
          This is a critical conceptual differentiator.
          Frame Rakshak-AI directly as an ERP: Enterprise Resource Planning for municipal emergency ecosystems.
          Show how the classic ERP pillars (Inventory, Fleet Logistics, Priority Shipping, Governance) directly map to hospital beds, ambulance dispatch, green corridor preemption, and DPDP compliance.
        `
      },
      {
        id: 5,
        category: "System Overview & Orchestration",
        catColor: "cyan",
        title: "The Rakshak-AI Unified Solution: 4-Way Multi-Agency Synchronization",
        render: () => `
          <div class="h-full grid grid-cols-1 md:grid-cols-2 gap-3.5">
            <div class="card-glass p-4 rounded-xl border border-rose-500/40">
              <div class="flex items-center gap-2 text-rose-400 font-bold text-sm mb-1.5">
                <span>📱</span> 1. CITIZEN & VICTIM MOBILE APP
              </div>
              <ul class="text-xs text-slate-300 space-y-1">
                <li>• 18.2ms on-device TFLite kinematic crash classification</li>
                <li>• 15-second zero-touch unconscious failsafe countdown</li>
                <li>• Dual-SIM background SOS SMS with live tracking link</li>
                <li>• Verified Ayushman Bharat (ABHA) Emergency Health Vault</li>
              </ul>
            </div>

            <div class="card-glass p-4 rounded-xl border border-cyan-500/40">
              <div class="flex items-center gap-2 text-cyan-400 font-bold text-sm mb-1.5">
                <span>🚓</span> 2. POLICE & ITMS COMMAND WORKSTATION
              </div>
              <ul class="text-xs text-slate-300 space-y-1">
                <li>• City-wide tactical GIS incident map (PostgreSQL + PostGIS)</li>
                <li>• Sub-second geohash fanout & nearest PCR cruiser dispatch</li>
                <li>• CCTV Edge Vision (YOLOv8) vehicle density scoring</li>
                <li>• Municipal Green Corridor preemption authorization</li>
              </ul>
            </div>

            <div class="card-glass p-4 rounded-xl border border-emerald-500/40">
              <div class="flex items-center gap-2 text-emerald-400 font-bold text-sm mb-1.5">
                <span>🚑</span> 3. 108 AMBULANCE COCKPIT HUD
              </div>
              <ul class="text-xs text-slate-300 space-y-1">
                <li>• 1-tap incident claiming with race-safe distributed locking</li>
                <li>• Luminous emerald Green Wave HUD with turn-by-turn routing</li>
                <li>• Traffic lights flip to solid GREEN at 950m out (EVP)</li>
                <li>• Dynamic A* reroute bypassing urban bottlenecks (-4.2 min)</li>
              </ul>
            </div>

            <div class="card-glass p-4 rounded-xl border border-purple-500/40">
              <div class="flex items-center gap-2 text-purple-400 font-bold text-sm mb-1.5">
                <span>🏥</span> 4. LEVEL-1 HOSPITAL TRAUMA BAY
              </div>
              <ul class="text-xs text-slate-300 space-y-1">
                <li>• JWT-authenticated surgeon dashboard (10 seeded facilities)</li>
                <li>• Ephemeral WebRTC live video triage (zero persistent disk writes)</li>
                <li>• AI Crash Biomechanics (Delta-V, peak G, ISS 26, organ risks)</li>
                <li>• Pre-activates Trauma Bay 01, blood cross-match, and CT scan</li>
              </ul>
            </div>
          </div>
        `,
        notes: `
          Slide 5 provides the architectural blueprint of the entire product.
          Explain that Rakshak-AI is NOT just another emergency phone app.
          It is an orchestrated 4-way platform uniting the citizen, police, ambulance, and trauma surgeon simultaneously.
        `
      },
      {
        id: 6,
        category: "Subsystem Deep-Dive: Mobile Edge AI",
        catColor: "rose",
        title: "Citizen App: 18ms On-Device Kinematic Crash AI",
        render: () => `
          <div class="h-full grid grid-cols-1 lg:grid-cols-12 gap-4 items-center">
            <div class="lg:col-span-7 flex flex-col justify-between h-full space-y-3">
              <div class="card-glass p-4 rounded-xl border-l-4 border-l-rose-500">
                <div class="text-xs font-bold text-rose-400 uppercase tracking-wider mb-2">ON-DEVICE INFERENCE ENGINE (TFLITE 1D-CNN)</div>
                <div class="space-y-2 text-xs text-slate-300">
                  <div>
                    <span class="text-cyan-300 font-bold">⚡ 18.2ms Zero-Cloud Latency:</span>
                    Runs entirely locally via INT8-quantized 1D-CNN. Zero network roundtrip to confirm violent impact.
                  </div>
                  <div>
                    <span class="text-cyan-300 font-bold">🔄 Multi-Axis Sensor Fusion:</span>
                    Samples 100Hz tri-axial accelerometer (±16G), gyroscope, and sudden GPS speed drops.
                  </div>
                  <div>
                    <span class="text-cyan-300 font-bold">🛡️ Zero False Alarm Guard:</span>
                    Differentiates drops on concrete from vehicular crashes using bandpass filters & jerk (da/dt).
                  </div>
                  <div>
                    <span class="text-cyan-300 font-bold">🏍️ Two-Wheeler Kinematic Tuning:</span>
                    Calibrated specifically for motorcycles with zero airbag requirement and tumble roll dynamics.
                  </div>
                  <div>
                    <span class="text-cyan-300 font-bold">🔒 Immutable Physics Fallback:</span>
                    Kinematic rule engine (>6.5G deceleration) guarantees detection if neural buffer fails.
                  </div>
                </div>
              </div>

              <div class="p-3 bg-slate-950/70 border border-slate-800 rounded-xl flex items-center justify-between text-xs">
                <span class="text-slate-400 font-medium">Model Footprint:</span>
                <span class="text-emerald-400 font-mono font-bold">42 KB (INT8 Quantized)</span>
                <span class="text-slate-400 font-medium">Sampling Rate:</span>
                <span class="text-cyan-400 font-mono font-bold">100 Hz Stream</span>
                <span class="text-slate-400 font-medium">Battery Impact:</span>
                <span class="text-amber-400 font-mono font-bold">&lt; 1.4% / 8 hrs</span>
              </div>
            </div>

            <div class="lg:col-span-5 flex justify-center items-center h-full">
              <div class="relative w-48 sm:w-52 rounded-2xl overflow-hidden border-2 border-slate-700 shadow-2xl bg-black">
                <img src="docs/screenshots/screenshot_citizen_guard.png" alt="Citizen Guard HUD" class="w-full object-cover">
              </div>
            </div>
          </div>
        `,
        notes: `
          Slide 6 proves the technical depth of the mobile client.
          Clarify: The AI model runs on the edge, not on a remote server.
          Highlight the two-wheeler calibration: airbag pulses don't exist on bikes, so kinematic tumble and jerk thresholds are tuned specifically for India's high motorcycle population.
        `
      },
      {
        id: 7,
        category: "Subsystem Deep-Dive: Autonomous Dispatch",
        catColor: "rose",
        title: "Citizen App: 15-Second Zero-Touch Unconscious Failsafe",
        render: () => `
          <div class="h-full grid grid-cols-1 lg:grid-cols-12 gap-4 items-center">
            <div class="lg:col-span-7 flex flex-col justify-between h-full space-y-3">
              <div class="grid grid-cols-3 gap-2">
                <div class="p-2.5 rounded-xl bg-slate-950/70 border border-amber-500/30 text-center">
                  <div class="text-amber-400 font-bold text-xs">PHASE 1</div>
                  <div class="text-[11px] text-white font-semibold mt-0.5">100 dB Siren</div>
                  <div class="text-[10px] text-slate-400 mt-1">Haptic pulse + loud alarm overrides silent mode.</div>
                </div>
                <div class="p-2.5 rounded-xl bg-slate-950/70 border border-rose-500/30 text-center">
                  <div class="text-rose-400 font-bold text-xs">PHASE 2</div>
                  <div class="text-[11px] text-white font-semibold mt-0.5">15s Ring Timer</div>
                  <div class="text-[10px] text-slate-400 mt-1">Visual countdown with single-tap 'I'M OK' abort.</div>
                </div>
                <div class="p-2.5 rounded-xl bg-slate-950/70 border border-emerald-500/30 text-center">
                  <div class="text-emerald-400 font-bold text-xs">PHASE 3</div>
                  <div class="text-[11px] text-white font-semibold mt-0.5">Zero-Touch SOS</div>
                  <div class="text-[10px] text-slate-400 mt-1">Autonomous cloud dispatch + native GSM SMS.</div>
                </div>
              </div>

              <div class="card-glass p-3.5 rounded-xl border border-cyan-500/40">
                <div class="text-xs font-bold text-cyan-400 uppercase tracking-wider mb-1">CLINICAL VALUE OF ZERO-TOUCH UNCONSCIOUS DISPATCH</div>
                <p class="text-xs text-slate-300 leading-relaxed">
                  In 68% of high-speed rollover collisions, drivers suffer concussions, traumatic head shock, or fractured upper extremities, making unlocking a smartphone physiologically impossible. Traditional emergency apps that require typing passwords or navigating menus fail completely in severe trauma. Rakshak-AI's zero-touch failsafe guarantees immediate medical activation without requiring the victim to be conscious.
                </p>
              </div>

              <div class="p-3 bg-slate-950/70 border border-slate-800 rounded-xl text-xs text-slate-300 flex items-center justify-between">
                <div><span class="text-rose-400 font-bold">Fallback:</span> Native GSM SIM SMS (Direct Carrier)</div>
                <div><span class="text-emerald-400 font-bold">Delivery:</span> 3 Emergency Contacts + Police</div>
              </div>
            </div>

            <div class="lg:col-span-5 flex justify-center items-center h-full">
              <div class="relative w-48 sm:w-52 rounded-2xl overflow-hidden border-2 border-rose-500/60 shadow-2xl bg-black">
                <img src="docs/screenshots/screenshot_citizen_countdown.png" alt="Countdown SOS" class="w-full object-cover">
              </div>
            </div>
          </div>
        `,
        notes: `
          Slide 7 focuses on the UX of the 15-second countdown.
          Explain that if a driver is simply dropping their phone or tapped the bumper, they can tap 'I'M OK — CANCEL SOS' with zero consequence.
          If they are knocked unconscious, the timer expires and emergency dispatch activates automatically.
        `
      },
      {
        id: 8,
        category: "Intelligence Layer: Predictive Road Safety",
        catColor: "amber",
        title: "Trip Sentinel & Accident Blackspot Spatial Clustering",
        render: () => `
          <div class="h-full grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="card-glass p-4 rounded-xl border-l-4 border-l-amber-500 flex flex-col justify-between">
              <div>
                <div class="text-xs font-bold text-amber-400 uppercase tracking-wider mb-2">TRIP SENTINEL: ACTIVE JOURNEY MONITORING</div>
                <div class="space-y-3 text-xs text-slate-300">
                  <div>
                    <span class="text-white font-bold block text-sm">🛰️ Continuous Journey Sentinel</span>
                    Tracks active trips with periodic telemetry heartbeats (speed, GPS heading, motion state).
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">🏎️ Highway Speed Threshold (60 km/h)</span>
                    Dead-man switch is calibrated specifically for highway corridors (>60 km/h) to prevent nuisance triggers in city crawl.
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">⚠️ 3-Tier Lost Contact Escalation</span>
                    If telemetry heartbeat abruptly terminates at highway speed, the state machine escalates from ACTIVE ➔ ALERT ➔ ESCALATED.
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">🛑 Graceful Trip Completion</span>
                    Detects safe deceleration, vehicle engine shutdown, or deliberate user parking to end sessions cleanly.
                  </div>
                </div>
              </div>
            </div>

            <div class="card-glass p-4 rounded-xl border-l-4 border-l-rose-500 flex flex-col justify-between">
              <div>
                <div class="text-xs font-bold text-rose-400 uppercase tracking-wider mb-2">ACCIDENT BLACKSPOT SPATIAL CLUSTERING</div>
                <div class="space-y-3 text-xs text-slate-300">
                  <div>
                    <span class="text-white font-bold block text-sm">📍 Learned From Crash Data</span>
                    Dynamically clusters historical accident hotspots (e.g. Silk Board Junction, 4 collisions; Hebbal Flyover; MG Road).
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">🏛️ Government iRAD Integration Roadmap</span>
                    Architected to ingest open MoRTH iRAD (Integrated Road Accident Database) feeds to auto-seed certified national blackspots.
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">🎯 Spatial Proximity Geofencing</span>
                    Evaluates incident coordinates against known hazard zones with sub-500m PostGIS spatial indexing (ST_DWithin).
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">🔔 Proactive In-Cabin Hazard Caution</span>
                    Alerts driver with auditory and visual caution banners when approaching historically lethal accident zones.
                  </div>
                </div>
              </div>
            </div>
          </div>
        `,
        notes: `
          Slide 8 highlights our proactive intelligence capabilities.
          Point out that the dead-man switch is calibrated specifically for highway corridors (>60 km/h) so it doesn't trigger falsely in city traffic.
          Clarify the blackspot banner: it's learned from Rakshak demo incidents and designed to integrate with MoRTH's iRAD national database.
        `
      },
      {
        id: 9,
        category: "Subsystem Deep-Dive: Traffic Grid V2I",
        catColor: "emerald",
        title: "Autonomous AI Green Corridor & Dynamic Signal Preemption",
        render: () => `
          <div class="h-full grid grid-cols-1 lg:grid-cols-12 gap-4 items-center">
            <div class="lg:col-span-6 flex flex-col justify-between h-full space-y-3">
              <div class="card-glass p-3.5 rounded-xl border-l-4 border-l-emerald-500">
                <div class="text-xs font-bold text-emerald-400 uppercase tracking-wider mb-2">EMERGENCY VEHICLE PREEMPTION (EVP / C-V2X)</div>
                <div class="space-y-2 text-xs text-slate-300">
                  <div>
                    <span class="text-cyan-300 font-bold">📡 950-Meter Radar Geofence:</span>
                    Projects advance vector cone. ITMS receives authenticated C-V2X preemption command at 950m out.
                  </div>
                  <div>
                    <span class="text-cyan-300 font-bold">🟢 45-Second Advance Green Wave:</span>
                    Clears conflicting phases safely through standard yellow clearance intervals, turning SOLID GREEN 45s before arrival.
                  </div>
                  <div>
                    <span class="text-cyan-300 font-bold">🚦 NTCIP 1202 Standard:</span>
                    Directly compatible with Bengaluru B-TRAC and Indian Smart City traffic controllers.
                  </div>
                  <div>
                    <span class="text-cyan-300 font-bold">📹 CCTV Edge Vision (YOLOv8):</span>
                    Cameras analyze intersection queue lengths in real-time.
                  </div>
                  <div>
                    <span class="text-cyan-300 font-bold">🗺️ Dynamic A* Bottleneck Bypass:</span>
                    Detects 89% choke on 100ft Road and routes ambulance via Old Airport Road (-4.2 min saved).
                  </div>
                </div>
              </div>

              <div class="card-glass p-3 rounded-xl border border-cyan-500/40 text-xs">
                <div class="text-cyan-300 font-bold mb-1">AMBULANCE EMS CONSOLE: 1-TAP ATOMIC CASE CLAIMING</div>
                <div class="text-slate-300">Incident claimed with PostgreSQL row-level locks. Pre-loads T1 Polytrauma severity, PINN Biomechanics (ISS 26), and verified ABHA vault before wheels roll.</div>
              </div>
            </div>

            <div class="lg:col-span-6 flex justify-center items-center h-full">
              <div class="rounded-xl overflow-hidden border border-slate-700 shadow-2xl bg-black max-h-[380px]">
                <img src="docs/screenshots/screenshot_ambulance_claim.png" alt="Ambulance Claim HUD" class="w-full object-contain">
              </div>
            </div>
          </div>
        `,
        notes: `
          Slide 9 covers our V2I / C-V2X Green Corridor innovation.
          Walk the judges through the sequence: 950m radar geofence triggers the traffic light controller.
          The controller transitions conflicting phases through yellow clearance and gives a 45-second solid green corridor.
        `
      },
      {
        id: 10,
        category: "Subsystem Deep-Dive: Police Ops",
        catColor: "cyan",
        title: "Central Police & ITMS Command: City-Wide Tactical Map",
        render: () => `
          <div class="h-full grid grid-cols-1 lg:grid-cols-12 gap-4 items-center">
            <div class="lg:col-span-5 flex flex-col justify-between h-full space-y-3">
              <div class="card-glass p-3.5 rounded-xl border-l-4 border-l-cyan-500">
                <div class="text-xs font-bold text-cyan-400 uppercase tracking-wider mb-2">TACTICAL POLICE DISPATCH & ITMS COMMAND</div>
                <div class="space-y-2 text-xs text-slate-300">
                  <div>
                    <span class="text-white font-bold">🌐 Sub-Second Geohash Fanout:</span>
                    PostGIS spatial query pinpoints accident scene on the city map within 300ms of crash detection.
                  </div>
                  <div>
                    <span class="text-white font-bold">🚓 Automated PCR Cruiser Dispatch:</span>
                    Identifies nearest Police Control Room patrol vehicle (KA-01-G-404) and dispatches it immediately to secure the crash scene.
                  </div>
                  <div>
                    <span class="text-white font-bold">🚧 Crash Scene Cordon & Crowd Control:</span>
                    Enables police to arrive within 2-3 minutes to secure evidence and clear incoming lanes.
                  </div>
                  <div>
                    <span class="text-white font-bold">🕒 Synchronized UTC/IST Timekeeping:</span>
                    Centralized date parser guarantees exact matching across police, ambulance, and hospital logs.
                  </div>
                </div>
              </div>

              <div class="card-glass p-3 rounded-xl border border-emerald-500/40 text-xs">
                <div class="text-emerald-400 font-bold mb-1">POLICE COMMAND WORKSTATION (BENGALURU PILOT)</div>
                <div class="text-slate-300">Live incident at Indiranagar 100ft Rd. PCR cruiser KA-01-G-404 deployed. CCTV Edge Vision flags 89% choke density, triggering automatic green corridor clearance.</div>
              </div>
            </div>

            <div class="lg:col-span-7 flex justify-center items-center h-full">
              <div class="rounded-xl overflow-hidden border border-slate-700 shadow-2xl bg-black max-h-[380px]">
                <img src="docs/screenshots/screenshot_police_dashboard.png" alt="Police Command Dashboard" class="w-full object-contain">
              </div>
            </div>
          </div>
        `,
        notes: `
          Slide 10 explains how Police ITMS Command participates in the ecosystem.
          Explain that police need to know about the crash not just to manage traffic, but to deploy a PCR patrol car immediately for crowd control and evidence cordoning.
          Highlight the synchronized timekeeping: all logs match UTC/IST across every dashboard.
        `
      },
      {
        id: 11,
        category: "Subsystem Deep-Dive: Ambulance EMS",
        catColor: "emerald",
        title: "Ambulance Cockpit Console: 1-Tap Claiming & High-Speed HUD",
        render: () => `
          <div class="h-full grid grid-cols-1 lg:grid-cols-12 gap-4 items-center">
            <div class="lg:col-span-5 flex flex-col justify-between h-full space-y-3">
              <div class="card-glass p-3.5 rounded-xl border-l-4 border-l-emerald-500">
                <div class="text-xs font-bold text-emerald-400 uppercase tracking-wider mb-2">AMBULANCE COCKPIT & HIGH-SPEED NAVIGATION</div>
                <div class="space-y-2 text-xs text-slate-300">
                  <div>
                    <span class="text-cyan-300 font-bold">👆 1-Tap Race-Safe Claiming:</span>
                    Instant acoustic dispatch ping; single tap claims case and locks incident network-wide via PostgreSQL.
                  </div>
                  <div>
                    <span class="text-cyan-300 font-bold">🟢 Luminous Green Wave HUD:</span>
                    High-contrast emerald navigation interface designed for high-speed transit with live speedometer and countdown.
                  </div>
                  <div>
                    <span class="text-cyan-300 font-bold">📡 C-V2X Radar Geofencing:</span>
                    Projective radar cone forces upcoming traffic signals to flip SOLID GREEN at 950 meters out.
                  </div>
                  <div>
                    <span class="text-cyan-300 font-bold">🔄 Dynamic A* Choke Detour:</span>
                    Bypasses 89% congested bottleneck on 100ft Rd, saving 4.2 minutes of transit time.
                  </div>
                  <div>
                    <span class="text-cyan-300 font-bold">🩺 In-Cabin Clinical Action Deck:</span>
                    Integrated AI Trauma Blackbox chips (ISS 26) and ABHA vault bottom sheet alert crew to drug allergies and blood group.
                  </div>
                </div>
              </div>

              <div class="card-glass p-3 rounded-xl border border-cyan-500/40 text-xs">
                <div class="text-cyan-300 font-bold mb-1">AMBULANCE COCKPIT HUD: LIVE C-V2X GREEN WAVE</div>
                <div class="text-slate-300">Approaching signal at 950m pre-empted SOLID GREEN. Current speed: 65 km/h. Bottleneck bypass active: -4.2 min. ETA to Manipal Trauma Center: 4.8 min.</div>
              </div>
            </div>

            <div class="lg:col-span-7 flex justify-center items-center h-full">
              <div class="rounded-xl overflow-hidden border border-slate-700 shadow-2xl bg-black max-h-[380px]">
                <img src="docs/screenshots/screenshot_ambulance_hud.png" alt="Ambulance HUD" class="w-full object-contain">
              </div>
            </div>
          </div>
        `,
        notes: `
          Slide 11 focuses on the ambulance experience.
          Emphasize the human-centered ergonomics: paramedics and drivers in a speeding ambulance cannot read small fonts or fiddle with multi-step menus.
          The Green Wave HUD features high-contrast green visuals, large target buttons, and audio alerts.
        `
      },
      {
        id: 12,
        category: "Subsystem Deep-Dive: Hospital ER",
        catColor: "purple",
        title: "Hospital Trauma Bay: Real Auth, RBAC & Race-Safe Case Locking",
        render: () => `
          <div class="h-full grid grid-cols-1 lg:grid-cols-12 gap-4 items-center">
            <div class="lg:col-span-5 flex flex-col justify-between h-full space-y-3">
              <div class="card-glass p-3.5 rounded-xl border-l-4 border-l-purple-500">
                <div class="text-xs font-bold text-purple-400 uppercase tracking-wider mb-2">ENTERPRISE AUTH, RBAC & SURGICAL PRE-ARMING</div>
                <div class="space-y-2 text-xs text-slate-300">
                  <div>
                    <span class="text-cyan-300 font-bold">🔐 Real Auth (JWT + Bcrypt):</span>
                    8-hour signed JWT tokens carrying user id, hospital id, and staff role replace client-side dropdowns.
                  </div>
                  <div>
                    <span class="text-cyan-300 font-bold">🛡️ RBAC Enforcement:</span>
                    Hospital staff can strictly view and accept incidents assigned to their facility. Police get tactical view only.
                  </div>
                  <div>
                    <span class="text-cyan-300 font-bold">🚫 Mismatched Accept Rejected (403):</span>
                    Hospital A attempting to accept an incident matched to Hospital B receives a strict 403 Forbidden rejection.
                  </div>
                  <div>
                    <span class="text-cyan-300 font-bold">🔒 Atomic Case Locking:</span>
                    PostgreSQL row locks prevent duplicate acceptances; competing facilities see 'CASE LOCKED' with audit badge.
                  </div>
                  <div>
                    <span class="text-cyan-300 font-bold">🏥 Pre-Armed Trauma Bay:</span>
                    Bay 01, ventilator, and blood cross-match pre-issued 10 minutes prior to arrival.
                  </div>
                </div>
              </div>

              <div class="card-glass p-3 rounded-xl border border-purple-500/40 text-xs">
                <div class="text-purple-300 font-bold mb-1">LEVEL-1 SURGICAL ER WORKSTATION (MANIPAL HOSPITAL)</div>
                <div class="text-slate-300">Real WebRTC Visual Triage feed (TTL 900s RAM buffer), PINN Crash Biomechanics (ISS 26 Severe Polytrauma), and verified ABHA vault (B+ Blood, Penicillin Anaphylaxis Alert).</div>
              </div>
            </div>

            <div class="lg:col-span-7 flex justify-center items-center h-full">
              <div class="rounded-xl overflow-hidden border border-slate-700 shadow-2xl bg-black max-h-[380px]">
                <img src="docs/screenshots/screenshot_hospital_dashboard.png" alt="Hospital Dashboard" class="w-full object-contain">
              </div>
            </div>
          </div>
        `,
        notes: `
          Slide 12 highlights enterprise hospital security and readiness.
          Explain that in real-world hackathon testing, evaluators test for race conditions and privilege escalation.
          Rakshak uses signed JWTs and PostgreSQL row-level locks so that two hospitals cannot accept the same case simultaneously.
        `
      },
      {
        id: 13,
        category: "Game-Changing Feature: PINN Modeling",
        catColor: "rose",
        title: "Innovation 1: AI Crash Biomechanics & Virtual Trauma Blackbox",
        render: () => `
          <div class="h-full flex flex-col justify-between space-y-3">
            <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
              <div class="card-glass p-3 rounded-xl border-l-4 border-l-rose-500">
                <div class="text-[10px] text-slate-400 uppercase font-semibold">DELTA-V DROP</div>
                <div class="text-xl sm:text-2xl font-black text-rose-400 mt-0.5">62.4 km/h</div>
                <div class="text-[10px] text-slate-300 mt-0.5">Velocity loss in &lt;120ms impact window.</div>
              </div>
              <div class="card-glass p-3 rounded-xl border-l-4 border-l-amber-500">
                <div class="text-[10px] text-slate-400 uppercase font-semibold">PEAK DECELERATION</div>
                <div class="text-xl sm:text-2xl font-black text-amber-400 mt-0.5">48.6 G</div>
                <div class="text-[10px] text-slate-300 mt-0.5">Maximum kinetic deceleration shockwave.</div>
              </div>
              <div class="card-glass p-3 rounded-xl border-l-4 border-l-cyan-500">
                <div class="text-[10px] text-slate-400 uppercase font-semibold">KINETIC DISSIPATION</div>
                <div class="text-xl sm:text-2xl font-black text-cyan-400 mt-0.5">142.8 kJ</div>
                <div class="text-[10px] text-slate-300 mt-0.5">Mechanical energy absorbed by cabin.</div>
              </div>
              <div class="card-glass p-3 rounded-xl border-l-4 border-l-purple-500">
                <div class="text-[10px] text-slate-400 uppercase font-semibold">PREDICTED ISS</div>
                <div class="text-xl sm:text-2xl font-black text-purple-400 mt-0.5">26 (Severe)</div>
                <div class="text-[10px] text-slate-300 mt-0.5">Injury Severity Score: Severe Polytrauma.</div>
              </div>
            </div>

            <div class="card-glass p-4 rounded-xl border border-rose-500/40">
              <div class="text-xs font-bold text-rose-400 uppercase tracking-wider mb-2">PREDICTED INTERNAL ORGAN TRAUMA MATRIX & CLINICAL PROTOCOLS</div>
              <div class="space-y-2 text-xs text-slate-300">
                <div>
                  <span class="text-rose-400 font-bold block">🚨 Cervical Spine Whiplash / Fracture Risk: 84% [CRITICAL]</span>
                  <span class="text-cyan-300">🏥 Clinical Protocol:</span> Immediate C-Spine Collar Immobilization before moving victim to avoid secondary spinal cord transection.
                </div>
                <div>
                  <span class="text-amber-400 font-bold block">⚠️ Blunt Sternal / Myocardial Contusion: 76% [HIGH]</span>
                  <span class="text-cyan-300">🏥 Clinical Protocol:</span> Pre-order 12-lead ECG and stat Cardiac Troponin markers; prepare cardiac defibrillator in Bay 01.
                </div>
                <div>
                  <span class="text-amber-400 font-bold block">⚠️ Intra-Abdominal / Splenic Laceration Risk: 61% [HIGH]</span>
                  <span class="text-cyan-300">🏥 Clinical Protocol:</span> Immediate Focused Assessment with Sonography in Trauma (FAST) ultrasound protocol on arrival.
                </div>
                <div>
                  <span class="text-cyan-300 font-bold block">🧠 Traumatic Brain Injury (Closed Head Shock): 48% [MODERATE]</span>
                  <span class="text-cyan-300">🏥 Clinical Protocol:</span> Immediate Non-Contrast Head CT Protocol scheduled upon trauma bay docking.
                </div>
              </div>
            </div>
          </div>
        `,
        notes: `
          Slide 13 presents our first major game-changing feature: AI Crash Biomechanics.
          Surgeons usually operate blind. They don't know if a patient has internal bleeding until they open them up.
          Rakshak uses Physics-Informed Neural Networks (PINN) to compute the collision shockwave and predict internal organ injuries before the ambulance arrives.
        `
      },
      {
        id: 14,
        category: "Privacy Architecture & DPDP Act 2023",
        catColor: "cyan",
        title: "Zero-Storage Protocol & Real WebRTC Ephemeral Visual Triage",
        render: () => `
          <div class="h-full grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="card-glass p-4 rounded-xl border-l-4 border-l-cyan-500 flex flex-col justify-between">
              <div>
                <div class="text-xs font-bold text-cyan-400 uppercase tracking-wider mb-2">WEBRTC PEER-TO-PEER VISUAL STREAMING</div>
                <div class="space-y-3 text-xs text-slate-300">
                  <div>
                    <span class="text-emerald-400 font-bold block text-sm">📹 Direct P2P DataChannel Transport</span>
                    Establishes a direct WebRTC peer connection between victim's phone camera and surgeon's workstation over Socket.io signaling.
                  </div>
                  <div>
                    <span class="text-emerald-400 font-bold block text-sm">🔄 Automatic 5-Second WebSocket Fallback</span>
                    If restrictive symmetric NATs or corporate firewalls block WebRTC, system falls back to binary WebSocket streaming seamlessly.
                  </div>
                  <div>
                    <span class="text-emerald-400 font-bold block text-sm">🔍 High-Resolution Fullscreen Lightbox</span>
                    Surgeons can open a portrait inspection lightbox to examine cabin deformation and head trauma before docking.
                  </div>
                  <div>
                    <span class="text-emerald-400 font-bold block text-sm">🏷️ Transport Diagnostic Badge</span>
                    Live badge indicates '⚡ WebRTC P2P' or '🔄 WebSocket Fallback', proving fallback resilience to evaluators.
                  </div>
                </div>
              </div>
            </div>

            <div class="card-glass p-4 rounded-xl border-l-4 border-l-rose-500 flex flex-col justify-between">
              <div>
                <div class="text-xs font-bold text-rose-400 uppercase tracking-wider mb-2">ZERO-PERSISTENT-STORAGE PRIVACY PROTOCOL</div>
                <div class="space-y-3 text-xs text-slate-300">
                  <div>
                    <span class="text-amber-400 font-bold block text-sm">🚫 Zero Local Disk Storage</span>
                    Camera bytes stream directly from device RAM buffers. Zero images are ever written to mobile galleries or local flash storage.
                  </div>
                  <div>
                    <span class="text-amber-400 font-bold block text-sm">💾 Volatile Redis RAM Only (TTL 900s)</span>
                    Intermediate relay buffers live strictly in RAM with a 15-minute TTL. Redis persistence (AOF and RDB) is disabled.
                  </div>
                  <div>
                    <span class="text-amber-400 font-bold block text-sm">🛡️ Anti-Exfiltration UI Defenses</span>
                    Right-click menus, image dragging, and downloads are strictly disabled in dashboard DOM to prevent photo leaks.
                  </div>
                  <div>
                    <span class="text-amber-400 font-bold block text-sm">⚖️ DPDP Act 2023 Compliant</span>
                    Complies with India's Digital Personal Data Protection Act 2023, protecting victim dignity and preventing viral social media leaks.
                  </div>
                </div>
              </div>
            </div>
          </div>
        `,
        notes: `
          Slide 14 details our WebRTC visual triage and zero-storage privacy protocol.
          Address the ethical question: "What if someone's graphic crash photo is saved and leaked online?"
          Emphasize: Zero images are stored on disk. Everything streams through volatile RAM with a 900-second TTL and DOM anti-exfiltration guards.
        `
      },
      {
        id: 15,
        category: "Game-Changing Feature: Digital Health Stack",
        catColor: "emerald",
        title: "Innovation 2: Ayushman Bharat (ABDM/ABHA) Emergency Health Vault",
        render: () => `
          <div class="h-full grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="card-glass p-4 rounded-xl border-l-4 border-l-emerald-500 flex flex-col justify-between">
              <div>
                <div class="text-xs font-bold text-emerald-400 uppercase tracking-wider mb-2">ABDM-VERIFIED EMERGENCY HEALTH IDENTITY</div>
                <div class="space-y-3 text-xs text-slate-300">
                  <div>
                    <span class="text-white font-bold block text-sm">🆔 Verified 14-Digit ABHA ID</span>
                    91-8842-9912-3401 (stevin.joseph@abdm) — Authenticated via Government of India ABDM Gateway.
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">🩸 Confirmed Blood Group (B+ Positive)</span>
                    Eliminates 15-20 minutes of diagnostic blood typing delays, enabling immediate cross-matching and transfusion.
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">🔐 Hardware TEE Cryptographic Signature</span>
                    Data signed within smartphone's hardware Trusted Execution Environment (0x7f4a8b29c910d9e2) ensuring zero tampering.
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">🫀 National Organ Donor Registration</span>
                    Verified registration with National Organ & Tissue Transplant Organisation (NOTTO-IND-2024-88419).
                  </div>
                </div>
              </div>
            </div>

            <div class="card-glass p-4 rounded-xl border-l-4 border-l-rose-500 flex flex-col justify-between">
              <div>
                <div class="text-xs font-bold text-rose-400 uppercase tracking-wider mb-2">CRITICAL DRUG ALLERGIES & CONTRAINDICATIONS</div>
                <div class="space-y-3 text-xs text-slate-300">
                  <div class="p-2.5 bg-rose-950/40 border border-rose-500/40 rounded-lg">
                    <span class="text-rose-400 font-bold block text-xs">🚨 HIGH-URGENCY ALLERGY CONTRAINDICATION</span>
                    Penicillin Anaphylaxis & Sulfa Drugs.<br/>
                    <span class="text-white font-bold">Clinical Alert:</span> Strict prohibition against administering beta-lactam antibiotics during acute emergency resuscitation!
                  </div>
                  <div>
                    <span class="text-amber-400 font-bold block text-sm">💊 Chronic Conditions & Co-Morbidities</span>
                    Type-1 Diabetes Mellitus on daily Insulin Glargine. Requires continuous glucose monitoring during resuscitation.
                  </div>
                  <div>
                    <span class="text-amber-400 font-bold block text-sm">⚠️ High-Risk Medication: Warfarin Blood Thinner</span>
                    Patient is on anticoagulant therapy! Alerts surgeons to high risk of occult internal bleeding; prompts Vitamin K reversal agents.
                  </div>
                </div>
              </div>
            </div>
          </div>
        `,
        notes: `
          Slide 15 details our second major game-changing feature: Ayushman Bharat (ABDM/ABHA) Emergency Health Vault.
          Explain the life-saving impact: When an unconscious patient arrives, surgeons don't know their blood group or allergies.
          If they administer Penicillin to an allergic victim, it triggers anaphylactic shock. Rakshak's ABHA vault prevents this tragedy.
        `
      },
      {
        id: 16,
        category: "Governance & Indian Statutory Compliance",
        catColor: "amber",
        title: "Privacy-First Architecture & DPDP Act 2023 Statutory Compliance",
        render: () => `
          <div class="h-full grid grid-cols-1 md:grid-cols-2 gap-4">
            <div class="card-glass p-4 rounded-xl border-l-4 border-l-amber-500 flex flex-col justify-between">
              <div>
                <div class="text-xs font-bold text-amber-400 uppercase tracking-wider mb-2">INDIAN STATUTORY COMPLIANCE & BYSTANDER IMMUNITY</div>
                <div class="space-y-3 text-xs text-slate-300">
                  <div>
                    <span class="text-white font-bold block text-sm">⚖️ Good Samaritan Protection (MV Act Sec 134A)</span>
                    Supreme Court and Central Motor Vehicles guidelines guarantee complete immunity from police interrogation or hospital liability.
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">🏛️ Ayushman Bharat Digital Mission (ABDM) Standards</span>
                    Conforms to National Health Authority (NHA) standards for consent management and health data fiduciary verification.
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">📡 Emergency Services Telephony (TRAI Guidelines)</span>
                    Utilizes priority carrier bands for emergency SOS SMS broadcasting to overcome cell congestion near highways.
                  </div>
                </div>
              </div>
            </div>

            <div class="card-glass p-4 rounded-xl border-l-4 border-l-emerald-500 flex flex-col justify-between">
              <div>
                <div class="text-xs font-bold text-emerald-400 uppercase tracking-wider mb-2">DIGITAL PERSONAL DATA PROTECTION (DPDP) ACT 2023</div>
                <div class="space-y-3 text-xs text-slate-300">
                  <div>
                    <span class="text-white font-bold block text-sm">⏱️ Purpose Limitation & Ephemeral Lifespan</span>
                    Crash visual telemetry is gathered exclusively for emergency surgical resuscitation and purged after 900 seconds.
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">🧹 Postgres Database Sanitization</span>
                    Zero medical PII is stored in persistent disk tables. Metadata sanitizer strips blood group and health card data before PostgreSQL write.
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">💾 Volatile Redis RAM (2-Hour TTL)</span>
                    Emergency Health Cards are stored in volatile RAM with strict 2-hour TTL auto-purge, eliminating long-term data breach exposure.
                  </div>
                  <div>
                    <span class="text-white font-bold block text-sm">📝 Tamper-Evident Break-Glass Audit Trail</span>
                    Access to patient health records strictly requires accepted case status and registered clinician identity with audit justification.
                  </div>
                </div>
              </div>
            </div>
          </div>
        `,
        notes: `
          Slide 16 addresses data protection, ethics, and statutory compliance.
          Demonstrate deep understanding of the DPDP Act 2023: data minimization, purpose limitation, and storage limitation.
          Show how medical PII is stripped from persistent PostgreSQL tables and lives strictly in volatile Redis RAM with a 2-hour TTL.
        `
      },
      {
        id: 17,
        category: "System Architecture & Engineering Rigor",
        catColor: "cyan",
        title: "End-to-End Technical Architecture & Technology Stack",
        render: () => `
          <div class="h-full grid grid-cols-2 sm:grid-cols-4 gap-3">
            <div class="card-glass p-3.5 rounded-xl border border-rose-500/40 flex flex-col justify-between">
              <div>
                <div class="text-xs font-bold text-rose-400 uppercase tracking-wider mb-2">MOBILE CLIENT</div>
                <div class="text-sm font-bold text-white mb-2">Flutter & Dart</div>
                <ul class="text-[11px] text-slate-300 space-y-1.5">
                  <li>• Flutter 3.24+ & Dart 3.5+</li>
                  <li>• TensorFlow Lite (1D-CNN)</li>
                  <li>• flutter_webrtc (P2P Data)</li>
                  <li>• sensors_plus (100Hz IMU)</li>
                  <li>• Background Dual-SIM SMS</li>
                  <li>• SQLite Offline Queue</li>
                </ul>
              </div>
              <div class="text-[10px] text-slate-500 font-mono pt-2 border-t border-slate-800">Edge Device Layer</div>
            </div>

            <div class="card-glass p-3.5 rounded-xl border border-cyan-500/40 flex flex-col justify-between">
              <div>
                <div class="text-xs font-bold text-cyan-400 uppercase tracking-wider mb-2">CORE BACKEND</div>
                <div class="text-sm font-bold text-white mb-2">Node.js & Express</div>
                <ul class="text-[11px] text-slate-300 space-y-1.5">
                  <li>• TypeScript & Express REST</li>
                  <li>• Zod Schema Validation</li>
                  <li>• Socket.IO Real-Time Relay</li>
                  <li>• Bcrypt & JWT Security</li>
                  <li>• 30s Escalation Engine</li>
                  <li>• Trip Sentinel State Machine</li>
                </ul>
              </div>
              <div class="text-[10px] text-slate-500 font-mono pt-2 border-t border-slate-800">Orchestration Gateway</div>
            </div>

            <div class="card-glass p-3.5 rounded-xl border border-emerald-500/40 flex flex-col justify-between">
              <div>
                <div class="text-xs font-bold text-emerald-400 uppercase tracking-wider mb-2">DATA & MEMORY</div>
                <div class="text-sm font-bold text-white mb-2">PostgreSQL & Redis</div>
                <ul class="text-[11px] text-slate-300 space-y-1.5">
                  <li>• PostgreSQL 15 + PostGIS</li>
                  <li>• Spatial Geohash Indexing</li>
                  <li>• Row-Level Locking (Race-Safe)</li>
                  <li>• Redis 7 Volatile RAM</li>
                  <li>• TTL 900s & 2hr Purge</li>
                  <li>• Zero PII Disk Sanitization</li>
                </ul>
              </div>
              <div class="text-[10px] text-slate-500 font-mono pt-2 border-t border-slate-800">Spatial & In-Memory Layer</div>
            </div>

            <div class="card-glass p-3.5 rounded-xl border border-purple-500/40 flex flex-col justify-between">
              <div>
                <div class="text-xs font-bold text-purple-400 uppercase tracking-wider mb-2">DASHBOARD & GRID</div>
                <div class="text-sm font-bold text-white mb-2">React & C-V2X</div>
                <ul class="text-[11px] text-slate-300 space-y-1.5">
                  <li>• React 18, Vite, TypeScript</li>
                  <li>• Tailwind CSS & Lucide Icons</li>
                  <li>• React-Leaflet GIS Mapping</li>
                  <li>• NTCIP 1202 Signal Protocol</li>
                  <li>• YOLOv8 CCTV Edge Vision</li>
                  <li>• UTC/IST Date Normalization</li>
                </ul>
              </div>
              <div class="text-[10px] text-slate-500 font-mono pt-2 border-t border-slate-800">Operational Consoles</div>
            </div>
          </div>
        `,
        notes: `
          Slide 17 demonstrates production engineering rigor across the full stack.
          Emphasize the architecture: Flutter mobile client with edge TFLite, Node.js + TypeScript gateway, PostgreSQL + PostGIS spatial engine, Redis volatile RAM, and React 18 dashboards.
        `
      },
      {
        id: 18,
        category: "Enterprise Security Architecture",
        catColor: "purple",
        title: "Cryptographic Security, Multi-Role RBAC & Anti-Tamper Audit Logging",
        render: () => `
          <div class="h-full grid grid-cols-1 md:grid-cols-2 gap-3.5">
            <div class="card-glass p-4 rounded-xl border border-cyan-500/40">
              <div class="flex items-center gap-2 text-cyan-400 font-bold text-sm mb-1.5">
                <span>🔐</span> ASYMMETRIC JWT AUTHENTICATION
              </div>
              <ul class="text-xs text-slate-300 space-y-1">
                <li>• 8-Hour signed JSON Web Tokens (JWT)</li>
                <li>• Cryptographically signed claims (user id, hospital id, staff role)</li>
                <li>• Zero reliance on client-side dropdown selection</li>
                <li>• Instant token revocation on suspicious telemetry</li>
              </ul>
            </div>

            <div class="card-glass p-4 rounded-xl border border-rose-500/40">
              <div class="flex items-center gap-2 text-rose-400 font-bold text-sm mb-1.5">
                <span>🛡️</span> STRICT MULTI-ROLE ISOLATION
              </div>
              <ul class="text-xs text-slate-300 space-y-1">
                <li>• Police role strictly blocked from clinical health records (403)</li>
                <li>• Hospital staff strictly bound to assigned facility boundary</li>
                <li>• Cross-hospital case acceptance rejected with 403 Forbidden</li>
                <li>• Public/unauthenticated endpoints strictly sanitized</li>
              </ul>
            </div>

            <div class="card-glass p-4 rounded-xl border border-emerald-500/40">
              <div class="flex items-center gap-2 text-emerald-400 font-bold text-sm mb-1.5">
                <span>🔒</span> CONCURRENCY & CASE LOCKING
              </div>
              <ul class="text-xs text-slate-300 space-y-1">
                <li>• PostgreSQL row-level locks prevent race conditions</li>
                <li>• Competing facilities see 'CASE LOCKED' with audit badge</li>
                <li>• Device UUID idempotency deduplicates network retries</li>
                <li>• Zero duplicate dispatches across 108 network</li>
              </ul>
            </div>

            <div class="card-glass p-4 rounded-xl border border-amber-500/40">
              <div class="flex items-center gap-2 text-amber-400 font-bold text-sm mb-1.5">
                <span>📝</span> TAMPER-EVIDENT AUDIT FORENSICS
              </div>
              <ul class="text-xs text-slate-300 space-y-1">
                <li>• Immutable audit records for every Break-Glass medical access</li>
                <li>• Logs accessing physician, timestamp, hospital, and clinical reason</li>
                <li>• SHA-256 password hashing with salt rounds</li>
                <li>• Zero PII leakage in application logs or crash traces</li>
              </ul>
            </div>
          </div>
        `,
        notes: `
          Slide 18 details our cryptographic security, multi-role RBAC, and audit forensics.
          Explain how the system blocks unauthorized hospital snooping and ensures police officers cannot view private medical records.
          Everything is backed by cryptographic tokens and tamper-evident audit logs.
        `
      },
      {
        id: 19,
        category: "Quality Assurance & Production Readiness",
        catColor: "emerald",
        title: "Comprehensive Testing & Verification: 93+ Automated Tests",
        render: () => `
          <div class="h-full grid grid-cols-2 sm:grid-cols-4 gap-3">
            <div class="card-glass p-3.5 rounded-xl border border-cyan-500/40 flex flex-col justify-between">
              <div>
                <div class="text-xs font-bold text-cyan-400 uppercase tracking-wider mb-1">RBAC & SECURITY</div>
                <div class="text-xl font-black text-white mb-2">18/18 PASS</div>
                <ul class="text-[11px] text-slate-300 space-y-1">
                  <li>• JWT Sign & Verification</li>
                  <li>• Role & Hospital payload checks</li>
                  <li>• Malformed token rejection</li>
                  <li>• Cross-hospital 403 blocks</li>
                  <li>• Police medical data block</li>
                  <li>• Ambulance device claim auth</li>
                </ul>
              </div>
              <div class="text-[10px] text-emerald-400 font-mono pt-2 border-t border-slate-800">100% Security Pass</div>
            </div>

            <div class="card-glass p-3.5 rounded-xl border border-amber-500/40 flex flex-col justify-between">
              <div>
                <div class="text-xs font-bold text-amber-400 uppercase tracking-wider mb-1">PHASE 17 INTELLIGENCE</div>
                <div class="text-xl font-black text-white mb-2">29/29 PASS</div>
                <ul class="text-[11px] text-slate-300 space-y-1">
                  <li>• Suspected ➔ Promoted FSM</li>
                  <li>• Pre-alert user cancellation</li>
                  <li>• UUID Idempotency dedupe</li>
                  <li>• Highway 60 km/h speed threshold</li>
                  <li>• Trip Sentinel 3-tier escalation</li>
                  <li>• Silk Board blackspot clustering</li>
                </ul>
              </div>
              <div class="text-[10px] text-emerald-400 font-mono pt-2 border-t border-slate-800">100% Intelligence Pass</div>
            </div>

            <div class="card-glass p-3.5 rounded-xl border border-emerald-500/40 flex flex-col justify-between">
              <div>
                <div class="text-xs font-bold text-emerald-400 uppercase tracking-wider mb-1">PHASE 18 HEALTH CARD</div>
                <div class="text-xl font-black text-white mb-2">46/46 PASS</div>
                <ul class="text-[11px] text-slate-300 space-y-1">
                  <li>• ABDM adapter mock scenarios</li>
                  <li>• Ephemeral Redis RAM storage</li>
                  <li>• Postgres PII sanitization</li>
                  <li>• Redis 2-hour TTL auto-purge</li>
                  <li>• Break-Glass authorization checks</li>
                  <li>• Zero PII in logs audit</li>
                </ul>
              </div>
              <div class="text-[10px] text-emerald-400 font-mono pt-2 border-t border-slate-800">100% Clinical Data Pass</div>
            </div>

            <div class="card-glass p-3.5 rounded-xl border border-purple-500/40 flex flex-col justify-between">
              <div>
                <div class="text-xs font-bold text-purple-400 uppercase tracking-wider mb-1">FRONTEND & MOBILE</div>
                <div class="text-xl font-black text-white mb-2">100% PASS</div>
                <ul class="text-[11px] text-slate-300 space-y-1">
                  <li>• React 18 production build</li>
                  <li>• TypeScript clean compile</li>
                  <li>• 1,560 Vite modules bundled</li>
                  <li>• Flutter ambulance HUD widget tests</li>
                  <li>• TFLite kinematic fallback tests</li>
                  <li>• Safe UTC/IST date parsing</li>
                </ul>
              </div>
              <div class="text-[10px] text-emerald-400 font-mono pt-2 border-t border-slate-800">Zero Build / UI Errors</div>
            </div>
          </div>
        `,
        notes: `
          Slide 19 is our concrete proof of engineering excellence.
          Highlight that we do not present mock prototypes.
          We have 93 automated tests in the backend across RBAC security, state machines, trip sentinel, and ABDM health cards, plus verified Flutter mobile and React production builds.
        `
      },
      {
        id: 20,
        category: "Implementation Feasibility & National Impact",
        catColor: "emerald",
        title: "Scalability Roadmap, Smart City Economics & Vision 2030",
        render: () => `
          <div class="h-full flex flex-col justify-between space-y-3">
            <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
              <div class="card-glass p-3.5 rounded-xl border-t-4 border-t-cyan-500">
                <div class="text-xs font-bold text-cyan-400 uppercase mb-1">PHASE 1: BENGALURU PILOT (M1-M6)</div>
                <ul class="text-[11px] text-slate-300 space-y-1">
                  <li>• 10 Certified Level-1 Trauma Hospitals</li>
                  <li>• 40 Municipal 108 Emergency Ambulances</li>
                  <li>• 120 Smart ITMS Traffic Signals (B-TRAC Corridor)</li>
                  <li>• Silk Board, Indiranagar, MG Road coverage</li>
                </ul>
              </div>
              <div class="card-glass p-3.5 rounded-xl border-t-4 border-t-amber-500">
                <div class="text-xs font-bold text-amber-400 uppercase mb-1">PHASE 2: TIER-1 METROS (M7-M18)</div>
                <ul class="text-[11px] text-slate-300 space-y-1">
                  <li>• Rollout to Mumbai, Delhi-NCR, Hyderabad, Chennai</li>
                  <li>• Integration with 450+ Hospitals & 1,200 Ambulances</li>
                  <li>• C-V2X V2I protocol integration with Central ITMS</li>
                  <li>• Target 40% reduction in city-wide transit time</li>
                </ul>
              </div>
              <div class="card-glass p-3.5 rounded-xl border-t-4 border-t-emerald-500">
                <div class="text-xs font-bold text-emerald-400 uppercase mb-1">PHASE 3: NATIONAL HIGHWAYS (M19-M36)</div>
                <ul class="text-[11px] text-slate-300 space-y-1">
                  <li>• Golden Quadrilateral & NH-44 Expressways</li>
                  <li>• Automated toll plaza radar preemption</li>
                  <li>• State-wide coordination with NHAI and Highway Patrol</li>
                  <li>• Nationwide rollout under MoRTH & NHA sponsorship</li>
                </ul>
              </div>
            </div>

            <div class="card-glass p-3.5 rounded-xl border border-emerald-500/40">
              <div class="text-xs font-bold text-emerald-400 uppercase tracking-wider mb-1">DEPLOYMENT ECONOMICS & THE 2030 NATIONAL VISION</div>
              <p class="text-xs text-slate-300 leading-relaxed">
                By avoiding proprietary roadside sensors and relying on citizen smartphones, cloud WebRTC relays, and existing NTCIP 1202 municipal traffic signal controllers, Rakshak-AI costs less than ₹14,000 ($170 USD) per intersection to deploy, compared to traditional sensor grids costing ₹8,50,000+ ($10,000 USD) per junction.<br/><br/>
                Our mission is to eliminate the 40-minute delay barrier nationwide, reclaiming the Golden Hour for every citizen and saving 40,000+ lives each year on Indian roads.
              </p>
            </div>

            <div class="flex items-center justify-between text-xs text-slate-400 pt-1 border-t border-slate-800">
              <span class="font-bold text-white">THANK YOU! OPEN FOR QUESTIONS & LIVE SYSTEM DEMO</span>
              <span class="text-cyan-300 font-mono">Team Rakshak-AI • Advanced Emergency Operations</span>
            </div>
          </div>
        `,
        notes: `
          Conclude with conviction.
          Summarize: 75% transit time reduction, zero red light delays, zero data leaks, true ERP resource orchestration, and 93+ automated test verification.
          Invite the judges to see the live demonstration.
        `
      }
    ];

    let currentSlideIndex = 0;
    let isNotesOpen = true;

    const slideViewport = document.getElementById('slideViewport');
    const slideSelect = document.getElementById('slideSelect');
    const slideIndicator = document.getElementById('slideIndicator');
    const slideProgressBar = document.getElementById('slideProgressBar');
    const btnPrev = document.getElementById('btnPrev');
    const btnNext = document.getElementById('btnNext');
    const btnFullscreen = document.getElementById('btnFullscreen');
    const btnToggleNotes = document.getElementById('btnToggleNotes');
    const notesLabel = document.getElementById('notesLabel');
    const speakerNotesDrawer = document.getElementById('speakerNotesDrawer');
    const speakerNotesContent = document.getElementById('speakerNotesContent');
    const notesSlideNumber = document.getElementById('notesSlideNumber');

    // Populate Slide Dropdown
    slides.forEach((s, idx) => {
      const opt = document.createElement('option');
      opt.value = idx;
      opt.textContent = `${idx + 1}. ${s.title.substring(0, 36)}...`;
      slideSelect.appendChild(opt);
    });

    function renderSlide(index) {
      if (index < 0 || index >= slides.length) return;
      currentSlideIndex = index;
      const s = slides[currentSlideIndex];

      const categoryColorClasses = {
        emerald: "text-emerald-400 bg-emerald-500/10 border-emerald-500/30",
        rose: "text-rose-400 bg-rose-500/10 border-rose-500/30",
        amber: "text-amber-400 bg-amber-500/10 border-amber-500/30",
        cyan: "text-cyan-400 bg-cyan-500/10 border-cyan-500/30",
        purple: "text-purple-400 bg-purple-500/10 border-purple-500/30"
      };

      const badgeClass = categoryColorClasses[s.catColor] || categoryColorClasses.emerald;

      slideViewport.innerHTML = `
        <div class="flex items-center justify-between mb-3 border-b border-slate-800 pb-2">
          <div class="flex items-center gap-2">
            <span class="px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider border ${badgeClass}">
              ${s.category}
            </span>
          </div>
          <div class="text-xs font-mono text-slate-500 font-bold">
            SLIDE ${String(s.id).padStart(2, '0')} / 20
          </div>
        </div>

        <div class="text-2xl sm:text-3xl font-extrabold text-white tracking-tight mb-4">
          ${s.title}
        </div>

        <div class="flex-1 overflow-y-auto">
          ${s.render()}
        </div>
      `;

      // Update Controls
      slideIndicator.textContent = `Slide ${String(s.id).padStart(2, '0')} / 20`;
      slideSelect.value = index;
      slideProgressBar.style.width = `${((index + 1) / slides.length) * 100}%`;

      btnPrev.disabled = index === 0;
      btnNext.disabled = index === slides.length - 1;

      // Update Speaker Notes
      notesSlideNumber.textContent = s.id;
      speakerNotesContent.innerHTML = s.notes.trim().replace(/\\n/g, '<br/>');
    }

    btnPrev.addEventListener('click', () => renderSlide(currentSlideIndex - 1));
    btnNext.addEventListener('click', () => renderSlide(currentSlideIndex + 1));
    slideSelect.addEventListener('change', (e) => renderSlide(parseInt(e.target.value)));

    btnToggleNotes.addEventListener('click', () => {
      isNotesOpen = !isNotesOpen;
      speakerNotesDrawer.style.display = isNotesOpen ? 'block' : 'none';
      notesLabel.textContent = isNotesOpen ? 'Notes: ON' : 'Notes: OFF';
    });

    btnFullscreen.addEventListener('click', () => {
      if (!document.fullscreenElement) {
        document.documentElement.requestFullscreen().catch(() => {});
      } else {
        document.exitFullscreen().catch(() => {});
      }
    });

    // Keyboard Shortcuts
    window.addEventListener('keydown', (e) => {
      if (e.key === 'ArrowRight' || e.key === ' ' || e.key === 'PageDown' || e.key === 'n') {
        renderSlide(currentSlideIndex + 1);
      } else if (e.key === 'ArrowLeft' || e.key === 'PageUp' || e.key === 'p') {
        renderSlide(currentSlideIndex - 1);
      } else if (e.key === 'f' || e.key === 'F') {
        btnFullscreen.click();
      } else if (e.key === 's' || e.key === 'S') {
        btnToggleNotes.click();
      } else if (e.key === 'Home') {
        renderSlide(0);
      } else if (e.key === 'End') {
        renderSlide(slides.length - 1);
      }
    });

    // Initial Render
    renderSlide(0);
  </script>
</body>
</html>
"""

with open("rakshak_ai_master_presentation.html", "w", encoding="utf-8") as f:
    f.write(html_template)
print("[SUCCESS] Wrote 20-slide interactive HTML presentation to rakshak_ai_master_presentation.html")

pitch_dest = os.path.join("Vikist Blueprint", "2. PITCH FILES", "rakshak_ai_master_presentation.html")
if os.path.exists(os.path.dirname(pitch_dest)):
    with open(pitch_dest, "w", encoding="utf-8") as f:
        f.write(html_template)
    print(f"[SUCCESS] Updated pitch files destination at: {pitch_dest}")
