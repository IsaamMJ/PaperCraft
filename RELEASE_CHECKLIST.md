# Release Checklist

Use this before each build release.

---

## Pre-Build Checklist (Every Time)

### 1. Version Update
- [ ] Updated version in `pubspec.yaml` (e.g., 1.0.0-beta.1+1)
- [ ] Updated `CHANGELOG.md` with changes
- [ ] Committed version changes to git

### 2. Code Quality
- [ ] No debug print statements
- [ ] No TODOs for critical features
- [ ] All imports used (no unused imports)
- [ ] Ran `flutter analyze` (no errors)

### 3. Testing (Self)
- [ ] Tested on physical device (not just emulator)
- [ ] Tested create → save draft → submit flow
- [ ] Tested rejection → edit → resubmit flow
- [ ] Tested PDF generation (both layouts)
- [ ] Tested offline draft saving
- [ ] Tested with slow/no internet

### 4. Database
- [ ] All migrations run on Supabase
- [ ] RLS policies enabled and tested
- [ ] Test data cleaned up (if needed)

### 5. Build
- [ ] Run: `flutter clean`
- [ ] Run: `flutter pub get`
- [ ] Run: `flutter build apk --release`
- [ ] APK generated successfully
- [ ] Renamed APK with version: `papercraft-vX.X.X.apk`
- [ ] Tested APK on real device before sending

### 6. Documentation
- [ ] Updated `CHANGELOG.md`
- [ ] Updated `TESTING_LOG.md` with build info
- [ ] Listed known issues (if any)

### 7. Distribution
- [ ] APK file saved in archive folder
- [ ] Email drafted with:
  - Version number
  - What's new
  - What to test
  - How to report bugs
- [ ] Test credentials verified (if new teachers)

---

## Beta Release Specific

### Additional Checks
- [ ] Listed known issues clearly
- [ ] Set expectations for response time
- [ ] Prepared bug report template
- [ ] Have backup plan if critical bug found

---

## Release Candidate (RC) Specific

### Additional Checks
- [ ] All critical bugs fixed
- [ ] All high-priority bugs fixed
- [ ] Performance tested with large papers (50+ questions)
- [ ] Tested on multiple Android versions
- [ ] Tested on low-end devices
- [ ] Privacy policy ready
- [ ] Terms of service ready
- [ ] In-app help/FAQ added

---

## Play Store Release Specific

### Pre-Submission
- [ ] Version is `1.0.0+X` (no beta/rc)
- [ ] Built app bundle: `flutter build appbundle --release`
- [ ] Signed with release keystore
- [ ] File size < 150 MB
- [ ] Tested release bundle on device
- [ ] All beta/debug features removed
- [ ] Crash reporting enabled (if using)
- [ ] Analytics configured (if using)

### Play Store Listing
- [ ] App name: PaperCraft
- [ ] Short description (80 chars)
- [ ] Full description (4000 chars)
- [ ] Screenshots (min 2, recommended 8)
  - [ ] Home screen
  - [ ] Paper creation
  - [ ] Question entry
  - [ ] PDF preview
  - [ ] Question bank
- [ ] Feature graphic (1024 x 500)
- [ ] App icon (512 x 512)
- [ ] Category: Education
- [ ] Content rating: Everyone
- [ ] Privacy policy URL
- [ ] Support email
- [ ] Target audience: Teachers/Educators

### Legal & Compliance
- [ ] Privacy policy published and linked
- [ ] Terms of service published and linked
- [ ] Data handling disclosure accurate
- [ ] Permissions explained in description
- [ ] COPPA compliant (if applicable)

### Post-Submission
- [ ] Submitted to Play Store
- [ ] Shared listing URL with team
- [ ] Monitored for review status
- [ ] Prepared to respond to review feedback

---

## Emergency Rollback Plan

If critical bug found after release:

### Immediate Actions
1. [ ] Document the bug clearly
2. [ ] Assess severity (Can users continue? Data loss risk?)
3. [ ] If critical: Email all users immediately with workaround
4. [ ] Fix bug in new branch
5. [ ] Test fix thoroughly
6. [ ] Increment version (patch number)
7. [ ] Release hotfix ASAP

### For Beta Testing
- Send email: "Please stop testing, fix coming in X hours"
- Fix and release new version within 24 hours

### For Play Store
- Cannot pull release immediately
- Release hotfix version ASAP
- Update store listing with known issues if needed
- Respond to negative reviews explaining fix is coming

---

## Version Naming Guide

```
Format: MAJOR.MINOR.PATCH-PRERELEASE+BUILD

Examples:
1.0.0-beta.1+1    ← First beta build
1.0.0-beta.2+2    ← Second beta (bug fixes)
1.0.0-rc.1+4      ← Release candidate
1.0.0+5           ← Play Store release
1.0.1+6           ← Hotfix release
1.1.0+10          ← Feature update
```

When to increment:
- **BUILD (+1)**: Every build, always
- **PATCH (.0.1)**: Bug fixes only
- **MINOR (.1.0)**: New features (backwards compatible)
- **MAJOR (2.0.0)**: Breaking changes

---

## Quick Commands

```bash
# Check version
grep "version:" pubspec.yaml

# Clean build
flutter clean && flutter pub get

# Build release APK
flutter build apk --release

# Build app bundle (Play Store)
flutter build appbundle --release

# Analyze code
flutter analyze

# Find APK
# Location: build/app/outputs/flutter-apk/app-release.apk

# Find app bundle
# Location: build/app/outputs/bundle/release/app-release.aab

# Git commit version bump
git add pubspec.yaml CHANGELOG.md
git commit -m "Bump version to 1.0.0-beta.1"
git tag v1.0.0-beta.1
```

---

## Archive Checklist

After each release:

- [ ] APK/AAB file saved in `releases/` folder
- [ ] CHANGELOG.md updated
- [ ] TESTING_LOG.md updated
- [ ] Git tagged with version
- [ ] Release notes documented
- [ ] Feedback collected and organized

Folder structure:
```
releases/
  ├── v1.0.0-beta.1/
  │   ├── papercraft-v1.0.0-beta.1.apk
  │   ├── release-notes.txt
  │   └── feedback/
  ├── v1.0.0-beta.2/
  │   └── ...
```

---

## Contact Before Release

- [ ] Notify admin that new version is coming
- [ ] Give teachers 24-hour heads up for updates
- [ ] Prepare for immediate support after release
- [ ] Have time available to fix urgent issues

---

**Remember:** It's better to delay a release than ship a broken version!
