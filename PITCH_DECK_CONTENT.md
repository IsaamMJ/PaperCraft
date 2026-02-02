# PAPERCRAFT — Investor Pitch Deck Content

---

## SLIDE 1: Title & One-Liner

**Papercraft**

*The operating system for school exams — from paper creation to marks entry, all in one place.*

- Version 2.1 | Web + Android + iOS
- Built for Indian K-12 schools (scalable globally)

---

## SLIDE 2: The Problem

**Creating question papers in schools is a broken, manual, and stressful process.**

- Teachers write papers in Microsoft Word or by hand — no structure, no consistency
- Principals and reviewers receive papers manually — no tracking, no version control
- Papers get lost, duplicated, or leaked before exams
- No standard format across grades or subjects — every teacher does it differently
- Printing is chaotic — office staff re-types or reformats papers manually
- Exam timetables are managed on spreadsheets or notice boards — zero integration with paper creation
- After exams, marks are recorded in physical registers — no digital trail, no analytics
- Schools run 6–10 exam cycles per year — this pain repeats every single time

**The result:** Teachers waste 5–8 hours per exam cycle on paper creation alone. Schools have zero visibility into quality, progress, or completion.

---

## SLIDE 3: The Solution

**Papercraft digitizes the entire exam lifecycle — create, review, approve, print, and track marks — in a single workflow.**

- **Teachers** create structured question papers using a guided, section-by-section builder
- **Reviewers** approve or reject papers with feedback — no WhatsApp, no printouts
- **Office staff** generate print-ready PDFs in one click
- **Admins** set up exam calendars, timetables, and teacher assignments — papers auto-assign to teachers
- **Marks entry** happens digitally, linked to the exact exam and student

**One system replaces:** Word documents + WhatsApp groups + printed registers + Excel timetables + manual coordination.

---

## SLIDE 4: Product Features & Workflow

### Paper Creation Engine
- Guided multi-step paper builder (details → sections → questions → preview → submit)
- 8+ question types supported out of the box:
  - Multiple Choice (MCQ)
  - Short Answer
  - Essay (with sub-questions)
  - Fill in the Blanks (with shared word bank)
  - True / False
  - Match the Following
  - Word Forms & Missing Letters
  - Bulk Input (paste multiple questions at once)
- Section-level configuration: set question count, marks per question, total marks
- AI-powered question polish — improve language and clarity with one tap
- Real-time validation — catch errors before submission
- Draft saving — local (offline) + cloud sync

### Review & Approval Workflow
- Papers move through a clear pipeline: **Draft → Submitted → Approved / Rejected / Spare**
- Primary and secondary reviewers assigned by grade range
- Rejection includes written feedback — teachers fix and resubmit
- Notifications on every status change (in-app)

### Exam Timetable System
- Create exam calendars for the academic year (monthly tests, mid-terms, finals)
- Multi-step timetable wizard: select grades → set dates/times → assign subjects → configure marks
- Auto-detects conflicts (same grade, overlapping times)
- Auto-creates papers linked to timetable entries — teachers just fill in questions
- Marks configuration per grade range (e.g., Grades 1–5: 25 marks, Grades 6–12: 60 marks)
- Publish timetable to all teachers with one click

### Student Marks Entry
- Digital marks entry per student, per exam
- Attendance tracking (present / absent / medical leave)
- Draft and finalize modes
- Linked to timetable entries for full traceability

### PDF Generation & Printing
- One-click PDF generation from any approved paper
- A4 format, clean layout, customizable font sizes and spacing
- Supports all question types with proper formatting (word banks, matching pairs, option grids)
- Batch processing for office staff
- Print directly or download/share

### Admin & Setup
- Multi-tenant architecture — each school is fully isolated
- Admin setup wizard: grades, sections (A/B/C), subjects (core/auxiliary), teacher assignments
- Role-based access: Admin, Director, Teacher, Reviewer, Office Staff, Student
- Grade-section-subject mapping for precise assignment control

---

## SLIDE 5: How It Works (User Journey)

```
ADMIN sets up school
    ↓
ADMIN creates exam calendar & timetable
    ↓
Papers auto-assigned to TEACHERS based on their subject assignments
    ↓
TEACHER creates paper using guided builder
    ↓
TEACHER submits paper for review
    ↓
REVIEWER approves or rejects (with feedback)
    ↓
OFFICE STAFF generates print-ready PDFs
    ↓
Exams happen
    ↓
TEACHER enters student marks digitally
    ↓
ADMIN has full visibility — papers, marks, progress
```

---

## SLIDE 6: Traction & Validation

- **Product is live** — Version 2.1.0, build 29
- **Production-ready infrastructure** with Supabase (PostgreSQL), Firebase Crashlytics, and Google OAuth
- **38 database migrations** shipped — reflects continuous iteration based on real usage
- **Production readiness documentation** completed (stress tests, FK constraint verification, publish flow testing)
- **Multi-platform** — runs on Web, Android, and iOS from a single codebase
- **Real exam workflows tested** — monthly tests, half-yearly, and final exams
- **Active development** — recent features include student marks entry, timetable publishing, and exam auto-assignment

*(Note to founder: Add specific numbers here as you gather them — number of schools, teachers, papers created, exams conducted. Even 2–3 pilot schools with real data is powerful for early-stage.)*

---

## SLIDE 7: Target Market

### Primary Market
- **Indian K-12 private schools** — estimated 400,000+ schools
- Schools with Grades 1–12, multiple sections (A/B/C), 10–50 teachers
- Schools running 6–10 exam cycles per academic year

### Why Now
- Schools are rapidly digitizing post-COVID — but exam creation is still analog
- NEP 2020 pushes for continuous assessment — more exams = more paper creation pain
- No dominant player in this specific niche

### Expansion Path
- **Phase 1:** English-medium private schools in Tier 1 & 2 cities
- **Phase 2:** CBSE / ICSE / State Board schools across India
- **Phase 3:** International schools, coaching institutes, competitive exam prep
- **Phase 4:** Regional language support, government schools

### Market Size (India alone)
- 400,000 private schools × average subscription potential = large addressable market
- Each school = recurring annual revenue (SaaS model)

---

## SLIDE 8: Business Model

### SaaS Subscription (Primary)
- **Free tier:** 1 teacher, limited papers per month — for trial and onboarding
- **School Plan:** Per-school annual subscription based on number of teachers/grades
  - Small school (up to 20 teachers): entry pricing
  - Large school (50+ teachers): premium pricing
- **Includes:** All features, PDF generation, marks entry, timetable management

### Add-on Revenue Streams
- **AI Question Polish** — usage-based pricing for AI-assisted question improvement
- **Question Bank Access** — premium access to curated, approved question papers across grades and subjects
- **Analytics & Reports** — advanced exam analytics, student performance trends
- **White-label** — school branding on printed papers

### Why SaaS Works Here
- Exams are recurring (6–10 times/year) — schools need this every month
- Once adopted by admin, every teacher in the school uses it — built-in expansion
- Switching cost is high after 1 year of papers and marks data

---

## SLIDE 9: Competitive Advantage

### vs. Microsoft Word / Google Docs
- No structure, no review workflow, no version control
- Papercraft provides guided creation, built-in approval pipeline, and print-ready output

### vs. WhatsApp / Email Coordination
- No tracking, papers get lost in chat threads
- Papercraft gives real-time status tracking and role-based notifications

### vs. Generic School ERP Systems (Teachmint, Fedena, etc.)
- ERPs focus on attendance, fees, communication — exam paper creation is an afterthought
- Papercraft goes deep on the exam workflow — from paper design to marks entry

### vs. Question Bank Websites
- They provide pre-made questions, not a creation + review + approval workflow
- Papercraft lets teachers create original papers with quality control built in

### Moat
- **Workflow depth** — not just creation, but review → approval → print → marks in one flow
- **Multi-role system** — admin, teacher, reviewer, office staff all have purpose-built interfaces
- **Data lock-in** — years of papers, marks, and timetables create switching cost
- **Auto-assignment engine** — timetable-to-paper automation is unique
- **8+ question types** with proper formatting — no other tool handles this natively

---

## SLIDE 10: Technology & Architecture (Non-Technical Summary)

- **Cross-platform app** — one codebase runs on Web, Android, and iOS (built with Flutter)
- **Cloud database** — PostgreSQL via Supabase with enterprise-grade security
- **Multi-tenant** — each school's data is completely isolated and secure
- **Role-based access control** — every user sees only what they should
- **Offline-capable** — teachers can draft papers without internet, sync when online
- **Google Sign-In** — no passwords to remember, instant onboarding
- **PDF engine** — generates print-ready papers in-app, no external tools needed
- **Error monitoring** — Firebase Crashlytics for production stability
- **Clean architecture** — modular, testable, maintainable codebase ready for team scaling
- **AI-ready** — existing AI polish feature, architecture supports adding more AI capabilities

---

## SLIDE 11: Roadmap (Next 6–12 Months)

### Near-Term (0–3 Months)
- [ ] Onboard 5–10 pilot schools and gather structured feedback
- [ ] Student performance analytics dashboard (per exam, per subject, per student trends)
- [ ] Bulk student import via CSV
- [ ] Enhanced AI question generation — generate full sections from topic + difficulty input
- [ ] Regional language support (Hindi, Tamil, Telugu to start)

### Mid-Term (3–6 Months)
- [ ] Question bank marketplace — teachers share and discover approved papers
- [ ] Parent-facing report cards — auto-generated from marks data
- [ ] Blueprint/pattern-based paper creation (CBSE/ICSE blueprint compliance)
- [ ] Admin analytics — school-wide exam readiness dashboard
- [ ] WhatsApp notifications for teachers (paper status updates)

### Long-Term (6–12 Months)
- [ ] OMR sheet scanning — auto-grade MCQ papers from scanned answer sheets
- [ ] Multi-language paper generation — same paper in English + regional language
- [ ] School group/chain management — central admin for multi-campus schools
- [ ] API for integration with existing school ERPs
- [ ] Mobile-first teacher app (lightweight version for smartphones)

---

## SLIDE 12: Team

### Solo Founder — Technical & Product

- Full-stack developer and product builder
- Designed, architected, and built Papercraft end-to-end — from database schema to pixel-perfect UI
- Deep understanding of the Indian school system and teacher workflows
- Skills: Flutter, Dart, PostgreSQL, Supabase, Firebase, Clean Architecture, AI integration
- Shipped 29 production builds with 38 database migrations — this is not a prototype, it's a working product

### What I Bring
- Technical execution speed — no dependency on external dev teams
- Product instinct — every feature was built from direct observation of teacher pain
- Cost efficiency — solo founder means low burn rate and high output

### What I Need
- A co-founder or early hire with school sales / distribution experience
- Design support for scaling the UI across languages and devices

---

## SLIDE 13: The Ask

### From an Accelerator / Investor

**Funding:**
- Pre-seed / seed capital to support 12–18 months of runway
- Covers: pilot school onboarding, server costs, marketing, and potentially a first hire

**Distribution Support:**
- Introductions to school networks, education chains, and school management associations
- Help navigating B2B sales cycles in education

**Mentorship:**
- EdTech founders who've sold to schools
- Guidance on pricing strategy for Indian school market
- Product-market fit validation with structured pilot programs

**Infrastructure:**
- Cloud credits (Supabase, Firebase, or equivalent)
- AI API credits for question generation features

### Why Now
- Product is built and live — not an idea on a slide
- The pain is real and recurring — every school faces this every month
- The market is large and underserved — no one owns the exam paper creation workflow
- Solo founder with technical depth = low risk, high speed execution

---

## APPENDIX: Key Metrics to Track (for investor updates)

| Metric | Description |
|--------|-------------|
| Schools onboarded | Total active school tenants |
| Teachers active (MAU) | Monthly active teachers creating papers |
| Papers created | Total question papers created |
| Papers approved | Papers that completed the full workflow |
| Exams conducted | Timetables published and executed |
| Marks entries | Student marks recorded digitally |
| PDF generations | Papers exported to print-ready format |
| Time to paper | Average time from start to submission |
| Approval rate | % of papers approved on first submission |
| Retention | School renewal rate year-over-year |

---

*Document generated from codebase analysis of Papercraft v2.1.0+29*
*38 database migrations | 15+ feature modules | 8+ question types | 7 user roles*
