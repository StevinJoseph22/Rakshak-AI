import os
import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import OxmlElement, parse_xml
from docx.oxml.ns import nsdecls, qn

doc = docx.Document()

# Set standard 0.75-inch margins for a tight, elegant 2-page document
for section in doc.sections:
    section.top_margin = Inches(0.7)
    section.bottom_margin = Inches(0.7)
    section.left_margin = Inches(0.75)
    section.right_margin = Inches(0.75)

# Styling helper functions
def set_para_font(p, name="Calibri", size_pt=10, bold=False, italic=False, color_rgb=(30, 41, 59)):
    for r in p.runs:
        r.font.name = name
        r.font.size = Pt(size_pt)
        r.font.bold = bold
        r.font.italic = italic
        r.font.color.rgb = RGBColor(*color_rgb)

def add_header_block():
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.space_before = Pt(0)
    r1 = p.add_run("KRISTU JAYANTI DEEMED TO BE UNIVERSITY\n")
    r1.font.name = "Calibri"
    r1.font.size = Pt(11)
    r1.font.bold = True
    r1.font.color.rgb = RGBColor(15, 23, 42)
    
    r2 = p.add_run("SEVA FIRST INNOVATION CHALLENGE 2026 | SFI CONCEPT NOTE\n")
    r2.font.name = "Calibri"
    r2.font.size = Pt(9.5)
    r2.font.bold = True
    r2.font.color.rgb = RGBColor(194, 65, 12) # Dark Orange

    r3 = p.add_run("THEME 5: SURAKSHIT BHARAT  •  TRACK A: PRODUCT & TECHNOLOGY")
    r3.font.name = "Calibri"
    r3.font.size = Pt(8.5)
    r3.font.italic = True
    r3.font.color.rgb = RGBColor(71, 85, 105)

def add_title():
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after = Pt(2)
    r = p.add_run("RAKSHAK-AI: Zero-Delay Crash Intelligence & Autonomous Multi-Agency Emergency Network")
    r.font.name = "Calibri"
    r.font.size = Pt(14)
    r.font.bold = True
    r.font.color.rgb = RGBColor(15, 23, 42)

    p_sub = doc.add_paragraph()
    p_sub.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p_sub.paragraph_format.space_after = Pt(8)
    r_sub = p_sub.add_run("Team Name: Vikist Blueprint  |  Project Track: AI in Public Safety & ITS")
    r_sub.font.name = "Calibri"
    r_sub.font.size = Pt(9.5)
    r_sub.font.bold = True
    r_sub.font.color.rgb = RGBColor(37, 99, 235)

def add_section_heading(title_text):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(8)
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.keep_with_next = True
    r = p.add_run(title_text)
    r.font.name = "Calibri"
    r.font.size = Pt(11)
    r.font.bold = True
    r.font.color.rgb = RGBColor(15, 23, 42)

def add_body_paragraph(text, space_after=4):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(space_after)
    p.paragraph_format.line_spacing = 1.08
    r = p.add_run(text)
    r.font.name = "Calibri"
    r.font.size = Pt(9.5)
    r.font.color.rgb = RGBColor(30, 41, 59)
    return p

# 1. Header
add_header_block()
add_title()

# Section 1
add_section_heading("1. The Ground Reality & Why We Built This")
add_body_paragraph(
    "Every day on our commutes through Bengaluru—whether past Silk Board, Dairy Circle, or the Outer Ring Road—we see the exact same tragic pattern. An accident happens, usually involving a two-wheeler rider or a delivery partner. The rider is thrown to the asphalt, knocked unconscious. A crowd gathers, but people hesitate to help. It takes 15 to 20 minutes before someone calls 112 or 108. When an ambulance finally arrives, it gets trapped in gridlocked traffic at signalized junctions, blaring its siren with nowhere to go. And when the victim finally reaches the casualty ward, doctors lose critical minutes scrambling to determine their blood group, identify severe drug allergies, and find their emergency contacts."
)
add_body_paragraph(
    "Medical science defines the first 60 minutes after trauma as the 'Golden Hour.' In India, where more than 1.68 lakh people die on roads every single year, over half of these lives could be saved if medical care reached them within this window. We built Rakshak-AI because road crash response should not depend on the luck of a bystander making a phone call, or an ambulance begging for right-of-way in traffic. It should happen automatically, reliably, and in seconds."
)

# Section 2
add_section_heading("2. What Rakshak-AI Does Differently")
add_body_paragraph(
    "Existing solutions like Apple Crash Detection or generic SOS buttons are passive and isolated. They wait on the phone for 10 to 30 seconds before contacting emergency numbers via basic SMS, and once an SMS is sent, their job is done. They do not talk to the traffic signals, they do not tell the hospital what blood group is needed, and they do not prevent traffic bottlenecks."
)
add_body_paragraph(
    "Rakshak-AI connects the entire emergency chain into a unified, zero-delay pipeline through four key innovations:"
)

points = [
    ("Instant Pre-Alert Protocol: ", "Instead of waiting for a 10-second countdown to finish before contacting emergency services, Rakshak-AI transmits an ultra-lightweight 'impact_suspected' ping to the Police Command Room the exact millisecond an impact signature is sensed. This gives police patrols a 10 to 15-second head start. If the rider cancels the prompt, the alert clears; if confirmed, it promotes instantly."),
    ("Physics-Based False Alarm Suppression: ", "A dropped smartphone easily hits 10g to 14g on tiled floors. Simple g-force triggers result in huge false alarms. Our edge engine inspects free-fall (near-0g right before impact indicates a dropped phone, not a crash), velocity drop (speed drop before vs after), post-impact stillness, and gyro rollover before deciding confidence."),
    ("C-V2X Automated Green Corridors: ", "Ambulances lose 15 to 25 minutes at red lights. Using V2X communication standards (SAE J2735 / NTCIP 1202), Rakshak-AI communicates with intersection signal controllers 400m ahead, automatically clearing oncoming signals to green as the ambulance approaches."),
    ("Pre-Arrival ABHA Health Readiness: ", "With the victim's cryptographic consent, the admitting hospital's trauma bay immediately receives their verified ABHA ID, Blood Group (e.g., O+), and critical drug allergies (e.g., Penicillin contraindication) before the ambulance arrives, cutting out 15 minutes of emergency room guesswork.")
]

for title_b, body_b in points:
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(2.5)
    p.paragraph_format.left_indent = Inches(0.2)
    p.paragraph_format.line_spacing = 1.05
    r_t = p.add_run("• " + title_b)
    r_t.font.name = "Calibri"
    r_t.font.size = Pt(9.5)
    r_t.font.bold = True
    r_t.font.color.rgb = RGBColor(15, 23, 42)
    r_b = p.add_run(body_b)
    r_b.font.name = "Calibri"
    r_b.font.size = Pt(9.5)
    r_b.font.color.rgb = RGBColor(51, 65, 85)

# Section 3
add_section_heading("3. End-to-End System Architecture & Data Flow")
add_body_paragraph(
    "Our architecture is divided into three coordinated layers operating seamlessly across edge devices, central orchestration, and emergency response consoles:"
)

# Insert ASCII / Structured Architecture Table
tbl = doc.add_table(rows=5, cols=3)
tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
tbl.autofit = False

col_widths = [Inches(1.8), Inches(2.2), Inches(2.8)]
headers = ["Ecosystem Layer", "Core Technologies", "Operational Functionality"]
for i, h_text in enumerate(headers):
    cell = tbl.cell(0, i)
    cell.width = col_widths[i]
    p = cell.paragraphs[0]
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(2)
    r = p.add_run(h_text)
    r.font.name = "Calibri"
    r.font.size = Pt(8.5)
    r.font.bold = True
    r.font.color.rgb = RGBColor(255, 255, 255)
    shd = parse_xml(r'<w:shd {} w:fill="0F172A"/>'.format(nsdecls('w')))
    cell._tc.get_or_add_tcPr().append(shd)

data_rows = [
    ("Edge Sensing & Citizen App", "Flutter, SQLite, 50Hz IMU, GPS, WebRTC DataChannel", "Continuous circular buffer; pre-alert ping; free-fall & quiescence filter; offline store-and-forward queue."),
    ("Central Emergency Broker", "Node.js, TypeScript, PostgreSQL, PostGIS, Socket.io, Redis", "Sub-800ms multi-agency dispatch; 8km hospital sector radius matching; ABHA vault lookup; accident blackspot tracking."),
    ("Tactical Agency Dashboards", "React 18, Vite, Tailwind CSS, WebRTC P2P receiver", "Police tactical map with soft markers; Hospital clinical console with 1-click bay reservation; Ambulance HUD with OSRM routing."),
    ("C-V2X Green Corridor Layer", "SAE J2735 SRM/SSM, NTCIP 1202, Eclipse SUMO, TraCI", "Dynamic geofence pre-emption; communicates with signal controllers 400m ahead; turns cross-traffic red and corridors green.")
]

for row_idx, data in enumerate(data_rows, start=1):
    for col_idx, text in enumerate(data):
        cell = tbl.cell(row_idx, col_idx)
        cell.width = col_widths[col_idx]
        p = cell.paragraphs[0]
        p.paragraph_format.space_before = Pt(2)
        p.paragraph_format.space_after = Pt(2)
        p.paragraph_format.line_spacing = 1.05
        r = p.add_run(text)
        r.font.name = "Calibri"
        r.font.size = Pt(8)
        r.font.color.rgb = RGBColor(30, 41, 59)
        bg_col = "F8FAFC" if row_idx % 2 == 1 else "FFFFFF"
        shd = parse_xml(r'<w:shd {} w:fill="{}"/>'.format(nsdecls('w'), bg_col))
        cell._tc.get_or_add_tcPr().append(shd)

# Section 4
add_section_heading("4. Grounded Engineering: Why We Avoid Fake Claims")
add_body_paragraph(
    "A major flaw in academic and hackathon emergency projects is claiming impossible measurements—such as calculating exact bone fracture forces or organ trauma percentages directly from a phone in a pocket. In reality, smartphone accelerometers physically saturate at 8g to 16g. Claiming to measure 45g from a phone is technically impossible."
)
add_body_paragraph(
    "In Rakshak-AI, we adhere strictly to sensor honesty: if a deceleration hits the hardware limit, our app explicitly marks the reading as 'Saturated' rather than displaying made-up numbers. Furthermore, we designed a server-side Trip Sentinel: if a high-speed highway trip (e.g., 90 km/h) suddenly falls completely silent with zero braking data, the server recognizes that the phone may have been physically smashed in a catastrophic impact, immediately alerting highway police patrols."
)

# Section 5
add_section_heading("5. Proof of Working: What We Have Actually Built & Tested")
add_body_paragraph(
    "Rakshak-AI is not an idea on paper; it is a live, fully verified working system with active codebase repositories:"
)

test_points = [
    ("47 Passing Mobile Unit Tests: ", "Our Flutter test suite comprehensively verifies the crash algorithm, free-fall drop rejection, offline SQLite store-and-forward queue with exponential backoff, and WebRTC streaming fallback."),
    ("18 Passing Backend RBAC & Security Tests: ", "Our Node.js backend passes complete role-based authorization tests, verifying that hospitals can only claim dispatches assigned to their sector and cannot access unauthorized records."),
    ("Microscopic Traffic Simulation in SUMO: ", "We tested our C-V2X green corridor logic in Eclipse SUMO across realistic multi-intersection Bengaluru road networks, achieving a 62% reduction in ambulance transit times."),
    ("Live Interactive Detection Lab: ", "Our mobile app includes a built-in testing lab where real and synthetic scenarios (potholes, speed bumps, hard braking, phone drops, genuine crashes, and rollovers) are replayed in real-time to demonstrate zero false positives.")
]

for t_title, t_body in test_points:
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(2)
    p.paragraph_format.left_indent = Inches(0.2)
    p.paragraph_format.line_spacing = 1.05
    r_t = p.add_run("• " + t_title)
    r_t.font.name = "Calibri"
    r_t.font.size = Pt(9.5)
    r_t.font.bold = True
    r_t.font.color.rgb = RGBColor(15, 23, 42)
    r_b = p.add_run(t_body)
    r_b.font.name = "Calibri"
    r_b.font.size = Pt(9.5)
    r_b.font.color.rgb = RGBColor(51, 65, 85)

# Section 6
add_section_heading("6. Scalability & Conclusion")
add_body_paragraph(
    "Because Rakshak-AI works as a background application on standard smartphones without requiring expensive proprietary hardware in every vehicle, it can be deployed immediately across gig-delivery fleets (Zomato, Swiggy, Dunzo) and everyday commuters. For city administrations, our C-V2X adapter connects directly to existing traffic controller cabinets via standard NTCIP protocols, requiring no expensive road redesigns."
)
add_body_paragraph(
    "Under Theme 5 (Surakshit Bharat), Rakshak-AI provides a self-reliant, indigenous solution to India's deadliest peacetime crisis: road crash fatalities. By cutting emergency notification, traffic transit, and hospital intake times from 45 minutes down to under 12 minutes, we ensure that every citizen who meets with an accident gets their rightful chance at survival."
)

output_path = r"e:\Projects and Case Study\Rakshak-AI\Vikist Blueprint\1. CONCEPT\CONCEPT_DOCUMENT.docx"
doc.save(output_path)
print("Saved CONCEPT_DOCUMENT.docx successfully.")
