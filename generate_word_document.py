import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

def set_cell_background(cell, fill_hex):
    """Sets the background color of a table cell."""
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'), 'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'), fill_hex)
    tc_pr.append(shd)

def set_cell_margins(cell, top=100, bottom=100, left=150, right=150):
    """Sets internal padding for a cell (in dxa: 20 dxa = 1 pt)."""
    tc_pr = cell._tc.get_or_add_tcPr()
    tc_mar = OxmlElement('w:tcMar')
    for m, val in [('w:top', top), ('w:bottom', bottom), ('w:left', left), ('w:right', right)]:
        node = OxmlElement(m)
        node.set(qn('w:w'), str(val))
        node.set(qn('w:type'), 'dxa')
        tc_mar.append(node)
    tc_pr.append(tc_mar)

def create_document():
    doc = docx.Document()

    # Page Margins: 0.8 inches all around
    sections = doc.sections
    for section in sections:
        section.top_margin = Inches(0.8)
        section.bottom_margin = Inches(0.8)
        section.left_margin = Inches(0.8)
        section.right_margin = Inches(0.8)
        
        # Header
        header = section.header
        hp = header.paragraphs[0]
        hp.alignment = WD_ALIGN_PARAGRAPH.RIGHT
        hrun = hp.add_run("GATEWAYS 2026 | Round 1 Ideation Document")
        hrun.font.name = "Calibri"
        hrun.font.size = Pt(8.5)
        hrun.font.color.rgb = RGBColor(148, 163, 184) # subtle gray

        # Footer
        footer = section.footer
        fp = footer.paragraphs[0]
        fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
        frun = fp.add_run("Rakshak-AI — Autonomous Emergency Trauma Response System  |  Page 1")
        frun.font.name = "Calibri"
        frun.font.size = Pt(8.5)
        frun.font.color.rgb = RGBColor(148, 163, 184)

    # Styles
    normal_style = doc.styles['Normal']
    normal_style.font.name = 'Calibri'
    normal_style.font.size = Pt(10.5)
    normal_style.font.color.rgb = RGBColor(30, 41, 59) # Slate 800

    # Title Banner
    title_p = doc.add_paragraph()
    title_p.paragraph_format.space_before = Pt(0)
    title_p.paragraph_format.space_after = Pt(2)
    title_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    t_run = title_p.add_run("GATEWAYS 2026")
    t_run.font.name = "Calibri"
    t_run.font.size = Pt(24)
    t_run.font.bold = True
    t_run.font.color.rgb = RGBColor(15, 23, 42) # Deep Navy

    sub_p = doc.add_paragraph()
    sub_p.paragraph_format.space_before = Pt(0)
    sub_p.paragraph_format.space_after = Pt(8)
    sub_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    s_run = sub_p.add_run("Round 1 — Ideation & Architecture Document")
    s_run.font.name = "Calibri"
    s_run.font.size = Pt(13)
    s_run.font.bold = True
    s_run.font.color.rgb = RGBColor(37, 99, 235) # Royal Blue Accent

    # Divider line
    div_p = doc.add_paragraph()
    div_p.paragraph_format.space_before = Pt(0)
    div_p.paragraph_format.space_after = Pt(10)
    div_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    div_run = div_p.add_run("―" * 65)
    div_run.font.color.rgb = RGBColor(203, 213, 225)

    # Submission instruction note
    inst_p = doc.add_paragraph()
    inst_p.paragraph_format.space_before = Pt(0)
    inst_p.paragraph_format.space_after = Pt(14)
    i_run = inst_p.add_run("To be submitted by every team for Round 1. Keep it clear and specific and include all the necessary points.")
    i_run.font.italic = True
    i_run.font.size = Pt(9.5)
    i_run.font.color.rgb = RGBColor(100, 116, 139)

    # Helper for adding styled section headers
    def add_section_header(num_title):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(16)
        p.paragraph_format.space_after = Pt(6)
        p.paragraph_format.keep_with_next = True
        run = p.add_run(num_title)
        run.font.name = "Calibri"
        run.font.size = Pt(13.5)
        run.font.bold = True
        run.font.color.rgb = RGBColor(15, 23, 42)
        return p

    def add_prompt_italics(text):
        p = doc.add_paragraph()
        p.paragraph_format.space_before = Pt(0)
        p.paragraph_format.space_after = Pt(6)
        run = p.add_run(text)
        run.font.italic = True
        run.font.size = Pt(9.5)
        run.font.color.rgb = RGBColor(100, 116, 139)
        return p

    # ==========================================
    # 1. TEAM DETAILS
    # ==========================================
    add_section_header("1. Team Details")

    table = doc.add_table(rows=4, cols=2)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False

    col_widths = [Inches(2.2), Inches(4.7)]
    for row in table.rows:
        for idx, width in enumerate(col_widths):
            row.cells[idx].width = width

    # Table Header
    hdr_cells = table.rows[0].cells
    hdr_cells[0].text = "Field"
    hdr_cells[1].text = "Details"
    for cell in hdr_cells:
        set_cell_background(cell, "1E293B") # Dark slate
        set_cell_margins(cell, top=140, bottom=140, left=180, right=180)
        for p in cell.paragraphs:
            p.alignment = WD_ALIGN_PARAGRAPH.LEFT
            for r in p.runs:
                r.font.bold = True
                r.font.color.rgb = RGBColor(255, 255, 255)
                r.font.size = Pt(10)

    # Row 1: Team Name
    r1 = table.rows[1].cells
    r1[0].text = "Team Name"
    r1[1].text = "Team Rakshak (रक्षक)"
    
    # Row 2: Problem Statement Chosen
    r2 = table.rows[2].cells
    r2[0].text = "Problem Statement Chosen"
    r2[1].text = "Smart Healthcare & Autonomous Emergency Trauma Response System"

    # Row 3: Team Members
    r3 = table.rows[3].cells
    r3[0].text = "Team Members (Name, Reg No., Role)"
    r3[1].text = (
        "1. Stevin Joseph B (Reg No: [Your Reg No]) — Team Lead & Full-Stack Architect\n"
        "2. [Team Member 2] (Reg No: [Reg No]) — Mobile Telemetry & Sensor Systems\n"
        "3. [Team Member 3] (Reg No: [Reg No]) — Backend & Distributed Systems\n"
        "4. [Team Member 4] (Reg No: [Reg No]) — UI/UX & Cloud Infrastructure"
    )

    for row_idx, row in enumerate(table.rows[1:], start=1):
        bg_col = "F8FAFC" if row_idx % 2 == 1 else "FFFFFF"
        for cell_idx, cell in enumerate(row.cells):
            set_cell_background(cell, bg_col)
            set_cell_margins(cell, top=120, bottom=120, left=180, right=180)
            for p in cell.paragraphs:
                p.paragraph_format.space_before = Pt(0)
                p.paragraph_format.space_after = Pt(2)
                for r in p.runs:
                    r.font.size = Pt(9.5)
                    if cell_idx == 0:
                        r.font.bold = True
                        r.font.color.rgb = RGBColor(30, 41, 59)
                    else:
                        r.font.color.rgb = RGBColor(51, 65, 85)

    doc.add_paragraph().paragraph_format.space_after = Pt(4)

    # ==========================================
    # 2. PROBLEM UNDERSTANDING
    # ==========================================
    add_section_header("2. Problem Understanding")
    add_prompt_italics("In your own words: what is the real-world problem, who faces it, and why does it matter?")

    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(6)
    p.paragraph_format.line_spacing = 1.15
    run = p.add_run("In trauma medicine, the ")
    run = p.add_run("Golden Hour ")
    run.bold = True
    p.add_run(
        "is the crucial 60-minute window immediately following a severe vehicular collision. "
        "Receiving advanced surgical or intensive care within this window increases a trauma victim's survival rate by over 80%. "
        "However, today’s emergency response pipeline suffers from three fatal, systemic breakdowns:\n"
    )

    bullet_points = [
        ("Delayed Crash Detection & Bystander Hesitation: ", 
         "Victims are frequently unconscious or pinned inside wreckage. Traditional dispatch depends entirely on an eyewitness stopping, guessing the exact location coordinates, and placing a voice call to emergency numbers (108/112). This introduces a fatal 10 to 15-minute lag."),
        ("Blind Hospital Routing & Bed Refusal: ", 
         "Ambulances rush victims blindly to the nearest general clinic rather than an accredited trauma center equipped with active ICU ventilators and on-duty neurosurgeons. When the ambulance arrives at an unprepared or full hospital, the victim is turned away, wasting the remainder of the Golden Hour during secondary transfers."),
        ("Bystander Privacy & Legal Hesitation: ", 
         "Good Samaritans hesitate to photograph accident scenes or get involved due to fear of privacy violations, police questioning, or having their personal phone gallery inspected."),
        ("Zero Pre-Arrival Clinical Preparation: ", 
         "Hospital emergency departments (ED) operate blind until the ambulance physically pulls into the trauma bay. Crucial minutes are lost cross-matching blood units, assembling trauma surgeons, and clearing emergency operating theaters (OT).")
    ]

    for title, desc in bullet_points:
        bp = doc.add_paragraph(style='List Bullet')
        bp.paragraph_format.space_before = Pt(2)
        bp.paragraph_format.space_after = Pt(4)
        bp.paragraph_format.line_spacing = 1.15
        trun = bp.add_run(title)
        trun.bold = True
        trun.font.color.rgb = RGBColor(15, 23, 42)
        drun = bp.add_run(desc)
        drun.font.color.rgb = RGBColor(51, 65, 85)

    p_stat = doc.add_paragraph()
    p_stat.paragraph_format.space_before = Pt(4)
    p_stat.paragraph_format.space_after = Pt(6)
    p_stat.paragraph_format.line_spacing = 1.15
    run = p_stat.add_run("Scale & Impact: ")
    run.bold = True
    p_stat.add_run(
        "In India, over 168,000 citizens die annually on roads (1 death every 3.5 minutes), with two-wheeler riders accounting for 44% of fatalities. "
        "Globally, road traffic crashes claim 1.19 million lives every year (WHO) and cost nations between 2% and 3.5% of their total GDP."
    )

    # ==========================================
    # 3. PROPOSED SOLUTION — OVERVIEW
    # ==========================================
    add_section_header("3. Proposed Solution — Overview")
    add_prompt_italics("A short summary of what you are building and how it solves the problem. Avoid tech jargon here — this should be understandable to a non-technical judge.")

    p_sol = doc.add_paragraph()
    p_sol.paragraph_format.space_before = Pt(2)
    p_sol.paragraph_format.space_after = Pt(6)
    p_sol.paragraph_format.line_spacing = 1.15
    p_sol.add_run(
        "Rakshak-AI (रक्षक-AI) is an autonomous emergency response and hospital triage network that connects crash victims, "
        "hospitals, and traffic police within seconds. Instead of waiting for a bystander to make a phone call, Rakshak-AI uses "
        "the sensors already inside standard smartphones to turn every phone into an autonomous crash detector.\n\n"
        "The moment a severe vehicular collision occurs, Rakshak-AI executes a four-step life-saving response:"
    )

    sol_steps = [
        ("1. Autonomous Impact Confirmation: ", "Detects high-G deceleration and sudden velocity drop, sounding a 10-second auditory countdown on the phone to allow conscious riders to cancel accidental triggers."),
        ("2. Intelligent Hospital Matching: ", "Instantly identifies accredited trauma centers within the local radius based on real road driving distance and actual ICU capacity, rather than sending victims blindly to unprepared clinics."),
        ("3. Pre-Arrival Bed Reservation & Case Locking: ", "Sends an alert to nearby hospital emergency desks. The moment a hospital accepts, the emergency bed is digitally locked, preventing double-booking and ensuring doctors and blood units are prepped before the patient arrives."),
        ("4. Zero-Storage Visual Triage: ", "Allows bystanders to point their camera at the scene to stream pre-arrival injury visuals directly to emergency surgeons. The photo is never saved to the bystander’s phone gallery and is automatically erased from the system after the emergency, ensuring total privacy."),
        ("5. Synchronized Police Dispatch: ", "Simultaneously alerts police control rooms with exact coordinates and the assigned hospital to enable green traffic corridors for the ambulance.")
    ]

    for title, desc in sol_steps:
        sp = doc.add_paragraph(style='List Bullet')
        sp.paragraph_format.space_before = Pt(2)
        sp.paragraph_format.space_after = Pt(4)
        sp.paragraph_format.line_spacing = 1.15
        trun = sp.add_run(title)
        trun.bold = True
        trun.font.color.rgb = RGBColor(15, 23, 42)
        drun = sp.add_run(desc)
        drun.font.color.rgb = RGBColor(51, 65, 85)

    # ==========================================
    # 4. SYSTEM ARCHITECTURE
    # ==========================================
    add_section_header("4. System Architecture")
    add_prompt_italics("Describe or diagram your system: the main components/agents, what each one is responsible for, and how information flows between them. Paste or attach your architecture diagram below.")

    p_arch_intro = doc.add_paragraph()
    p_arch_intro.paragraph_format.space_before = Pt(2)
    p_arch_intro.paragraph_format.space_after = Pt(6)
    p_arch_intro.paragraph_format.line_spacing = 1.15
    p_arch_intro.add_run(
        "Rakshak-AI is built on an event-driven, distributed microservices architecture designed for sub-second emergency routing, "
        "high fault tolerance, and zero-storage privacy guarantees."
    )

    # Architecture Diagram Box
    diag_table = doc.add_table(rows=1, cols=1)
    diag_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    diag_cell = diag_table.rows[0].cells[0]
    diag_cell.width = Inches(6.9)
    set_cell_background(diag_cell, "0F172A") # Deep Navy Slate
    set_cell_margins(diag_cell, top=140, bottom=140, left=180, right=180)

    diag_p = diag_cell.paragraphs[0]
    diag_p.paragraph_format.space_before = Pt(0)
    diag_p.paragraph_format.space_after = Pt(0)
    d_run = diag_p.add_run(
        "+-----------------------------------------------------------------------------------------+\n"
        "|                              RAKSHAK-AI SYSTEM ARCHITECTURE                             |\n"
        "+-----------------------------------------------------------------------------------------+\n"
        "                                                                                           \n"
        "  [ MOBILE CLIENT: Flutter / Dart ]                                                        \n"
        "   - Dual-Signature Impact Engine (Sensors Plus: Accelerometer + Gyroscope)                \n"
        "   - Zero-Gallery Camera Pipeline (Direct RAM Buffer Uint8List)                            \n"
        "   - Incident Channel Subscriber (Socket.io-client)                                        \n"
        "          |                                  |                                             \n"
        "          | (Crash Telemetry & SOS)          | (Ephemeral Binary Image Stream)             \n"
        "          v                                  v                                             \n"
        "  [ CORE INGESTION GATEWAY: Node.js + Express + TypeScript ]                               \n"
        "   - Telemetry Validation (Zod Schemas)                                                    \n"
        "   - Bi-directional Real-Time Room Isolation (Socket.io)                                   \n"
        "   - Atomic Mutual-Exclusion Bed Lock (PostgreSQL Guarded Transactions)                    \n"
        "          |                                  |                                             \n"
        "          +------------+                     +------------------+                          \n"
        "          |            |                                        |                          \n"
        "          v            v                                        v                          \n"
        "  [ SPATIAL TRIAGE ] [ EPHEMERAL BROKER ]             [ DATABASE & SPATIAL ENGINE ]        \n"
        "   Python FastAPI     Redis 7 In-Memory                PostgreSQL 16 + PostGIS 3.4         \n"
        "   Spatial AI Engine  --save '' --appendonly no        Spatial Indexing (GIST)             \n"
        "   Road Winding Fact. 15-min TTL RAM Buffer            ST_DWithin & Road Distance Calc     \n"
        "          |                    |                                                           \n"
        "          +--------------------+                                                           \n"
        "                    |                                                                      \n"
        "                    v                                                                      \n"
        "  [ REAL-TIME WEB COMMAND CONSOLES: React 18 + Vite + TypeScript ]                         \n"
        "   - Hospital ER Console: Audio Klaxon + Vitals + Pre-arrival Photo + Accept/Reject        \n"
        "   - Police Central Command: Citywide Heatmap + Live Incident Badges + Dispatch Matrix     \n"
        "+-----------------------------------------------------------------------------------------+"
    )
    d_run.font.name = "Consolas"
    d_run.font.size = Pt(7.5)
    d_run.font.color.rgb = RGBColor(226, 232, 240)

    doc.add_paragraph().paragraph_format.space_after = Pt(4)

    arch_components = [
        ("Mobile Telemetry Client (Flutter / Dart): ", "Monitors accelerometer, gyroscope, and GPS in background. Detects crash patterns, executes countdown alert, captures in-memory scene photos, and subscribes to incident-specific WebSocket rooms."),
        ("API Gateway & WebSocket Server (Node.js / Express / Socket.io): ", "High-throughput ingestion layer. Employs room isolation: 'hospital:<id>' for targeted alerts, 'all_incidents' for police command, and 'incident:<id>' for mobile updates. Executes atomic case locking."),
        ("Geospatial Spatial-Triage Service (Python FastAPI & PostGIS): ", "Calculates actual road driving distances using PostGIS geodesic functions with urban winding multipliers (1.6x) and matches victim severity against hospital trauma center accreditations."),
        ("Ephemeral Zero-Storage Cache (Redis 7): ", "Operates with persistence strictly disabled (--save '' --appendonly no). Caches raw image buffers with a 15-minute TTL. Images evaporate upon resolution with zero physical disk writes."),
        ("Cascading Auto-Escalation Engine: ", "Automated state machine. If matched hospitals reject or do not respond within 45 seconds, widens search radius from 8 km to 20 km, then city-wide, before alerting central police command."),
        ("Web Command Consoles (React 18 / Vite / TypeScript): ", "Dedicated low-latency interfaces for hospital emergency rooms and police traffic headquarters with real-time audio-visual trauma dispatching.")
    ]

    for title, desc in arch_components:
        cp = doc.add_paragraph(style='List Bullet')
        cp.paragraph_format.space_before = Pt(2)
        cp.paragraph_format.space_after = Pt(4)
        cp.paragraph_format.line_spacing = 1.15
        trun = cp.add_run(title)
        trun.bold = True
        trun.font.color.rgb = RGBColor(15, 23, 42)
        drun = cp.add_run(desc)
        drun.font.color.rgb = RGBColor(51, 65, 85)

    # ==========================================
    # 5. TECH STACK
    # ==========================================
    add_section_header("5. Tech Stack")
    add_prompt_italics("List the languages, frameworks, models/APIs, and tools you plan to use. Choice of technology is entirely up to your team.")

    stack_table = doc.add_table(rows=8, cols=3)
    stack_table.alignment = WD_TABLE_ALIGNMENT.CENTER
    stack_table.autofit = False

    stack_widths = [Inches(1.8), Inches(2.2), Inches(2.9)]
    for row in stack_table.rows:
        for idx, width in enumerate(stack_widths):
            row.cells[idx].width = width

    st_hdr = stack_table.rows[0].cells
    st_hdr[0].text = "Layer"
    st_hdr[1].text = "Technologies"
    st_hdr[2].text = "Role & Justification"
    for cell in st_hdr:
        set_cell_background(cell, "1E293B")
        set_cell_margins(cell, top=120, bottom=120, left=150, right=150)
        for p in cell.paragraphs:
            for r in p.runs:
                r.font.bold = True
                r.font.color.rgb = RGBColor(255, 255, 255)
                r.font.size = Pt(9.5)

    stack_data = [
        ("Mobile Client", "Flutter 3.x, Dart 3.x", "Cross-platform mobile engine delivering 60fps performance and direct low-level sensor access."),
        ("Sensors & Hardware", "sensors_plus, geolocator, image_picker", "High-frequency accelerometer and gyroscope polling, high-precision GPS, and in-memory photo capture."),
        ("Backend & REST API", "Node.js, Express, TypeScript, Zod", "Asynchronous, type-safe API ingestion gateway handling telemetry packets and schema validation."),
        ("Real-Time Engine", "Socket.io 4.8", "Bi-directional WebSocket streaming with room isolation for targeted multi-hospital broadcasting."),
        ("Geospatial & Database", "PostgreSQL 16, PostGIS 3.4", "Spatial indexing (GIST), geodesic distance calculation (ST_DWithin), and transactional state management."),
        ("Triage Microservice", "Python 3.10+, FastAPI, Uvicorn", "High-concurrency async service for spatial clustering, hospital ranking, and road distance calculation."),
        ("Ephemeral Cache", "Redis 7 (Alpine Linux)", "Diskless RAM cache (--save '' --appendonly no) with 15-min TTL for privacy-compliant photo streaming.")
    ]

    for idx, (layer, tech, role) in enumerate(stack_data, start=1):
        row_cells = stack_table.rows[idx].cells
        row_cells[0].text = layer
        row_cells[1].text = tech
        row_cells[2].text = role
        bg_col = "F8FAFC" if idx % 2 == 1 else "FFFFFF"
        for cell_idx, cell in enumerate(row_cells):
            set_cell_background(cell, bg_col)
            set_cell_margins(cell, top=100, bottom=100, left=150, right=150)
            for p in cell.paragraphs:
                p.paragraph_format.space_before = Pt(0)
                p.paragraph_format.space_after = Pt(2)
                for r in p.runs:
                    r.font.size = Pt(9)
                    if cell_idx == 0:
                        r.font.bold = True
                        r.font.color.rgb = RGBColor(30, 41, 59)
                    elif cell_idx == 1:
                        r.font.bold = True
                        r.font.color.rgb = RGBColor(37, 99, 235)
                    else:
                        r.font.color.rgb = RGBColor(51, 65, 85)

    doc.add_paragraph().paragraph_format.space_after = Pt(4)

    # ==========================================
    # 7. HANDLING EDGE CASES & FOLLOW-UPS
    # ==========================================
    add_section_header("7. Handling Edge Cases & Follow-ups")
    add_prompt_italics("Every problem statement includes a 'points to think about' section. Explain how your system is designed to handle at least one of those situations (e.g., missing/conflicting information, a change mid-process, an ambiguous request).")

    edge_cases = [
        ("A. False Positive Suppression (Dropped Phones, Severe Potholes & Roller Coasters)",
         "Problem: Phone drops or aggressive driving over potholes produce sudden G-force spikes that could trigger false alarms.\n"
         "Design Solution: Rakshak-AI uses a Dual-Signature Sensor Fusion Algorithm. An accident is only confirmed if a high-G impact (> 5.0G) is accompanied by an instantaneous velocity drop to 0 km/h within 150 ms. A dropped phone while walking has zero preceding vehicular speed, while a pothole has continuous forward momentum. Furthermore, a 10-second auditory countdown alert allows conscious riders to cancel accidental triggers."),

        ("B. Race Conditions: Simultaneous Hospital Acceptance (Double-Booking Prevention)",
         "Problem: Two trauma centers click 'Accept' simultaneously, risking conflicting patient routing.\n"
         "Design Solution: PostgreSQL Atomic Mutual Exclusion. Acceptance uses an atomic guarded transaction: "
         "'UPDATE incidents SET status = 'accepted', accepted_hospital_id = $1 WHERE id = $2 AND status IN ('broadcasting', 'escalated') RETURNING *'. "
         "The first transaction succeeds (200 OK), while the second affects 0 rows and immediately returns 409 Conflict. The server broadcasts 'case_locked' to other hospitals, disabling their action buttons and locking the case in real time."),

        ("C. Hospital Overcrowding & Rejection (Cascading Auto-Escalation)",
         "Problem: The closest trauma centers have no ICU beds or on-duty surgeons available.\n"
         "Design Solution: Multi-Tier Auto-Escalation Engine. If all matched hospitals reject the incident, or if an automated 45-second timer expires without acceptance, the system automatically expands the search radius from 8 km to 20 km (Stage 1), and then registry-wide (Stage 2). If no private facility accepts, the status transitions to 'unmatched', triggering high-urgency alarms at the central police command for state emergency ambulance deployment."),

        ("D. Poor Cellular Connectivity & Highway Dead Zones",
         "Problem: Accidents frequently happen in areas with intermittent or degraded 2G/3G connectivity.\n"
         "Design Solution: The mobile telemetry engine logs crash packets into an encrypted local SQLite buffer. Upon cellular re-handshake, packets are transmitted with priority queuing. On the hospital side, if dashboard WebSockets disconnect, the backend automatically triggers an automated IVR telephone call and flash SMS to the ER head nurse.")
    ]

    for title, desc in edge_cases:
        ep = doc.add_paragraph()
        ep.paragraph_format.space_before = Pt(4)
        ep.paragraph_format.space_after = Pt(2)
        ep.paragraph_format.line_spacing = 1.15
        trun = ep.add_run(title)
        trun.bold = True
        trun.font.color.rgb = RGBColor(15, 23, 42)

        desc_p = doc.add_paragraph()
        desc_p.paragraph_format.space_before = Pt(0)
        desc_p.paragraph_format.space_after = Pt(6)
        desc_p.paragraph_format.line_spacing = 1.15
        drun = desc_p.add_run(desc)
        drun.font.color.rgb = RGBColor(51, 65, 85)

    # ==========================================
    # 8. WHAT MAKES THIS ORIGINAL
    # ==========================================
    add_section_header("8. What Makes This Original")
    add_prompt_italics("What is different or thoughtful about your approach, compared to an obvious/first-guess solution?")

    p_orig = doc.add_paragraph()
    p_orig.paragraph_format.space_before = Pt(2)
    p_orig.paragraph_format.space_after = Pt(6)
    p_orig.paragraph_format.line_spacing = 1.15
    p_orig.add_run(
        "Compared to traditional emergency apps or naive hackathon prototypes that merely dial emergency helplines, "
        "Rakshak-AI introduces four fundamental engineering and procedural innovations:"
    )

    originality_pillars = [
        ("1. Pure Software-Driven Telemetry (Zero Hardware Barrier): ", 
         "Conventional crash response systems (like Bosch eCall or OnStar) require expensive proprietary OBD-II dongles or factory-installed car hardware. Rakshak-AI runs entirely on existing smartphones, democratizing automotive-grade crash safety for two-wheeler riders who represent 75% of Indian vehicles."),

        ("2. Ephemeral Zero-Storage Architecture (True Bystander Privacy): ", 
         "First-guess solutions upload crash photos to permanent cloud buckets (AWS S3), exposing bystanders and victims to severe legal and privacy liabilities under India’s Digital Personal Data Protection (DPDP) Act 2023. Rakshak-AI streams images directly through volatile RAM (diskless Redis) with a 15-minute TTL. Images evaporate upon resolution, guaranteeing that zero photos are saved to the bystander’s camera roll or written to physical server disks."),

        ("3. Closed-Loop Hospital Bed Locking vs. Open-Loop Calling: ", 
         "Apple Crash Detection and Life360 are open-loop systems: they send an SMS or call 108/911 and terminate. They have zero visibility into hospital beds. Rakshak-AI is a closed-loop medical coordination system: it tracks hospital trauma accreditations, streams pre-arrival visuals to surgeons, and locks the trauma bed before the ambulance arrives."),

        ("4. Road-Winding Spatial Geodesics vs. Naive As-The-Crow-Flies Radius: ", 
         "First-guess prototypes calculate straight-line Euclidean distance ('5 km radius'), which frequently recommends hospitals separated by rivers, railway lines, or highway dividers that take 45 minutes to cross. Rakshak-AI uses PostGIS geodesic algorithms combined with urban road network winding coefficients (1.6x) to route victims to the fastest hospital by driving time, not geographic coordinates.")
    ]

    for title, desc in originality_pillars:
        op = doc.add_paragraph(style='List Bullet')
        op.paragraph_format.space_before = Pt(2)
        op.paragraph_format.space_after = Pt(4)
        op.paragraph_format.line_spacing = 1.15
        trun = op.add_run(title)
        trun.bold = True
        trun.font.color.rgb = RGBColor(15, 23, 42)
        drun = op.add_run(desc)
        drun.font.color.rgb = RGBColor(51, 65, 85)

    # Save Document
    target_path = r"e:\Projects and Case Study\Rakshak-AI\GATEWAYS_2026_Rakshak_AI_Round_1.docx"
    doc.save(target_path)
    print(f"Document successfully created at: {target_path}")

if __name__ == "__main__":
    create_document()
