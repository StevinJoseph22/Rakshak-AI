import os
import math
from PIL import Image, ImageDraw, ImageFont

OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "docs", "screenshots")
os.makedirs(OUTPUT_DIR, exist_ok=True)

FONT_DIR = r"C:\Windows\Fonts"
font_regular = os.path.join(FONT_DIR, "segoeui.ttf")
font_bold = os.path.join(FONT_DIR, "segoeuib.ttf")
font_mono = os.path.join(FONT_DIR, "consola.ttf")

def get_font(size, bold=False, mono=False):
    f_path = font_mono if mono else (font_bold if bold else font_regular)
    try:
        return ImageFont.truetype(f_path, size)
    except:
        return ImageFont.load_default()

# -----------------------------------------------------------------------------
# 1. Citizen Mobile App: Guard Monitoring Mode (480 x 1000)
# -----------------------------------------------------------------------------
def generate_citizen_guard():
    W, H = 480, 1000
    im = Image.new("RGB", (W, H), (10, 15, 29)) # #0a0f1d
    d = ImageDraw.Draw(im)

    # Status Bar
    d.text((25, 12), "12:42", fill=(248, 250, 252), font=get_font(13, bold=True))
    d.text((W - 90, 12), "5G  98% 🔋", fill=(248, 250, 252), font=get_font(12, bold=True))

    # App Bar
    d.rounded_rectangle((15, 45, W - 15, 110), radius=14, fill=(15, 23, 42), outline=(30, 41, 59), width=1)
    d.text((32, 60), "🛡️ RAKSHAK-AI", fill=(16, 185, 129), font=get_font(18, bold=True))
    d.text((32, 85), "Autonomous Kinematic Road Safety Guard", fill=(148, 163, 184), font=get_font(11))
    d.rounded_rectangle((W - 135, 62, W - 32, 95), radius=16, fill=(16, 185, 129, 40), outline=(16, 185, 129), width=1)
    d.text((W - 122, 70), "ARMED 🟢", fill=(16, 185, 129), font=get_font(12, bold=True))

    # Real-Time G-Force Waveform Card
    d.rounded_rectangle((15, 125, W - 15, 380), radius=16, fill=(15, 23, 42), outline=(16, 185, 129), width=2)
    d.text((32, 140), "LIVE IMU ACCELEROMETER STREAM", fill=(56, 189, 248), font=get_font(12, bold=True, mono=True))
    d.text((W - 110, 140), "100 Hz POLLING", fill=(148, 163, 184), font=get_font(10, mono=True))

    # Waveform canvas
    d.rectangle((30, 170, W - 30, 310), fill=(2, 6, 23), outline=(30, 41, 59), width=1)
    # Grid lines
    for y in range(190, 310, 30):
        d.line((30, y, W - 30, y), fill=(30, 41, 59), width=1)
    # Gentle sine wave showing normal 1.0G gravity
    pts = []
    for x in range(30, W - 30, 4):
        norm = (x - 30) / (W - 60)
        y = 240 + math.sin(norm * 16) * 14
        pts.append((x, y))
    d.line(pts, fill=(16, 185, 129), width=2)

    d.text((32, 325), "CURRENT FORCE: 1.02 G [NORMAL VEHICULAR MOTION]", fill=(16, 185, 129), font=get_font(12, bold=True, mono=True))
    d.text((32, 350), "Impact Trigger Threshold: > 6.50 G Peak with Speed Drop", fill=(148, 163, 184), font=get_font(10))

    # On-Device ML Diagnostics Card
    d.rounded_rectangle((15, 395, W - 15, 660), radius=16, fill=(15, 23, 42), outline=(30, 41, 59), width=1)
    d.text((32, 415), "ON-DEVICE AI RUNTIME TELEMETRY", fill=(248, 250, 252), font=get_font(13, bold=True))

    diag_rows = [
        ("Classifier Runtime", "TensorFlow Lite (INT8 1D-CNN)", (56, 189, 248)),
        ("Inference Execution", "18.2 ms on-device latency", (16, 185, 129)),
        ("Cloud Dependency", "ZERO (100% Offline Capable)", (16, 185, 129)),
        ("Jerk Derivative Filter", "ACTIVE (Prevents phone drop false alarms)", (245, 158, 11)),
        ("GPS Spatial Fix", "12.9716° N, 77.5946° E (Bengaluru)", (248, 250, 252)),
        ("Battery Drain Impact", "< 1.4% / 8 hours background monitoring", (56, 189, 248)),
        ("Deterministic Fallback", "Kinematic Rule Engine ARMED", (16, 185, 129))
    ]
    for idx, (label, val, col) in enumerate(diag_rows):
        ry = 450 + idx * 28
        d.text((32, ry), label, fill=(148, 163, 184), font=get_font(11))
        d.text((210, ry), val, fill=col, font=get_font(11, bold=True))

    # Ayushman Bharat Emergency Health Vault Card
    d.rounded_rectangle((15, 675, W - 15, 830), radius=16, fill=(4, 47, 46), outline=(16, 185, 129), width=2)
    d.text((32, 692), "🛡️ AYUSHMAN BHARAT (ABDM) EMERGENCY VAULT", fill=(52, 211, 153), font=get_font(12, bold=True))
    d.text((32, 720), "ABHA ID: 91-8842-9912-3401 (Verified)", fill=(248, 250, 252), font=get_font(12, bold=True, mono=True))
    d.text((32, 745), "Blood Group: B+ Positive | NOTTO Organ Donor", fill=(167, 243, 208), font=get_font(11))
    d.text((32, 770), "🚨 Allergy: Penicillin Anaphylaxis • Warfarin Thinner", fill=(254, 202, 202), font=get_font(11, bold=True))
    d.text((32, 798), "Hardware TEE Enclave Signed • Zero-Knowledge Proof", fill=(110, 231, 183), font=get_font(10, mono=True))

    # Test Lab Trigger Simulation Button
    d.rounded_rectangle((25, 860, W - 25, 930), radius=16, fill=(225, 29, 72), outline=(244, 63, 94), width=1)
    d.text((W / 2 - 130, 885), "SIMULATE 5.4G CRASH IMPACT ⚡", fill=(255, 255, 255), font=get_font(13, bold=True))
    d.text((W / 2 - 145, 950), "Simulates severe deceleration & tests 15s zero-touch SOS", fill=(100, 116, 139), font=get_font(10))

    out_p = os.path.join(OUTPUT_DIR, "screenshot_citizen_guard.png")
    im.save(out_p, "PNG")
    print(f"Generated: {out_p}")

# -----------------------------------------------------------------------------
# 2. Citizen Mobile App: 15-Second Zero-Touch SOS Countdown Screen (480 x 1000)
# -----------------------------------------------------------------------------
def generate_citizen_countdown():
    W, H = 480, 1000
    im = Image.new("RGB", (W, H), (15, 2, 6)) # Deep red/black
    d = ImageDraw.Draw(im)

    # Status Bar
    d.text((25, 12), "12:43", fill=(248, 250, 252), font=get_font(13, bold=True))
    d.text((W - 90, 12), "5G  97% 🔋", fill=(248, 250, 252), font=get_font(12, bold=True))

    # Emergency Header
    d.rounded_rectangle((20, 50, W - 20, 120), radius=14, fill=(69, 10, 10), outline=(239, 68, 68), width=2)
    d.text((W / 2 - 110, 62), "🚨 SEVERE CRASH DETECTED", fill=(254, 202, 202), font=get_font(16, bold=True))
    d.text((W / 2 - 145, 90), "Peak Impact: 5.42 G  |  Speed Drop: 62.4 km/h", fill=(252, 165, 165), font=get_font(11, bold=True, mono=True))

    # Warning Title
    d.text((W / 2 - 120, 145), "ARE YOU UNINJURED?", fill=(255, 255, 255), font=get_font(20, bold=True))
    d.text((W / 2 - 150, 175), "100 dB Audible Alarm Sounding • Device Wakelock", fill=(252, 165, 165), font=get_font(11))

    # Countdown Ring (Radius 100)
    cx, cy, r = W / 2, 310, 95
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(69, 10, 10, 80), outline=(153, 27, 27), width=16)
    # Animated arc segment (say 11 of 15 seconds remaining)
    d.arc((cx - r, cy - r, cx + r, cy + r), start=-90, end=170, fill=(239, 68, 68), width=16)

    d.text((cx - 35, cy - 40), "11", fill=(255, 255, 255), font=get_font(60, bold=True, mono=True))
    d.text((cx - 65, cy + 25), "SECONDS REMAINING", fill=(254, 202, 202), font=get_font(11, bold=True, mono=True))

    # Big Emerald "I'M OK — CANCEL SOS" Button
    d.rounded_rectangle((30, 450, W - 30, 530), radius=20, fill=(16, 185, 129), outline=(52, 211, 153), width=2)
    d.text((W / 2 - 115, 477), "I'M OK — CANCEL SOS", fill=(2, 44, 34), font=get_font(18, bold=True))
    d.text((W / 2 - 125, 545), "Tap to abort emergency dispatch if uninjured", fill=(148, 163, 184), font=get_font(11))

    # Ayushman Bharat (ABDM) Emergency Health Vault Chip
    d.rounded_rectangle((20, 580, W - 20, 700), radius=16, fill=(4, 47, 46), outline=(16, 185, 129), width=2)
    d.text((36, 598), "🛡️ AYUSHMAN BHARAT (ABDM) HEALTH VAULT", fill=(52, 211, 153), font=get_font(12, bold=True))
    d.text((36, 625), "ABHA ID: 91-8842-9912-3401 (Verified) • Stevin Joseph", fill=(248, 250, 252), font=get_font(11, bold=True, mono=True))
    d.text((36, 648), "Confirmed Blood Group: B+ Positive | Organ Donor: NOTTO", fill=(167, 243, 208), font=get_font(11))
    d.text((36, 672), "🚨 Allergy Alert: Penicillin Anaphylaxis • Warfarin Thinner", fill=(254, 202, 202), font=get_font(11, bold=True))

    # AI Crash Biomechanics Preview Chip
    d.rounded_rectangle((20, 715, W - 20, 835), radius=16, fill=(30, 41, 59), outline=(56, 189, 248), width=2)
    d.text((36, 730), "⚡ AI CRASH BIOMECHANICS & VIRTUAL BLACKBOX (PINN)", fill=(56, 189, 248), font=get_font(11, bold=True))
    d.text((36, 755), "Delta-V: 62.4 km/h  |  Decel: 48.6 G  |  ISS: 26 (Severe)", fill=(248, 250, 252), font=get_font(11, bold=True, mono=True))
    d.text((36, 780), "• C-Spine Whiplash: 84% [CRITICAL] ➔ Collar Required", fill=(248, 113, 113), font=get_font(10.5))
    d.text((36, 805), "• Myocardial Contusion: 76%  |  Splenic Laceration: 61%", fill=(251, 191, 36), font=get_font(10.5))

    # Zero-Touch Autonomous Dispatch Footer
    d.rounded_rectangle((20, 855, W - 20, 955), radius=16, fill=(15, 23, 42), outline=(30, 41, 59), width=1)
    d.text((36, 870), "ZERO-TOUCH LIFESAVER GUARANTEE", fill=(255, 255, 255), font=get_font(12, bold=True))
    d.text((36, 895), "If unconscious or incapacitated, dispatch auto-triggers at 00:00.", fill=(148, 163, 184), font=get_font(10))
    d.text((36, 915), "Transmits GPS, Biomechanics & ABHA Vault to Nearest Trauma ER.", fill=(16, 185, 129), font=get_font(10, bold=True))
    d.text((36, 933), "Sends background dual-SIM SOS SMS with live tracking link.", fill=(56, 189, 248), font=get_font(10))

    out_p = os.path.join(OUTPUT_DIR, "screenshot_citizen_countdown.png")
    im.save(out_p, "PNG")
    print(f"Generated: {out_p}")

# -----------------------------------------------------------------------------
# 3. Ambulance Cockpit Console: 1-Tap Claiming (1000 x 650)
# -----------------------------------------------------------------------------
def generate_ambulance_claim():
    W, H = 1000, 650
    im = Image.new("RGB", (W, H), (10, 15, 29))
    d = ImageDraw.Draw(im)

    # Rugged Tablet Header
    d.rectangle((0, 0, W, 60), fill=(15, 23, 42))
    d.text((25, 18), "🚑 RAKSHAK 108 AMBULANCE COCKPIT • VEHICLE KA-03-E-9912", fill=(16, 185, 129), font=get_font(16, bold=True))
    d.text((W - 220, 20), "GPS FIXED 🟢 • C-V2X READY", fill=(56, 189, 248), font=get_font(12, bold=True, mono=True))

    # Active Emergency Dispatch Card
    d.rounded_rectangle((35, 85, W - 35, 490), radius=18, fill=(15, 23, 42), outline=(239, 68, 68), width=3)
    d.text((60, 110), "🚨 EMERGENCY DISPATCH BROADCAST RECEIVED", fill=(239, 68, 68), font=get_font(18, bold=True, mono=True))
    d.text((W - 280, 112), "PRIORITY: T1 CRITICAL RED", fill=(239, 68, 68), font=get_font(13, bold=True, mono=True))

    d.line((60, 145, W - 60, 145), fill=(30, 41, 59), width=1)

    # Dispatch details grid
    rows = [
        ("Crash Location:", "Indiranagar 100ft Road, Bengaluru (12.9716° N, 77.5946° E)"),
        ("Road Distance:", "1.8 km (~4 mins transit with Green Corridor active)"),
        ("Kinetic Telemetry:", "Peak Deceleration: 48.6 G  |  Delta-V: 62.4 km/h  |  ISS: 26 (Severe)"),
        ("Matched Trauma ER:", "Manipal Hospital, Old Airport Road (Trauma Bay 01 Pre-Armed)"),
        ("Traffic Preemption:", "Autonomous Green Wave Armed • 4 Intersections Projecting Green")
    ]
    for idx, (label, val) in enumerate(rows):
        ry = 165 + idx * 36
        d.text((60, ry), label, fill=(148, 163, 184), font=get_font(13, bold=True))
        d.text((230, ry), val, fill=(248, 250, 252), font=get_font(13, bold=True))

    # Parity Action Chips
    d.rounded_rectangle((60, 360, 360, 405), radius=8, fill=(30, 41, 59), outline=(239, 68, 68), width=1)
    d.text((75, 375), "⚡ AI TRAUMA BLACKBOX: ISS 26", fill=(248, 113, 113), font=get_font(12, bold=True, mono=True))

    d.rounded_rectangle((380, 360, 710, 405), radius=8, fill=(4, 47, 46), outline=(16, 185, 129), width=1)
    d.text((395, 375), "🛡️ ABHA VAULT: B+ POSITIVE (ALLERGY ⚠️)", fill=(52, 211, 153), font=get_font(12, bold=True, mono=True))

    d.text((60, 425), "⚠️ CRITICAL ALLERGY: Penicillin Anaphylaxis • Patient on Warfarin (Blood Thinner)", fill=(254, 202, 202), font=get_font(12, bold=True))
    d.text((60, 452), "Paramedic Directive: Prepare Cervical Collar immobilization and IV Normal Saline en route.", fill=(56, 189, 248), font=get_font(11.5))

    # Big 1-Tap Claim Button
    d.rounded_rectangle((35, 520, W - 35, 610), radius=18, fill=(16, 185, 129), outline=(52, 211, 153), width=2)
    d.text((W / 2 - 210, 552), "CLAIM INCIDENT & ENGAGE GREEN CORRIDOR ➔", fill=(2, 44, 34), font=get_font(20, bold=True))

    out_p = os.path.join(OUTPUT_DIR, "screenshot_ambulance_claim.png")
    im.save(out_p, "PNG")
    print(f"Generated: {out_p}")

# -----------------------------------------------------------------------------
# 4. Ambulance Cockpit Console: Green Wave Navigation HUD (1000 x 650)
# -----------------------------------------------------------------------------
def generate_ambulance_hud():
    W, H = 1000, 650
    im = Image.new("RGB", (W, H), (10, 15, 29))
    d = ImageDraw.Draw(im)

    # Top Cockpit Bar
    d.rectangle((0, 0, W, 50), fill=(15, 23, 42))
    d.text((25, 15), "🟢 [C-V2X Status: ACTIVE] Autonomous Green Wave Preemption ON", fill=(16, 185, 129), font=get_font(14, bold=True, mono=True))
    d.text((W - 380, 15), "🤖 Dynamic Detour: 100ft Rd Choke Bypassed (-4.2 min)", fill=(56, 189, 248), font=get_font(12, bold=True))

    # Vector Map Area
    d.rectangle((20, 65, W - 20, 520), fill=(2, 6, 23), outline=(30, 41, 59), width=2)

    # Grid roads
    d.line((100, 280, W - 100, 280), fill=(30, 41, 59), width=24) # Main road
    d.line((350, 100, 350, 500), fill=(30, 41, 59), width=20) # Cross road 1
    d.line((700, 100, 700, 500), fill=(30, 41, 59), width=20) # Cross road 2

    # Choke point on straight road (Red dashed area)
    d.line((400, 280, 650, 280), fill=(239, 68, 68), width=24)
    d.text((430, 272), "100FT ROAD CHOKE (89% CONGESTION)", fill=(255, 255, 255), font=get_font(10, bold=True))

    # A* Green Detour Route Line (Glowing emerald curve bypassing choke)
    detour_pts = [
        (100, 280), (320, 280), (350, 270), (380, 200), (620, 200), (670, 260), (700, 280), (880, 280)
    ]
    d.line(detour_pts, fill=(16, 185, 129), width=10)

    # Approaching Ambulance Marker
    d.ellipse((305, 265, 335, 295), fill=(16, 185, 129), outline=(255, 255, 255), width=3)
    d.text((275, 305), "AMBULANCE (65 km/h)", fill=(52, 211, 153), font=get_font(11, bold=True, mono=True))

    # Upcoming Traffic Signal Icon (Preempted Green)
    d.rounded_rectangle((335, 150, 365, 210), radius=6, fill=(15, 23, 42), outline=(16, 185, 129), width=2)
    d.ellipse((343, 188, 357, 202), fill=(16, 185, 129)) # Solid green light
    d.text((375, 175), "SIGNAL #04: SOLID GREEN 🟢 (Preempted 45s ahead)", fill=(16, 185, 129), font=get_font(11, bold=True, mono=True))

    # Crash Destination Pin
    d.ellipse((870, 268, 894, 292), fill=(239, 68, 68), outline=(255, 255, 255), width=2)
    d.text((830, 305), "CRASH SCENE (Indiranagar)", fill=(248, 113, 113), font=get_font(11, bold=True))

    # Floating HUD Overlay Deck
    d.rounded_rectangle((40, 85, 260, 225), radius=14, fill=(15, 23, 42, 220), outline=(56, 189, 248), width=2)
    d.text((55, 100), "CURRENT TRANSIT SPEED", fill=(148, 163, 184), font=get_font(10, bold=True))
    d.text((55, 115), "65 km/h", fill=(16, 185, 129), font=get_font(32, bold=True, mono=True))

    d.text((55, 165), "NEXT SIGNAL DISTANCE", fill=(148, 163, 184), font=get_font(10, bold=True))
    d.text((55, 180), "320 m", fill=(56, 189, 248), font=get_font(22, bold=True, mono=True))
    d.text((140, 185), "PREEMPTED 🟢", fill=(16, 185, 129), font=get_font(11, bold=True))

    # Bottom Paramedic Clinical Bar
    d.rectangle((0, 540, W, H), fill=(15, 23, 42))
    d.text((25, 555), "⚡ Trauma Blackbox: Delta-V 62.4 km/h  |  ISS 26  |  C-Spine 84% [Collar Ready]", fill=(248, 113, 113), font=get_font(12, bold=True, mono=True))
    d.text((25, 582), "🛡️ ABHA Vault: Stevin Joseph  |  Blood B+ Pos  |  ⚠️ CONTRAINDICATION: PENICILLIN ANAPHYLAXIS", fill=(52, 211, 153), font=get_font(12, bold=True, mono=True))
    d.text((25, 608), "🏥 Matched Facility: Manipal Hospital (Bay 01 Reserved)  |  Distance to Patient: 680 m", fill=(226, 232, 240), font=get_font(11))

    out_p = os.path.join(OUTPUT_DIR, "screenshot_ambulance_hud.png")
    im.save(out_p, "PNG")
    print(f"Generated: {out_p}")

# -----------------------------------------------------------------------------
# 5. Central Police & ITMS Command Dashboard (1200 x 700)
# -----------------------------------------------------------------------------
def generate_police_dashboard():
    W, H = 1200, 700
    im = Image.new("RGB", (W, H), (10, 15, 29))
    d = ImageDraw.Draw(im)

    # Top Navbar
    d.rectangle((0, 0, W, 50), fill=(15, 23, 42))
    d.text((25, 15), "🚓 BENGALURU POLICE ITMS COMMAND • POLICE_TACTICAL_VIEW (JWT VERIFIED)", fill=(56, 189, 248), font=get_font(15, bold=True))
    d.text((W - 280, 16), "POLICE DISPATCHER: SGT. KUMAR", fill=(148, 163, 184), font=get_font(12, mono=True))
    d.rounded_rectangle((W - 130, 12, W - 25, 40), radius=6, fill=(239, 68, 68, 40), outline=(239, 68, 68), width=1)
    d.text((W - 110, 18), "LIVE FEED 🔴", fill=(239, 68, 68), font=get_font(11, bold=True))

    # Left Drawer: Incident Triage Feed (340px width)
    d.rectangle((0, 50, 340, H), fill=(2, 6, 23))
    d.text((20, 68), "ACTIVE EMERGENCIES (1)", fill=(148, 163, 184), font=get_font(12, bold=True, mono=True))

    # Incident Card
    d.rounded_rectangle((15, 95, 325, 330), radius=12, fill=(15, 23, 42), outline=(239, 68, 68), width=2)
    d.text((30, 110), "INCIDENT #4d4ea69d", fill=(239, 68, 68), font=get_font(13, bold=True, mono=True))
    d.rounded_rectangle((230, 108, 310, 128), radius=8, fill=(239, 68, 68), outline=(239, 68, 68), width=1)
    d.text((242, 112), "T1 RED", fill=(255, 255, 255), font=get_font(10, bold=True))

    d.text((30, 140), "Location: Indiranagar 100ft Rd", fill=(248, 250, 252), font=get_font(12, bold=True))
    d.text((30, 162), "Deceleration: 48.6 G  |  Delta-V: 62.4 km/h", fill=(248, 113, 113), font=get_font(11, mono=True))
    d.text((30, 185), "Accepted by: Manipal Hospital (Bay 01)", fill=(52, 211, 153), font=get_font(11, bold=True))
    d.text((30, 208), "Ambulance: KA-03-E-9912 (En Route)", fill=(56, 189, 248), font=get_font(11))
    d.text((30, 230), "Traffic Wave: 4 Junctions Preempted 🟢", fill=(16, 185, 129), font=get_font(11))

    # Police Dispatch Button
    d.rounded_rectangle((30, 260, 310, 305), radius=8, fill=(2, 132, 199), outline=(56, 189, 248), width=1)
    d.text((45, 275), "DISPATCH PCR VAN KA-01-G-404 🚓", fill=(255, 255, 255), font=get_font(11, bold=True))

    # CCTV Edge Vision Alert in Left Drawer
    d.rounded_rectangle((15, 345, 325, 480), radius=12, fill=(15, 23, 42), outline=(245, 158, 11), width=2)
    d.text((30, 360), "CCTV EDGE VISION (YOLOv8)", fill=(245, 158, 11), font=get_font(12, bold=True, mono=True))
    d.text((30, 385), "100ft Rd Choke Density: 89% (Critical)", fill=(239, 68, 68), font=get_font(11, bold=True))
    d.text((30, 408), "Queue: 480m Standstill • Zero Yield Space", fill=(148, 163, 184), font=get_font(10.5))
    d.text((30, 430), "Action: Dynamic A* Reroute Engaged", fill=(16, 185, 129), font=get_font(11, bold=True))
    d.text((30, 452), "Detour: Old Airport Road (-4.2 min)", fill=(56, 189, 248), font=get_font(11))

    # Right Canvas: Large City GIS Map (340px to W)
    d.rectangle((340, 50, W, H), fill=(6, 10, 20))
    # Map vector lines
    d.line((420, 350, 1100, 350), fill=(26, 36, 56), width=32) # Primary Expressway
    d.line((650, 100, 650, 650), fill=(26, 36, 56), width=24) # Ring Road
    d.line((900, 100, 900, 650), fill=(26, 36, 56), width=24) # 100ft Rd

    # Green Corridor Glow Line
    d.line([(450, 350), (650, 350), (650, 260), (850, 260), (900, 320), (1050, 320)], fill=(16, 185, 129), width=12)

    # City Map Pins
    # Crash Scene Pin
    d.ellipse((1035, 305, 1065, 335), fill=(239, 68, 68), outline=(255, 255, 255), width=3)
    d.text((1000, 345), "CRASH SCENE", fill=(239, 68, 68), font=get_font(12, bold=True))

    # Hospital Pin
    d.ellipse((435, 335, 465, 365), fill=(168, 85, 247), outline=(255, 255, 255), width=3)
    d.text((380, 375), "MANIPAL HOSPITAL (ER)", fill=(168, 85, 247), font=get_font(12, bold=True))

    # PCR Cruiser KA-01-G-404 Pin
    d.ellipse((740, 245, 765, 270), fill=(2, 132, 199), outline=(255, 255, 255), width=2)
    d.text((710, 278), "PCR KA-01-G-404 (ETA 1.8m)", fill=(56, 189, 248), font=get_font(11, bold=True))

    # C-V2X Junction Badges
    d.rounded_rectangle((630, 225, 670, 255), radius=6, fill=(16, 185, 129))
    d.text((642, 233), "🟢", fill=(255, 255, 255), font=get_font(12))

    d.rounded_rectangle((880, 285, 920, 315), radius=6, fill=(16, 185, 129))
    d.text((892, 293), "🟢", fill=(255, 255, 255), font=get_font(12))

    # Legend Card
    d.rounded_rectangle((W - 250, H - 150, W - 20, H - 20), radius=10, fill=(15, 23, 42, 220), outline=(30, 41, 59), width=1)
    d.text((W - 235, H - 135), "GIS TACTICAL LEGEND", fill=(148, 163, 184), font=get_font(10, bold=True))
    d.text((W - 235, H - 110), "🟢 Active Green Wave Corridor", fill=(16, 185, 129), font=get_font(10.5))
    d.text((W - 235, H - 85), "🚓 Dispatched PCR Police Patrol", fill=(56, 189, 248), font=get_font(10.5))
    d.text((W - 235, H - 60), "🏥 Level-1 Designated Trauma Bay", fill=(168, 85, 247), font=get_font(10.5))
    d.text((W - 235, H - 35), "🔴 Severe Kinetic Collision Site", fill=(239, 68, 68), font=get_font(10.5))

    out_p = os.path.join(OUTPUT_DIR, "screenshot_police_dashboard.png")
    im.save(out_p, "PNG")
    print(f"Generated: {out_p}")

# -----------------------------------------------------------------------------
# 6. Hospital Trauma Bay Dashboard (1200 x 700)
# -----------------------------------------------------------------------------
def generate_hospital_dashboard():
    W, H = 1200, 700
    im = Image.new("RGB", (W, H), (10, 15, 29))
    d = ImageDraw.Draw(im)

    # Top Navbar
    d.rectangle((0, 0, W, 50), fill=(6, 78, 59))
    d.text((25, 14), "🏥 MANIPAL HOSPITAL EMERGENCY COMMAND • DR. RAMESH (CHIEF TRAUMA SURGEON)", fill=(167, 243, 208), font=get_font(15, bold=True))
    d.text((W - 320, 16), "FACILITY ID: manipal_old_airport_rd", fill=(110, 231, 183), font=get_font(12, mono=True))
    d.rounded_rectangle((W - 110, 12, W - 25, 40), radius=6, fill=(239, 68, 68), outline=(255, 255, 255), width=1)
    d.text((W - 95, 18), "LOGOUT", fill=(255, 255, 255), font=get_font(11, bold=True))

    # Main Grid (Left: 560px, Right: 600px)
    # Left Card: Live WebRTC Photo Feed & Case Status
    d.rounded_rectangle((20, 65, 560, H - 20), radius=16, fill=(15, 23, 42), outline=(16, 185, 129), width=2)

    # Incident header
    d.rounded_rectangle((35, 80, 230, 108), radius=14, fill=(220, 252, 231), outline=(134, 239, 172), width=1)
    d.text((45, 87), "ACCEPTED BY YOUR FACILITY 🟢", fill=(21, 128, 61), font=get_font(11, bold=True))
    d.text((245, 88), "ID: 4d4ea69d-9912...", fill=(148, 163, 184), font=get_font(11, mono=True))

    d.text((35, 120), "ROAD DISTANCE: ~1.8 km Road", fill=(220, 38, 38), font=get_font(18, bold=True))
    d.text((320, 123), "ETA: ~3.8 mins (Green Corridor)", fill=(16, 185, 129), font=get_font(12, bold=True))

    # Simulated Live WebRTC Camera Stream Frame (Zero-Storage RAM)
    d.rounded_rectangle((35, 155, 545, 410), radius=10, fill=(2, 6, 23), outline=(56, 189, 248), width=2)
    # Top overlay inside stream
    d.rectangle((35, 155, 545, 185), fill=(15, 23, 42, 220))
    d.ellipse((45, 165, 55, 175), fill=(239, 68, 68))
    d.text((62, 163), "LIVE WEBRTC P2P TRIAGE STREAM (IN-MEMORY RAM ONLY)", fill=(255, 255, 255), font=get_font(10.5, bold=True, mono=True))

    d.rounded_rectangle((410, 160, 535, 180), radius=10, fill=(5, 150, 105))
    d.text((420, 164), "⚡ WebRTC P2P", fill=(255, 255, 255), font=get_font(9.5, bold=True))

    # Mock photo contents: vehicle cabin deformation
    d.rectangle((50, 195, 530, 395), fill=(15, 23, 42))
    d.text((120, 275), "[ Visual Triage Stream: Frontal Cabin Crush Detected ]", fill=(148, 163, 184), font=get_font(13))
    d.text((150, 305), "Steering wheel deformed • Front windshield shattered", fill=(100, 116, 139), font=get_font(11))
    d.text((140, 375), "🔒 Zero-Persistent-Storage (TTL 900s) • DPDP Act 2023", fill=(16, 185, 129), font=get_font(11, bold=True, mono=True))

    # Toggle Pills
    d.rounded_rectangle((35, 425, 280, 470), radius=10, fill=(254, 242, 242), outline=(239, 68, 68), width=2)
    d.text((48, 440), "⚡ AI Crash Biomechanics (ISS 26)", fill=(153, 27, 27), font=get_font(12, bold=True))

    d.rounded_rectangle((295, 425, 545, 470), radius=10, fill=(240, 253, 244), outline=(16, 185, 129), width=2)
    d.text((308, 440), "🛡️ ABHA Health Vault (B+ Pos)", fill=(22, 101, 52), font=get_font(12, bold=True))

    # Paramedic En Route Status Card
    d.rounded_rectangle((35, 485, 545, 595), radius=12, fill=(2, 6, 23), outline=(30, 41, 59), width=1)
    d.text((50, 500), "AMBULANCE EN ROUTE TELEMETRY", fill=(56, 189, 248), font=get_font(11, bold=True))
    d.text((50, 525), "• Assigned Unit: BLR-01 (KA-03-E-9912)", fill=(248, 250, 252), font=get_font(12))
    d.text((50, 548), "• Paramedic Claim: Accepted (Case Locked Network-Wide)", fill=(16, 185, 129), font=get_font(12, bold=True))
    d.text((50, 570), "• Approaching Corridor: Indiranagar 100ft Bypass (Speed: 65 km/h)", fill=(226, 232, 240), font=get_font(11))

    # Right Card: AI Crash Biomechanics & Ayushman Bharat Vault Panels
    d.rounded_rectangle((585, 65, W - 20, H - 20), radius=16, fill=(15, 23, 42), outline=(56, 189, 248), width=2)

    # Section 1: AI Crash Biomechanics (PINN)
    d.text((605, 80), "⚡ PHYSICS-INFORMED CRASH BIOMECHANICS & INJURY PREDICTION (PINN)", fill=(248, 113, 113), font=get_font(12, bold=True, mono=True))

    # 4 stats pills
    pills = [
        ("DELTA-V DROP", "62.4 km/h", (248, 113, 113)),
        ("PEAK DECEL", "48.6 G", (239, 68, 68)),
        ("KINETIC ENERGY", "142.8 kJ", (251, 191, 36)),
        ("PREDICTED ISS", "26 (Severe)", (248, 113, 113))
    ]
    for idx, (label, val, col) in enumerate(pills):
        px = 605 + idx * 145
        d.rounded_rectangle((px, 105, px + 135, 155), radius=8, fill=(30, 41, 59), outline=(51, 65, 85), width=1)
        d.text((px + 10, 112), label, fill=(148, 163, 184), font=get_font(9, bold=True))
        d.text((px + 10, 128), val, fill=col, font=get_font(14, bold=True, mono=True))

    # Organ injury risk rows
    organ_rows = [
        ("C-Spine Whiplash / Fracture", "84% Risk [CRITICAL]", "Immediate C-Spine Collar Immobilization", (239, 68, 68)),
        ("Blunt Sternal / Myocardial Contusion", "76% Risk [HIGH]", "Prepare 12-lead ECG & Cardiac Troponin", (245, 158, 11)),
        ("Intra-Abdominal / Splenic Laceration", "61% Risk [HIGH]", "FAST Abdominal Ultrasound Protocol on arrival", (245, 158, 11))
    ]
    for idx, (inj, risk, act, col) in enumerate(organ_rows):
        oy = 170 + idx * 42
        d.rounded_rectangle((605, oy, W - 35, oy + 36), radius=6, fill=(2, 6, 23), outline=col, width=1)
        d.text((615, oy + 5), inj, fill=(255, 255, 255), font=get_font(11, bold=True))
        d.text((615, oy + 20), f"🏥 Clinical Action: {act}", fill=(56, 189, 248), font=get_font(9.5))
        d.rounded_rectangle((W - 145, oy + 6, W - 45, oy + 28), radius=6, fill=col)
        d.text((W - 138, oy + 10), risk, fill=(255, 255, 255), font=get_font(9, bold=True))

    # Section 2: Ayushman Bharat (ABDM) Health Vault
    d.line((605, 305, W - 35, 305), fill=(30, 41, 59), width=1)
    d.text((605, 318), "🛡️ AYUSHMAN BHARAT (ABDM) EMERGENCY HEALTH VAULT", fill=(52, 211, 153), font=get_font(12, bold=True, mono=True))
    d.text((W - 200, 320), "Verified via ABDM Gateway ✅", fill=(110, 231, 183), font=get_font(10, bold=True))

    # Patient details grid
    d.rounded_rectangle((605, 340, W - 35, 410), radius=8, fill=(4, 47, 46, 140), outline=(16, 185, 129), width=1)
    d.text((615, 348), "ABHA: 91-8842-9912-3401 (stevin.joseph@abdm)", fill=(167, 243, 208), font=get_font(11, bold=True, mono=True))
    d.text((615, 368), "Patient: Stevin Joseph (Verified)  |  Blood Group: B+ Positive", fill=(255, 255, 255), font=get_font(11.5, bold=True))
    d.text((615, 388), "Organ Donor: Registered (NOTTO-IND-2024-88419)  |  Hardware TEE Enclave Signed", fill=(110, 231, 183), font=get_font(10, mono=True))

    # High Urgency Allergy Contraindication Alert (Red Box)
    d.rounded_rectangle((605, 420, W - 35, 490), radius=8, fill=(69, 10, 10), outline=(239, 68, 68), width=2)
    d.text((615, 428), "🚨 HIGH-URGENCY CONTRAINDICATION: PENICILLIN ANAPHYLAXIS", fill=(254, 202, 202), font=get_font(12, bold=True))
    d.text((615, 448), "DO NOT ADMINISTER BETA-LACTAM ANTIBIOTICS DURING RESUSCITATION!", fill=(255, 255, 255), font=get_font(11, bold=True))
    d.text((615, 468), "⚠️ Active Medication: Warfarin Blood Thinner — Severe Internal Hemorrhage Risk!", fill=(252, 165, 165), font=get_font(10.5))

    # Surgical Preparedness Checklist
    d.rounded_rectangle((605, 505, W - 35, 595), radius=8, fill=(2, 6, 23), outline=(30, 41, 59), width=1)
    d.text((615, 515), "SURGICAL READINESS & PRE-ORDER CHECKLIST", fill=(148, 163, 184), font=get_font(11, bold=True))
    d.text((615, 538), "• Trauma Bay 01: RESERVED & PRE-ARMED 🟢", fill=(52, 211, 153), font=get_font(11.5, bold=True))
    d.text((615, 558), "• Blood Bank: 2 Units B+ Positive / O-Negative CROSS-MATCHED 🟢", fill=(52, 211, 153), font=get_font(11.5, bold=True))
    d.text((615, 578), "• Polytrauma CT Suite: CLEARED FOR DOCKING 🟢", fill=(52, 211, 153), font=get_font(11.5, bold=True))

    out_p = os.path.join(OUTPUT_DIR, "screenshot_hospital_dashboard.png")
    im.save(out_p, "PNG")
    print(f"Generated: {out_p}")

if __name__ == "__main__":
    generate_citizen_guard()
    generate_citizen_countdown()
    generate_ambulance_claim()
    generate_ambulance_hud()
    generate_police_dashboard()
    generate_hospital_dashboard()
    print("[SUCCESS] All 6 high-fidelity UI screenshots generated successfully!")
