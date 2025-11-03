# Exam Timetable System - Risk Analysis & Mitigation Strategy

## Document Purpose

This document identifies potential risks in the Exam Timetable System implementation and provides mitigation strategies for each identified risk.

**Risk Assessment Date**: November 1, 2025
**Overall Risk Level**: MEDIUM (manageable with proper planning)

---

## Risk Assessment Matrix

```
        Low      Medium      High    Critical
Impact   |         |         |         |
 HIGH   | 6 items | 4 items | 2 items | 1 item |
        |         |         |         |
 MEDIUM | 5 items | 8 items | 3 items | 0 items|
        |         |         |         |
 LOW    | 8 items | 4 items | 1 item  | 0 items|
        +─────────┴─────────┴─────────┘
 PROBABILITY: Low    Medium    High

Legend:
- Red (Critical): Must address before go-live
- Orange (High): Should address, or have ready contingency
- Yellow (Medium): Monitor during implementation
- Green (Low): Track but low priority
```

---

## Critical Risks (Red - Go/No-Go Blockers)

### Risk 1: RLS Policy Bypasses Causing Data Leakage

**Risk ID**: CRIT-001
**Category**: Security & Data Integrity
**Severity**: CRITICAL

#### Description
If Row Level Security (RLS) policies are not correctly implemented or tested, one school's admin could see another school's timetables, papers, or assignments. This is a data privacy violation and could lead to regulatory issues.

#### Current State
- RLS policies planned in migration file
- Not yet tested in production environment
- Relies on `auth.jwt() ->> 'tenant_id'` extraction

#### Probability: LOW (15%)
- RLS is well-documented and standard in Supabase
- Policies are straightforward (single tenant_id check)
- However, untested in full environment with all roles

#### Impact: CRITICAL (9/10)
- Data breach (regulatory fines, customer trust)
- Reputational damage
- Potential legal liability
- System must be taken offline immediately

#### Mitigation Strategy

**Primary Mitigation** (HIGH CONFIDENCE):
```sql
-- 1. Test RLS policies thoroughly BEFORE production
-- Create test tenants and verify isolation

-- 2. Test at application level too
-- Don't rely solely on database RLS

-- 3. Implement query-level filtering as backup
SELECT * FROM grade_sections
WHERE tenant_id = current_user_tenant_id
AND auth.jwt() ->> 'tenant_id' = current_user_tenant_id;

-- 4. Add audit logging for access violations
CREATE TABLE audit_access_log (
  id uuid PRIMARY KEY,
  user_id uuid,
  table_name text,
  attempted_tenant_id uuid,
  actual_tenant_id uuid,
  access_granted boolean,
  timestamp timestamp,
  CONSTRAINT access_denied_check CHECK (
    attempted_tenant_id = actual_tenant_id OR access_granted = false
  )
);

-- 5. Monitor access violations
SELECT COUNT(*) FROM audit_access_log
WHERE access_granted = false;
```

**Secondary Mitigation** (BACKUP):
- Implement app-level tenant filtering as safety net
- Code review checklist: All queries must have `WHERE tenant_id = ?`
- Automated test: Query each table from "wrong" tenant, verify zero results

#### Early Warning Signs
- Unusual queries in application logs
- Admin complaints: "I see other school's timetables"
- Audit log showing access_granted = false
- Support tickets about data visibility issues

#### Testing Checklist
- [ ] Create test tenant A and B with identical data
- [ ] Login as admin from School A
- [ ] Attempt to query School B's data directly (via Supabase)
- [ ] Verify zero results returned
- [ ] Repeat for all new tables (grade_sections, teacher_subjects, exam_calendar, exam_timetables, exam_timetable_entries)
- [ ] Test with different user roles (admin, teacher, student)
- [ ] Automated RLS test suite must pass 100%

#### Go/No-Go Decision Point
**MUST FIX BEFORE PRODUCTION**: If RLS test fails, rollback and investigate before proceeding.

**Responsible**: Database architect, Security lead
**Timeline**: Complete testing by end of Phase 2
**Owner**: [Name/Role]

---

### Risk 2: Cascading Delete Causing Data Loss

**Risk ID**: CRIT-002
**Category**: Data Integrity

#### Description
If a teacher, grade, or subject is deleted from the system, cascading deletes could remove associated timetable entries and papers, causing data loss and confusion.

#### Current State
- Using soft deletes (`is_active = false`) for some tables
- Hard delete CASCADE relationships still exist
- No backup procedure before cascade deletes

#### Probability: MEDIUM (40%)
- Could happen accidentally during data cleanup
- Could happen if admin role accidentally deleted wrong record
- Unlikely in normal operation but possible

#### Impact: CRITICAL (8/10)
- Papers disappear from teacher dashboards
- Timetable entries vanish
- Audit trail of papers lost
- Teachers confused about missing work

#### Mitigation Strategy

**PRIMARY MITIGATION** (Immediate):
1. **Use Soft Deletes Everywhere**:
   ```sql
   -- Do NOT use CASCADE DELETE
   -- Use soft delete instead
   ALTER TABLE question_papers
   ALTER COLUMN user_id SET NOT NULL;

   -- If teacher deleted, papers remain with deleted teacher_id
   -- Papers become read-only or show "Teacher removed" message
   ```

2. **Constraints for Integrity**:
   ```sql
   -- Grade cannot be deleted if it has active papers
   ALTER TABLE grades
   ADD CONSTRAINT grades_deletion_check
   CHECK NOT EXISTS (
    SELECT 1 FROM question_papers
    WHERE grade_id = grades.id AND is_active = true
  );
   ```

3. **Archive Procedure for True Deletion**:
   ```sql
   -- When admin truly wants to delete:
   -- 1. Archive to archive_* tables
   -- 2. Then delete from production

   INSERT INTO archive_question_papers
   SELECT * FROM question_papers WHERE grade_id = $1;

   DELETE FROM question_papers WHERE grade_id = $1;
   ```

**SECONDARY MITIGATION**:
- Database backups every 6 hours (restorable within 6 hours)
- Point-in-time recovery enabled
- Admin delete requires 2-step confirmation
- Admin delete logs to audit_log with timestamp + reason

#### Early Warning Signs
- Admin receives "Papers not found" error
- Teacher reports missing papers from dashboard
- Sudden drop in paper count in database
- Audit log showing DELETE commands

#### Testing Checklist
- [ ] Delete teacher with active papers → Papers remain visible
- [ ] Delete grade with active papers → Error or warning
- [ ] Archive procedure works correctly
- [ ] Backup/restore procedure tested
- [ ] Audit log captures all deletions

#### Go/No-Go Decision Point
**MUST FIX BEFORE PRODUCTION**: Implement soft delete everywhere and test deletion scenarios.

**Responsible**: Backend lead, Database architect
**Timeline**: Complete by end of Phase 2
**Owner**: [Name/Role]

---

### Risk 3: Paper Count Mismatch After Publishing

**Risk ID**: CRIT-003
**Category**: Business Logic / Data Integrity

#### Description
When admin publishes timetable with 100 entries, the system might create 95 papers instead of 100. This causes admin/teacher confusion: "Where are the 5 missing papers?"

#### Causes
- Teacher assignment lookup failed but didn't error
- Duplicate papers created and one deleted
- Database transaction partially failed
- Async job queue lost some jobs

#### Current State
- Synchronous creation for <500 entries (safer)
- No transaction wrapping
- No count verification after creation

#### Probability: LOW-MEDIUM (25%)
- Synchronous approach reduces risk
- Database errors caught and logged
- But edge cases might exist

#### Impact: CRITICAL (8/10)
- Teachers don't get assigned papers
- Exam cannot proceed as planned
- Admin must manually investigate
- Student exam could be delayed

#### Mitigation Strategy

**PRIMARY MITIGATION**:
1. **Transactional Publishing**:
   ```dart
   Future<void> publishTimetable(String timetableId) async {
     try {
       final timetable = await getTimetable(timetableId);
       final entries = await getTimetableEntries(timetableId);

       // BEGIN TRANSACTION (app-level)
       final papersCreated = <String>[];

       for (final entry in entries) {
         try {
           final paper = await createPaper(entry);
           papersCreated.add(paper.id);
         } catch (e) {
           // ROLLBACK: Delete all papers created so far
           for (final paperId in papersCreated) {
             await deletePaper(paperId);
           }
           throw PublishTimetableException(
             'Failed at entry ${entry.id}, rollback complete'
           );
         }
       }

       // Verify count matches expected
       if (papersCreated.length != expectedPaperCount) {
         throw PaperCountMismatchException(
           'Expected $expectedPaperCount papers, created ${papersCreated.length}'
         );
       }

       // Update status only if all papers created
       await updateTimetableStatus(timetableId, 'published');
       // COMMIT
     } catch (e) {
       // ROLLBACK on any error
       AppLogger.error('Publish failed, rolling back', error: e);
       rethrow;
     }
   }
   ```

2. **Verification & Reporting**:
   ```dart
   Future<PublishResult> publishTimetableWithReport(
     String timetableId,
   ) async {
     final result = PublishResult();

     try {
       // Count expected papers
       final entries = await getTimetableEntries(timetableId);
       result.expectedPaperCount = await countExpectedPapers(entries);

       // Publish
       await publishTimetable(timetableId);

       // Verify created
       result.actualPaperCount = await countCreatedPapers(timetableId);

       if (result.actualPaperCount != result.expectedPaperCount) {
         result.errors.add(
           'Paper count mismatch: expected ${result.expectedPaperCount}, '
           'got ${result.actualPaperCount}'
         );
       }

     } catch (e) {
       result.errors.add(e.toString());
     }

     return result;
   }
   ```

3. **Admin Verification Step**:
   ```
   Publish Confirmation Screen:

   "You're about to create papers for this timetable.

   Calculation:
   • 15 entries in timetable
   • Expected papers to create: 18
     - Grade 5-A Maths: 2 teachers → 2 papers
     - Grade 5-A English: 1 teacher → 1 paper
     - ... (list all)

   [ ✓ Verified ]  [ Recalculate ]  [ Cancel ]"
   ```

#### Early Warning Signs
- Admin publishes, then checks papers
- "Expected 100 papers, found 95 papers" message
- No error in logs, but papers missing
- Teacher complains: "I didn't get a paper for Maths"

#### Testing Checklist
- [ ] Publish with 10 entries, verify 10+ papers created
- [ ] Publish with multiple teachers per entry, count correct
- [ ] Publish with no teachers for entry, fails with clear error
- [ ] Simulate database error mid-creation, rolls back
- [ ] Verification report shows expected vs actual
- [ ] Admin sees clear count before publishing

#### Go/No-Go Decision Point
**MUST HAVE BEFORE PRODUCTION**: Transactional publishing and verification report.

**Responsible**: Backend lead, QA
**Timeline**: Complete by end of Phase 2
**Owner**: [Name/Role]

---

## High-Risk Issues (Orange - Needs Mitigation)

### Risk 4: Section Names Not Standardized

**Risk ID**: HIGH-001
**Category**: Data Quality
**Probability**: HIGH (70%)
**Impact**: HIGH (6/10)

#### Description
Different grades define sections with different naming schemes. Grade 5 uses "A, B, C", Grade 6 uses "A, B", Grade 7 uses "1, 2, 3". This causes confusion and breaks assumptions.

#### Mitigation
- Admin guidance doc: "Recommend consistent naming (A, B, C) across all grades"
- Validation: Only allow single-character or two-character section names
- Help text: "Examples: A, B, C or 1, 2, 3"
- Constraint: `section_name ~ '^[A-Z0-9]{1,2}$'`

#### Testing
- [ ] Try to add section named "Grade 5-A" → Fails with error
- [ ] Try to add section named "Z" → Succeeds
- [ ] Try to add section named "12" → Succeeds
- [ ] Display warning if mixing letter + number schemes in same grade

---

### Risk 5: Teacher Assignment Lookup Performance

**Risk ID**: HIGH-002
**Category**: Performance
**Probability**: HIGH (60%)
**Impact**: MEDIUM (6/10)

#### Description
When publishing timetable with 500 entries, looking up teachers for each (grade, subject, section) might take too long if indexes are missing.

#### Current State
- Index created in migration: `idx_teacher_subjects_grade_subject`
- But query uses 5 columns: grade, subject, section, academic_year, tenant_id

#### Mitigation
1. **Verify Index Coverage**:
   ```sql
   CREATE INDEX idx_teacher_subjects_lookup ON teacher_subjects(
     tenant_id, grade_id, subject_id, section, academic_year
   );
   ```

2. **Benchmark Query**:
   ```sql
   EXPLAIN ANALYZE
   SELECT teacher_id FROM teacher_subjects
   WHERE tenant_id = 'xxx'
     AND grade_id = 'yyy'
     AND subject_id = 'zzz'
     AND section = 'A'
     AND academic_year = '2024-2025'
     AND is_active = true;

   -- Should use index, show < 1ms execution time
   ```

3. **Batch Lookup** (for many entries):
   ```sql
   -- Instead of N queries, batch lookup
   SELECT grade_id, subject_id, section, teacher_id
   FROM teacher_subjects
   WHERE (grade_id, subject_id, section) IN (
     ('Grade 5', 'Maths', 'A'),
     ('Grade 5', 'Maths', 'B'),
     ('Grade 5', 'English', 'A'),
     ...
   )
   AND academic_year = '2024-2025'
   AND is_active = true;
   ```

#### Testing
- [ ] Single entry lookup: <10ms
- [ ] 50 entry batch lookup: <100ms
- [ ] 500 entry batch lookup: <500ms
- [ ] Monitor query execution time during Phase 4

---

### Risk 6: Admin Accidentally Publishes Wrong Timetable

**Risk ID**: HIGH-003
**Category**: User Error
**Probability**: MEDIUM (45%)
**Impact**: HIGH (7/10)

#### Description
Admin creates timetable for "June Monthly" but fat-fingers and publishes "June Monthly - Backup" instead, creating wrong papers.

#### Mitigation
1. **Confirmation Dialog**:
   ```
   "Publish 'June Monthly Test'?

   This will create 45 question papers for your teachers.
   Teachers will see these papers in their dashboard.

   This action cannot be undone.

   [ YES, PUBLISH ]  [ CANCEL ]"
   ```

2. **Display Summary**:
   Show exam name, entry count, expected paper count clearly

3. **Audit Log**:
   ```
   Admin published: June Monthly Test
   Time: 2024-06-10 10:30:45
   Papers created: 45
   ```

4. **Rollback Mechanism** (Phase 4+):
   Allow admin to unpublish within 24 hours if needed

#### Testing
- [ ] Confirmation shows correct timetable name
- [ ] Count displayed matches actual
- [ ] Audit log records publishing action
- [ ] Notification sent shows which timetable published

---

## Medium-Risk Issues (Yellow - Monitor During Implementation)

### Risk 7: Concurrent Timetable Edits

**Risk ID**: MEDIUM-001
**Category**: Data Integrity
**Probability**: MEDIUM (50%)
**Impact**: MEDIUM (5/10)

#### Description
Two admins editing same timetable simultaneously. One adds 10 entries, other adds 5 entries. Result: Merge conflict or lost updates.

#### Mitigation
1. **Optimistic Locking**:
   ```sql
   ALTER TABLE exam_timetables
   ADD COLUMN updated_at timestamp WITH TIME ZONE,
   ADD COLUMN version_number integer DEFAULT 1;

   -- Update only if version matches
   UPDATE exam_timetables
   SET status = $1, version_number = version_number + 1
   WHERE id = $2 AND version_number = $3;

   -- If version doesn't match: conflict detected
   ```

2. **Lock on Edit**:
   - When admin opens edit screen, lock timetable
   - Show: "Editing by [Admin Name] - Last edited 2 min ago"
   - If other admin tries to edit: "Cannot edit - locked by [Admin Name]"

3. **Last-Write-Wins** (if no locking):
   - Track `updated_at` timestamp
   - Reload data before save
   - Show merge conflict UI if data changed

#### Testing
- [ ] Two sessions editing same timetable
- [ ] Add entries in each session
- [ ] Save first session → Success
- [ ] Save second session → Conflict or override warning
- [ ] Verify final data state is correct

---

### Risk 8: Teacher Assignment Validation Gaps

**Risk ID**: MEDIUM-002
**Category**: Business Logic
**Probability**: MEDIUM (55%)
**Impact**: MEDIUM (6/10)

#### Description
During onboarding, teacher selects (Grade 5, Section A, Maths). But Section A doesn't actually exist in Grade 5 (admin forgot to create it). System allows invalid assignment.

#### Mitigation
1. **Client-Side Validation**:
   ```dart
   // Only show sections that actually exist
   final gradeSections = await gradeSectionRepository.getGradeSections(
     tenantId: currentTenant.id,
     gradeId: selectedGrade.id,
   );

   // Display checkboxes only for existing sections
   ```

2. **Server-Side Validation**:
   ```sql
   ALTER TABLE teacher_subjects
   ADD CONSTRAINT valid_section_exists
   FOREIGN KEY (tenant_id, grade_id, section)
   REFERENCES grade_sections(tenant_id, grade_id, section_name);
   ```

3. **Validation Use Case**:
   ```dart
   final result = validateTeacherAssignment(
     gradeId: selectedGrade,
     section: selectedSection,
     subjectId: selectedSubject,
   );

   if (!result.isValid) {
     showError(result.errorMessage);
     // e.g., "Section C doesn't exist in Grade 5"
   }
   ```

#### Testing
- [ ] Try to select non-existent section → Error shown
- [ ] Try to assign non-existent subject → Error shown
- [ ] Validation prevents save with invalid data
- [ ] Help text explains what sections are available

---

### Risk 9: Migration Syntax Errors

**Risk ID**: MEDIUM-003
**Category**: Technical
**Probability**: LOW (20%)
**Impact**: MEDIUM (5/10)

#### Description
SQL migration file has syntax error (missing comma, typo in column name). Migration fails midway, leaving database in inconsistent state.

#### Mitigation
1. **SQL Validation** (before applying):
   ```bash
   # Test migration on backup database first
   pg_restore -d test_db backup.sql
   psql -d test_db -f supabase/migrations/20251101_add_exam_timetable_schema.sql

   # Verify no errors
   ```

2. **Step-by-Step Validation**:
   - Run migration up to Step 1 (modify tables)
   - Check: Are columns added?
   - Run migration Step 2 (create new tables)
   - Check: Are tables created?
   - etc.

3. **Rollback Procedure**:
   ```bash
   # If migration fails:
   pg_restore -d production backup.sql
   # Investigate error
   # Fix migration file
   # Re-apply
   ```

#### Testing
- [ ] Run migration on test database → Success
- [ ] Verify all tables exist
- [ ] Verify all columns exist
- [ ] Verify all indexes exist
- [ ] Verify RLS policies created
- [ ] Run sample queries on each table

---

## Low-Risk Issues (Green - Track)

### Risk 10: Notification Spam

**Risk ID**: LOW-001
**Category**: User Experience
**Probability**: MEDIUM (50%)
**Impact**: LOW (3/10)

#### Description
When papers are created, each teacher gets notification. If 100 papers created, some teachers might get multiple notifications (once per paper).

#### Mitigation
- Batch notifications: "5 papers created for you"
- User preference: "Digest daily instead of immediate"
- Notification deduplication

#### Testing
- [ ] Create 10 papers for one teacher
- [ ] Verify only 1 notification sent (or batched)
- [ ] Teacher can toggle notification preferences

---

### Risk 11: Year Rollover Data

**Risk ID**: LOW-002
**Category**: Data Management
**Probability**: HIGH (80%)
**Impact**: LOW (2/10)

#### Description
When rolling over to new academic year (2025-2026), old timetables and papers for 2024-2025 are still visible but teachers don't need them.

#### Mitigation
- Archive old year data (archive_exam_timetables, archive_question_papers)
- Dashboard filters by academic year
- Admin interface to archive old data

#### Testing
- [ ] Filter timetables by academic year
- [ ] Archive 2024-2025 data
- [ ] Verify not shown in main views

---

### Risk 12: Mobile Responsiveness

**Risk ID**: LOW-003
**Category**: User Experience
**Probability**: MEDIUM (45%)
**Impact**: LOW (3/10)

#### Description
Admin UI (timetable management) not responsive on mobile. Admins use tablets/phones sometimes.

#### Mitigation
- Use responsive design patterns
- Test on tablet (1024px width minimum)
- Convert tables to cards on mobile
- Stack columns vertically

#### Testing
- [ ] Test each admin screen on mobile (375px)
- [ ] Test each admin screen on tablet (768px)
- [ ] Verify all buttons clickable
- [ ] Verify text readable

---

## Risk Monitoring & Control

### Weekly Risk Review

**Every Friday Standup**:
1. Review critical risks (CRIT-001, CRIT-002, CRIT-003)
   - Are mitigations in place?
   - Any new warning signs?

2. Review high-risk items (HIGH-001, HIGH-002, HIGH-003)
   - Are mitigations started?
   - Any new issues discovered?

3. Update risk status
   - Red → Yellow? → Green?
   - Or escalated?

### Risk Register Template

```
Risk ID: MEDIUM-001
Title: Concurrent Timetable Edits
Status: IN PROGRESS (optimistic locking implemented)
Mitigations:
  - [x] Design optimistic locking strategy
  - [ ] Implement locking in database
  - [ ] Test concurrent scenarios
  - [ ] Document for team
Next Review: Nov 8, 2025
Owner: Backend Lead
```

---

## Risk Communication

### Escalation Criteria

| Risk Level | Escalation | Action |
|-----------|-----------|--------|
| Red/Critical | IMMEDIATE | Notify PM, team lead, CTO |
| Orange/High | Daily | Include in standup |
| Yellow/Medium | Weekly | Include in Friday review |
| Green/Low | Monthly | Track in risk register |

### Risk Status Report (Weekly)

```
RISK STATUS REPORT - Week of Nov 1, 2025

🔴 CRITICAL (3)
  - CRIT-001: RLS policies - Testing started, on track
  - CRIT-002: Cascading deletes - Soft delete design done, implementing
  - CRIT-003: Paper count mismatch - Transaction logic designed

🟠 HIGH (3)
  - HIGH-001: Section naming - Validation designed, implementing
  - HIGH-002: Lookup performance - Index verified, benchmarking
  - HIGH-003: Wrong timetable publish - Dialog screen designed

🟡 MEDIUM (6)
  - MEDIUM-001: Concurrent edits - Design phase
  - MEDIUM-002: Validation gaps - Design phase
  - MEDIUM-003: Migration errors - Test procedure created
  - + 3 more

🟢 LOW (5)
  - LOW-001: Notification spam
  - LOW-002: Year rollover
  - LOW-003: Mobile responsiveness
  - + 2 more

OVERALL STATUS: ON TRACK
Next Review: Nov 8, 2025
```

---

## Contingency Plans

### If Critical Risk Materializes

#### Scenario 1: RLS Policy Bypass Discovered After Launch
```
RESPONSE PLAN:
1. IMMEDIATE (0-2 hours):
   - Take system offline
   - Notify all school admins
   - Begin forensic audit of access logs

2. SHORT TERM (2-4 hours):
   - Identify which data was potentially exposed
   - Patch RLS policy
   - Deploy hotfix

3. MEDIUM TERM (4-24 hours):
   - Detailed audit report
   - Notification to affected schools
   - Compensation plan if needed

4. LONG TERM:
   - Post-mortem analysis
   - Improved testing procedures
   - Enhanced monitoring
```

#### Scenario 2: Paper Count Mismatch at Scale
```
RESPONSE PLAN:
1. IMMEDIATE:
   - Pause publishing of timetables
   - Notify affected schools

2. Diagnosis:
   - Check logs for errors
   - Count expected vs actual papers
   - Identify pattern

3. Resolution:
   - Fix underlying issue
   - Manually create missing papers if needed
   - Send notifications to teachers

4. Prevention:
   - Enhanced transaction logging
   - Automated count verification
```

### Budget for Contingencies

- Risk Response Team: 2-3 people available on-call
- Hotfix Deployment: 2-4 hour availability window
- Customer Communication: Predefined templates ready
- External Audit: If needed for data breach assessment

---

## Sign-Off

**Risk Assessment Completed By**: [Name, Title]
**Date**: November 1, 2025
**Review Date**: November 8, 2025

**Stakeholder Sign-Offs**:
- [ ] Engineering Lead: Mitigations are feasible
- [ ] Product Manager: Risk acceptable for launch
- [ ] Operations Lead: Monitoring and support procedures ready
- [ ] Security Lead: Security risks properly mitigated

---

## Appendix: Risk Matrix Details

### Risk Scoring Methodology

**Probability Scale**:
- LOW (1-3): <20% chance of occurring during 3-month period
- MEDIUM (4-6): 20-60% chance
- HIGH (7-9): >60% chance

**Impact Scale** (if risk materializes):
- LOW (1-3): Inconvenience, easily fixed, <1 hour to resolve
- MEDIUM (4-6): Service disruption, requires medium effort, 1-8 hours to resolve
- HIGH (7-9): Major issue, significant effort to fix, >8 hours to resolve
- CRITICAL (10): System down, data loss, regulatory impact

**Overall Risk Score** = Probability × Impact
- Red (25+): Critical
- Orange (16-24): High
- Yellow (9-15): Medium
- Green (1-8): Low

---

## References

- NIST Risk Assessment Guide
- Project Management Institute (PMI) Risk Management Framework
- Supabase Security Best Practices
- Flutter Performance Guidelines
