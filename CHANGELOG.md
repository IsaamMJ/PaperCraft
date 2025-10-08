# PaperCraft - Changelog

All notable changes to this project will be documented in this file.

---

## [2.0.0+1] - 2025-01-XX (Closed Testing - Internal Track)

### Initial Closed Testing Release via Play Store
**Testing Group:** Pearlmatric School Teachers (3-5 users)
**Distribution:** Google Play Console - Internal Testing Track

### Features
- ✅ Teacher account creation and login
- ✅ Create question papers with multiple question types (MCQ, True/False, Short Answer, Long Answer, Fill Blanks, Match Following)
- ✅ Save papers as drafts (works offline)
- ✅ Submit papers for admin approval
- ✅ Edit rejected papers and resubmit
- ✅ Generate PDFs in two layouts:
  - Single Page Layout
  - Side-by-Side Layout (Balanced & Compressed modes)
- ✅ Preview PDFs before download
- ✅ Print PDFs directly
- ✅ Share PDFs with other apps
- ✅ Question bank for approved papers
- ✅ Admin console for paper approval/rejection

### Technical
- Offline-first architecture (drafts saved locally with Hive)
- Supabase backend with Row Level Security
- PDF generation with compression optimization
- Rejection history tracking

### Known Issues
- [ ] None yet (waiting for tester feedback)

### Testing Focus
- Paper creation workflow
- Rejection → Edit → Resubmit flow
- PDF generation (both layouts)
- Offline draft functionality
- Performance with 50+ questions

---

## [Unreleased] - Future Versions

### Planned for 2.0.0+2
- Bug fixes based on teacher feedback
- Performance improvements
- UI/UX refinements

### Planned for 2.0.0+5 (Production Release)
- Privacy policy page
- Terms of service
- In-app help/FAQ
- Data safety disclosure
- Content rating
- Final Play Store listing polish

---

## Version History Template

Use this template for each new version:

```
## [Version Number] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes to existing features

### Fixed
- Bug fixes

### Removed
- Removed features

### Known Issues
- Outstanding bugs
```

---

## Quick Reference

**Versioning (Starting from 2.0.0):**
- `2.0.0+1` - First internal testing (Play Store)
- `2.0.0+2` - Bug fixes
- `2.0.0+3` - More fixes / expanded testing
- `2.0.0+X` - Continue incrementing
- `2.1.0+X` - Feature updates (if needed)
- `2.0.0+final` - Production release

**Build Numbers:**
- Increment +1 for every upload to Play Store
- Never reuse a build number (Play Store enforces this)
- Build numbers are internal (users see version name only)

**Testing Phases:**
- Week 1: 2.0.0+1, 2.0.0+2 (Internal Testing - 3-5 teachers)
- Week 2: 2.0.0+3, 2.0.0+4 (Internal Testing - expanded group)
- Week 3: Final polish and production preparation
- Week 4: Production release (Google review required)
