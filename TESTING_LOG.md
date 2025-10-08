# PaperCraft - Testing Log

Track all testing builds and feedback here.

---

## Build 2.0.0+1 (First Closed Test - Play Store Internal Testing)

**Build Date:** [FILL IN TODAY'S DATE]
**Build Type:** AAB (App Bundle)
**File:** `app-dev-release.aab`
**Distribution:** Google Play Console - Internal Testing Track
**Version Code:** 1 (build number in Play Store)

**Testers:**
- [ ] Teacher 1: [Name] - [Email]
- [ ] Teacher 2: [Name] - [Email]
- [ ] Teacher 3: [Name] - [Email]

**Testing Period:** [Start Date] to [End Date] (approximately 3-5 days)

### Pre-Release Checklist
- [ ] Database migration run (paper_rejection_history table)
- [ ] Supabase RLS policies verified
- [ ] Version updated to 2.0.0+1 in pubspec.yaml
- [ ] Built release AAB with flavor dev
- [ ] Uploaded to Play Console Internal Testing
- [ ] Tested myself: Create → Submit → Reject → Edit → Resubmit
- [ ] Tested PDF generation (single + dual layouts)
- [ ] Tested compression mode
- [ ] Test credentials created for teachers
- [ ] Testers added to Internal Testing email list
- [ ] Opt-in link sent to teachers

### Feedback Received

#### Day 1 - [Date]
**From: [Teacher Name]**
- Issue: [Description]
- Severity: Critical / High / Medium / Low
- Status: Open / Fixed / Investigating

**From: [Teacher Name]**
- Issue: [Description]
- Severity: Critical / High / Medium / Low
- Status: Open / Fixed / Investigating

#### Day 2 - [Date]
[Add feedback as it comes in]

### Bugs Found
| ID | Reporter | Issue | Severity | Status | Fixed in |
|----|----------|-------|----------|--------|----------|
| B1 | Teacher1 | [Description] | High | Open | - |
| B2 | Teacher2 | [Description] | Medium | Fixed | beta.2 |

### Feature Requests
| ID | Reporter | Request | Priority | Status |
|----|----------|---------|----------|--------|
| F1 | Teacher1 | [Description] | Low | Backlog |

### Metrics
- Total papers created: ___
- Total submissions: ___
- PDFs generated: ___
- Crash reports: ___
- Teachers actively testing: ___ / ___

---

## Build 2.0.0+2 (Bug Fix Release)

**Build Date:** [FILL IN DATE]
**Build Type:** AAB (App Bundle)
**Distribution:** Google Play Console - Internal Testing Track
**Version Code:** 2

**Testers:**
- [ ] Same teachers as 2.0.0+1

### What Changed (from 2.0.0+1)
- Fixed: [Bug B2 description]
- Fixed: [Bug B3 description]
- Improved: [Performance issue]

### Pre-Release Checklist
- [ ] All high-priority bugs from 2.0.0+1 fixed
- [ ] Regression testing done
- [ ] Built release AAB
- [ ] Version updated to 2.0.0+2 in pubspec.yaml
- [ ] Uploaded to Play Console

### Feedback Received
[Track new feedback here]

---

## Build 2.0.0+3 (Expanded Testing)

**Build Date:** [FILL IN DATE]
**Build Type:** AAB (App Bundle)
**Distribution:** Google Play Console - Internal Testing Track
**Version Code:** 3

**Testers:**
- [ ] Expanded testing group (8-10 teachers)

[Continue same format...]

---

## Build 2.1.0+4 (Feature Update - Optional)

**Build Date:** [FILL IN DATE]
**Build Type:** AAB (App Bundle)
**Distribution:** Google Play Console - Closed Testing Track
**Version Code:** 4

**New Features:**
- [List new features if any]

---

## Build 2.0.0+5 (Production Release)

**Release Date:** [FILL IN DATE]
**Build Type:** AAB (App Bundle)
**Distribution:** Google Play Console - Production Track
**Store Link:** [Play Store URL]
**Status:** Submitted / Under Review / Published

### Pre-Submission Checklist
- [ ] All testing complete (minimum 2 weeks internal testing)
- [ ] No critical bugs
- [ ] All high-priority bugs fixed
- [ ] App bundle built with production flavor
- [ ] Signed with release keystore
- [ ] Play Store listing complete
- [ ] Screenshots uploaded (minimum 2, recommended 8)
- [ ] Privacy policy published and linked
- [ ] Terms of service published and linked
- [ ] Support email configured
- [ ] Content rating completed
- [ ] Data safety form completed
- [ ] Target audience set
- [ ] Release notes written

### Play Store Details
- Package name: [Your package name]
- Target SDK: 34 (Android 14)
- Min SDK: 21 (Android 5.0)
- File size: ___ MB
- Version: 2.0.0 (Build 5)

---

## Quick Commands Reference

```bash
# Check current version
grep "version:" pubspec.yaml

# Build release APK
flutter build apk --release

# Build app bundle for Play Store
flutter build appbundle --release

# Find APK location
# Android: build/app/outputs/flutter-apk/app-release.apk

# Rename APK with version
# Example: papercraft-v1.0.0-beta.1.apk
```

---

## Contact Information

**Developer:** [Your Name]
**Email:** [Your Email]
**Support Email:** [Support Email for Teachers]
**Project Repository:** [Git URL if applicable]

---

## Notes

### Testing Best Practices
- Always increment version before each build
- Never send same version twice (even for fixes)
- Keep all APK files in a folder (archive them)
- Respond to teacher feedback within 24 hours
- Group similar bugs together
- Prioritize: Critical → High → Medium → Low

### Communication with Testers
- Daily check-ins during Week 1
- Ask for feedback explicitly
- Thank teachers for their time
- Keep them updated on fixes
- Share changelog for each new version
