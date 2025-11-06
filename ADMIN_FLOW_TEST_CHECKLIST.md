# Admin Setup Flow - Comprehensive Testing Checklist

## Test Environment Setup
- [ ] App is built and running
- [ ] Test admin account is available
- [ ] Supabase backend is connected
- [ ] Network connectivity is stable
- [ ] Device/emulator has sufficient storage

---

## SECTION 1: LOGIN & ADMIN ACCESS

### 1.1 Admin Login
- [ ] Admin can login with valid credentials
- [ ] Admin redirected to admin setup wizard after login
- [ ] Admin redirected to `/admin/setup` route
- [ ] Non-admin users do NOT see admin setup wizard
- [ ] Admin setup wizard does NOT appear for teachers
- [ ] Proper role-based access control is enforced

### 1.2 Session Management
- [ ] Admin session persists correctly
- [ ] Session timeout handling works
- [ ] Re-login after session timeout works
- [ ] Proper error messages on authentication failure

---

## SECTION 2: STEP 1 - GRADE SELECTION

### 2.1 Initial State
- [ ] Step indicator shows "Step 1 of 4"
- [ ] Progress bar is at 25% (1/4)
- [ ] Step 1 circle is highlighted/bold
- [ ] Steps 2-4 circles are greyed out
- [ ] "Select Grades" title is displayed
- [ ] Description text is visible and clear

### 2.2 Quick-Add Buttons
- [ ] "Primary (1-5)" button exists and is clickable
- [ ] "Middle (6-8)" button exists and is clickable
- [ ] "High (9-10)" button exists and is clickable
- [ ] "Higher (11-12)" button exists and is clickable
- [ ] Clicking "Primary (1-5)" selects grades 1, 2, 3, 4, 5
- [ ] Clicking "Middle (6-8)" selects grades 6, 7, 8
- [ ] Clicking "High (9-10)" selects grades 9, 10
- [ ] Clicking "Higher (11-12)" selects grades 11, 12
- [ ] Buttons can be clicked multiple times
- [ ] Quick-add buttons add to existing selection (not replace)

### 2.3 Individual Grade Selection
- [ ] All grade buttons (1-12) are displayed
- [ ] Grade buttons are arranged in a 4-column grid
- [ ] Individual grades can be selected by clicking
- [ ] Individual grades can be deselected by clicking again
- [ ] Selected grades show visual indicator (highlight, checkmark, etc.)
- [ ] Deselected grades return to normal state

### 2.4 Grade Selection Combinations
- [ ] Single grade selection works (e.g., only grade 9)
- [ ] Multiple grades selection works (e.g., 9, 10, 11)
- [ ] All grades selection works (grades 1-12)
- [ ] Non-consecutive grades selection works (e.g., 5, 9, 12)
- [ ] Selection count display is accurate
- [ ] Summary shows "X grades selected"

### 2.5 School Details Input
- [ ] School Name text field is visible
- [ ] School Address text field is visible
- [ ] School Name field accepts text input
- [ ] School Address field accepts text input
- [ ] Real-time input validation occurs
- [ ] Maximum length constraints are enforced
- [ ] Special characters are handled properly
- [ ] Empty fields are allowed (optional fields)

### 2.6 Navigation from Step 1
- [ ] "Next" button is visible
- [ ] "Next" button is disabled when no grades selected
- [ ] "Next" button becomes enabled when grades are selected
- [ ] Clicking "Next" with valid selection moves to Step 2
- [ ] Step indicator changes to "Step 2 of 4"
- [ ] Progress bar updates to 50%
- [ ] Previously entered data is retained
- [ ] Clicking "Next" without grade selection shows error message
- [ ] Error message is clear and actionable

### 2.7 Data Persistence
- [ ] After selecting grades, data is stored in BLoC state
- [ ] Navigating backward and forward retains grade selection
- [ ] School name is remembered when navigating steps
- [ ] School address is remembered when navigating steps
- [ ] Data is not lost on widget rebuild

---

## SECTION 3: STEP 2 - SECTIONS CONFIGURATION

### 3.1 Initial State
- [ ] Step indicator shows "Step 2 of 4"
- [ ] Progress bar is at 50% (2/4)
- [ ] Step 2 circle is highlighted
- [ ] Step 1 circle shows checkmark
- [ ] "Add Sections" or "Configure Sections" title is displayed
- [ ] List of selected grades from Step 1 is shown

### 3.2 Grade Display
- [ ] All selected grades from Step 1 are displayed
- [ ] Each grade has its own section input area
- [ ] Grade numbers are clearly labeled (e.g., "Grade 9:", "Grade 10:")
- [ ] Grades are displayed in ascending order
- [ ] No unselected grades are shown

### 3.3 Quick Pattern Buttons
- [ ] "A, B, C" button exists and is clickable
- [ ] "A, B, C, D" button exists and is clickable
- [ ] "All Sections (A-E)" button exists and is clickable
- [ ] "A, B, C" applies sections A, B, C to ALL grades
- [ ] "A, B, C, D" applies sections A, B, C, D to ALL grades
- [ ] "All Sections (A-E)" applies sections A-E to ALL grades
- [ ] Quick buttons replace existing sections, not add to them
- [ ] Quick buttons can be clicked multiple times

### 3.4 Individual Section Input
- [ ] Text input field exists for each grade
- [ ] Input field accepts section names (letters)
- [ ] Input field accepts uppercase and lowercase letters
- [ ] Input validation prevents empty entries
- [ ] Input validation prevents special characters (or handles them)
- [ ] Input field has placeholder text (e.g., "Enter section name")
- [ ] "Add Section" button exists for each grade
- [ ] "Add Section" button adds section to the grade
- [ ] Maximum section length is enforced

### 3.5 Section Management
- [ ] Sections appear as removable chips/tags after entry
- [ ] Clicking on a section chip shows delete option
- [ ] Sections can be removed by clicking X or delete button
- [ ] Duplicate sections are prevented per grade
- [ ] Section names are case-insensitive (A, a, A treated same)
- [ ] Removed sections can be re-added
- [ ] Empty section lists are prevented when moving forward
- [ ] Visual indication of current sections per grade

### 3.6 Navigation from Step 2
- [ ] "Next" button is visible
- [ ] "Next" button is disabled when grades lack sections
- [ ] "Next" button becomes enabled when all grades have sections
- [ ] "Previous" button is visible and clickable
- [ ] Clicking "Previous" returns to Step 1
- [ ] Data entered in Step 1 is preserved
- [ ] Clicking "Next" with valid sections moves to Step 3
- [ ] Error message appears if trying to proceed without all sections
- [ ] Error message specifies which grades lack sections

### 3.7 Data Validation
- [ ] System prevents proceeding without sections for any grade
- [ ] At least 1 section is required per grade
- [ ] System validates all selected grades have sections
- [ ] Validation occurs before navigation attempt
- [ ] User-friendly error messages guide correction

### 3.8 Data Persistence
- [ ] Sections entered are retained in state
- [ ] Navigating back and forth retains section data
- [ ] Quick-add pattern buttons retain their selections
- [ ] Data survives widget rebuilds

---

## SECTION 4: STEP 3 - SUBJECT SELECTION

### 4.1 Initial State
- [ ] Step indicator shows "Step 3 of 4"
- [ ] Progress bar is at 75% (3/4)
- [ ] Step 3 circle is highlighted
- [ ] Steps 1-2 circles show checkmarks
- [ ] "Select Subjects" or "Configure Subjects" title is displayed
- [ ] List of selected grades from Step 1 is shown
- [ ] Loading indicator appears while fetching subject suggestions

### 4.2 Subject Catalog Integration
- [ ] Subject suggestions are loaded from database
- [ ] Subjects are filtered by grade range
- [ ] For grade 9, appropriate subjects are shown
- [ ] For grade 10, different subjects may be available
- [ ] For grade 11, appropriate subjects are shown
- [ ] Grade-specific subjects are accurately filtered
- [ ] Subject catalog is not empty
- [ ] Loading completes successfully for all grades

### 4.3 Subject Selection UI
- [ ] Subjects appear as FilterChips
- [ ] FilterChips show subject names clearly
- [ ] Selected subjects are visually distinct (highlighted, colored)
- [ ] Unselected subjects appear in normal state
- [ ] Clicking a subject toggles selection
- [ ] Multiple subjects can be selected per grade
- [ ] Subject selection is independent per grade

### 4.4 Subject Filtering
- [ ] Subjects are grouped by grade
- [ ] Each grade section is clearly labeled
- [ ] Grades are displayed in ascending order
- [ ] Only selected grades from Step 1 are shown
- [ ] Subject suggestions are appropriate for each grade
- [ ] Catalog filtering works correctly
- [ ] No grade shows subjects outside its range

### 4.5 Subject Management
- [ ] Selected subjects appear as removable chips/tags
- [ ] Subjects can be deselected by clicking chip X
- [ ] Subjects can be toggled by clicking FilterChip again
- [ ] Duplicate subjects per grade are prevented
- [ ] Subject selection is case-sensitive (Math ≠ math)
- [ ] Removed subjects can be re-added
- [ ] Visual indication of selected subjects
- [ ] Count of selected subjects per grade displayed

### 4.6 Subject Catalog Completeness
- [ ] All standard subjects are available in catalog
- [ ] Subject suggestions are complete and accurate
- [ ] No subjects are missing from catalog
- [ ] Catalog can be updated without breaking UI
- [ ] Subject names are spelled correctly
- [ ] Subject names are properly formatted
- [ ] No duplicate subjects in suggestions

### 4.7 Loading States
- [ ] Loading spinner appears while fetching subjects
- [ ] Loading message is displayed
- [ ] Spinner disappears when subjects load
- [ ] Error message if subjects fail to load
- [ ] Retry option appears on load failure
- [ ] UI is responsive during loading
- [ ] No UI freezing during subject fetch

### 4.8 Navigation from Step 3
- [ ] "Next" button is visible
- [ ] "Next" button is disabled when grades lack subjects
- [ ] "Next" button becomes enabled when all grades have subjects
- [ ] "Previous" button is visible and clickable
- [ ] Clicking "Previous" returns to Step 2
- [ ] Data entered in Steps 1-2 is preserved
- [ ] Clicking "Next" with valid subjects moves to Step 4
- [ ] Error message appears if trying to proceed without all subjects
- [ ] Error message specifies which grades lack subjects

### 4.9 Data Validation
- [ ] System prevents proceeding without subjects for any grade
- [ ] At least 1 subject is required per grade
- [ ] System validates all selected grades have subjects
- [ ] Validation occurs before navigation attempt
- [ ] User-friendly error messages guide correction

### 4.10 Data Persistence
- [ ] Subjects selected are retained in state
- [ ] Navigating back and forth retains subject selection
- [ ] Subject selections survive widget rebuilds
- [ ] Editing previous steps doesn't reset subjects

---

## SECTION 5: STEP 4 - REVIEW & CONFIRMATION

### 5.1 Initial State
- [ ] Step indicator shows "Step 4 of 4"
- [ ] Progress bar is at 100% (4/4)
- [ ] Step 4 circle is highlighted
- [ ] All previous steps show checkmarks
- [ ] "Review Configuration" or "Confirm Setup" title is displayed
- [ ] Summary section is displayed with all entered data

### 5.2 School Details Review
- [ ] School name is displayed (or empty if not provided)
- [ ] School address is displayed (or empty if not provided)
- [ ] School details are editable (take user back to Step 1)
- [ ] School name formatting is correct
- [ ] School address formatting is correct

### 5.3 Grades Summary
- [ ] All selected grades are listed
- [ ] Grades are displayed in ascending order
- [ ] Grade count is accurate
- [ ] Format is clear (e.g., "Grade 9, 10, 11")
- [ ] Grade list is easily readable
- [ ] Edit button/link for grades navigates to Step 1

### 5.4 Sections Summary
- [ ] Sections are grouped by grade
- [ ] Each grade shows its sections
- [ ] Format is clear (e.g., "Grade 9: A, B, C")
- [ ] All sections are displayed
- [ ] Section count is accurate per grade
- [ ] Edit button/link for sections navigates to Step 2

### 5.5 Subjects Summary
- [ ] Subjects are grouped by grade
- [ ] Each grade shows its subjects
- [ ] Format is clear (e.g., "Grade 9: Math, English, Science")
- [ ] All subjects are displayed
- [ ] Subject count is accurate per grade
- [ ] Edit button/link for subjects navigates to Step 3

### 5.6 Navigation from Step 4
- [ ] "Previous" button is visible and clickable
- [ ] Clicking "Previous" returns to Step 3
- [ ] Data from all steps is preserved
- [ ] "Complete Setup" or "Confirm" button is visible
- [ ] "Complete Setup" button triggers save process
- [ ] No validation errors on Step 4 (confirmation only)

### 5.7 Data Accuracy
- [ ] All data from previous steps is accurately displayed
- [ ] No data is missing from summary
- [ ] No data is duplicated in summary
- [ ] Format matches what was entered
- [ ] No spelling errors in displayed data

### 5.8 Editability
- [ ] Clicking on any section allows editing
- [ ] User is taken to correct step for editing
- [ ] Changes made on editing steps are reflected in review
- [ ] Can complete setup after making edits
- [ ] Navigation back to review retains changes

---

## SECTION 6: SAVE & COMPLETION

### 6.1 Save Process
- [ ] "Complete Setup" button is clickable
- [ ] Clicking triggers loading state
- [ ] Loading modal appears with spinner
- [ ] Loading message says "Completing setup..." or similar
- [ ] Loading modal has icon/animation
- [ ] Loading does NOT block UI completely

### 6.2 Loading Modal
- [ ] Modal displays school icon or animation
- [ ] Spinner/progress animation is visible
- [ ] Message explains what's happening
- [ ] Sub-message provides additional context
- [ ] Modal does NOT have close button
- [ ] User cannot dismiss modal prematurely
- [ ] Duration is approximately 3 seconds
- [ ] Modal is centered on screen

### 6.3 Database Operations
- [ ] School details (name, address) are saved to `tenants` table
- [ ] Grades are created in `grades` table
- [ ] Sections are created in `grade_sections` table
- [ ] Subjects are created in `subjects` table
- [ ] Grade-section-subject mappings are created
- [ ] All data is saved to correct tenant ID
- [ ] Soft deletes are handled properly
- [ ] Upsert operations work correctly
- [ ] No duplicate records are created
- [ ] RLS policies allow admin to save

### 6.4 Success State
- [ ] Loading modal transitions to success modal
- [ ] Success modal displays checkmark/success icon
- [ ] Success message says "Setup Completed!"
- [ ] Confirmation message about successful setup
- [ ] Modal auto-closes after 3 seconds
- [ ] No manual close action needed
- [ ] Animation is smooth and professional

### 6.5 Post-Completion Redirect
- [ ] After success modal closes, user is redirected
- [ ] Redirect goes to `/home` or dashboard
- [ ] Admin dashboard is displayed
- [ ] Auth state is refreshed
- [ ] `is_initialized` flag is set to true in database
- [ ] Admin can access dashboard features
- [ ] No infinite redirect loops

### 6.6 Error Handling
- [ ] If save fails, error modal is displayed
- [ ] Error message explains what went wrong
- [ ] Specific error details are shown
- [ ] Retry option is available
- [ ] User can go back and re-check data
- [ ] User is NOT logged out on error
- [ ] Session is maintained on error
- [ ] Can retry save without re-entering data

### 6.7 Network Issues
- [ ] Timeout handling works properly
- [ ] Connection loss is detected
- [ ] Appropriate error message is shown
- [ ] Retry mechanism is provided
- [ ] Partial saves are handled safely
- [ ] Idempotent operations prevent duplicates
- [ ] Data integrity is maintained

---

## SECTION 7: DATA VALIDATION & CONSTRAINTS

### 7.1 Input Constraints
- [ ] Grade numbers are 1-12 only
- [ ] Section names follow naming conventions
- [ ] Subject names are from catalog only
- [ ] School name has reasonable max length
- [ ] School address has reasonable max length
- [ ] Empty values are handled appropriately
- [ ] Special characters are handled

### 7.2 Business Logic Validation
- [ ] Cannot proceed without at least 1 grade
- [ ] Cannot proceed without sections for all grades
- [ ] Cannot proceed without subjects for all grades
- [ ] All validation occurs at right step
- [ ] Validation messages are helpful
- [ ] Validation does not prevent legitimate data

### 7.3 Database Constraints
- [ ] Foreign key constraints are respected
- [ ] RLS policies enforce tenant isolation
- [ ] Unique constraints prevent duplicates
- [ ] Check constraints enforce valid data
- [ ] Cascade deletes work properly
- [ ] No orphaned records are created

---

## SECTION 8: USER EXPERIENCE

### 8.1 Visual Design
- [ ] UI is clean and professional
- [ ] Colors are consistent with app theme
- [ ] Text is readable (size, contrast)
- [ ] Spacing is appropriate
- [ ] Icons are clear and intuitive
- [ ] Buttons are clearly clickable
- [ ] Forms are well-organized
- [ ] Step indicators are prominent

### 8.2 Responsiveness
- [ ] Layout adapts to screen size
- [ ] UI works on mobile phones
- [ ] UI works on tablets
- [ ] UI works on larger screens
- [ ] Text is not truncated unnecessarily
- [ ] Buttons are appropriately sized
- [ ] Input fields are accessible
- [ ] No horizontal scrolling needed

### 8.3 Interactions
- [ ] Buttons give visual feedback on press
- [ ] Selected items show clear feedback
- [ ] Hover states work on web/desktop
- [ ] Touch targets are appropriately sized
- [ ] No unresponsive buttons
- [ ] Loading states are clear
- [ ] Success/error states are obvious
- [ ] Animations are smooth

### 8.4 Accessibility
- [ ] Text colors have sufficient contrast
- [ ] Font sizes are readable
- [ ] Input labels are associated with fields
- [ ] Error messages are clear and visible
- [ ] Keyboard navigation works
- [ ] Screen reader friendly (if applicable)
- [ ] Focus indicators are visible
- [ ] No color-only information

### 8.5 Performance
- [ ] Pages load quickly
- [ ] No noticeable lag during interaction
- [ ] Animations are smooth (60 FPS)
- [ ] Database queries are optimized
- [ ] API calls complete within reasonable time
- [ ] Subject catalog loads efficiently
- [ ] Large number of grades/sections/subjects handled
- [ ] Memory usage is reasonable

### 8.6 Error Messages
- [ ] Messages are user-friendly (not technical)
- [ ] Messages explain what went wrong
- [ ] Messages suggest how to fix (if applicable)
- [ ] Messages are visible and prominent
- [ ] Messages are easy to understand
- [ ] Error icons are clear
- [ ] Messages don't use jargon
- [ ] Tone is helpful and positive

---

## SECTION 9: EDGE CASES & SPECIAL SCENARIOS

### 9.1 Multiple Wizard Runs
- [ ] Admin can run setup wizard multiple times
- [ ] Second run updates previous configuration
- [ ] Data from previous run is replaced (not appended)
- [ ] Soft deletes handle old data properly
- [ ] No data loss occurs
- [ ] Wizard completes successfully second time

### 9.2 Large Data Sets
- [ ] All 12 grades can be selected
- [ ] All 26 letters (A-Z) can be sections (or max is enforced)
- [ ] Large number of subjects from catalog works
- [ ] No performance degradation with large data
- [ ] Database handles large inserts
- [ ] No timeout on large saves

### 9.3 Data Integrity
- [ ] Partially saved data is handled properly
- [ ] Transaction rollback on error prevents corruption
- [ ] Concurrent admin runs don't interfere
- [ ] No race conditions occur
- [ ] Data consistency is maintained

### 9.4 Session Handling
- [ ] Session timeout during setup shows error
- [ ] User can login again and continue
- [ ] Data is not lost on session timeout
- [ ] Re-login does not require re-entering data
- [ ] Session extends on activity
- [ ] Logout during setup is handled safely

### 9.5 Network Scenarios
- [ ] Slow network is handled gracefully
- [ ] Connection drop during save is detected
- [ ] Retry works after connection restored
- [ ] Offline mode shows appropriate message
- [ ] Subject loading waits for network
- [ ] No stale data is used

### 9.6 Browser/App Navigation
- [ ] Back button doesn't break flow
- [ ] App can be closed and reopened
- [ ] Completing setup on one device prevents re-setup on another
- [ ] Deep linking to admin page works
- [ ] No hardcoded navigation loops

---

## SECTION 10: POST-SETUP VERIFICATION

### 10.1 Database Verification
- [ ] Check `tenants` table: `is_initialized = true`
- [ ] Check `tenants` table: name and address are saved
- [ ] Check `grades` table: All selected grades exist
- [ ] Check `grades` table: `is_active = true` for new grades
- [ ] Check `grades` table: Old grades marked inactive (soft delete)
- [ ] Check `grade_sections` table: Sections exist for each grade
- [ ] Check `grade_sections` table: `is_active = true`
- [ ] Check `subjects` table: Subject records exist
- [ ] Check `grade_section_subject` table: Mappings exist
- [ ] Check `grade_section_subject` table: Correct counts
- [ ] No duplicate records exist
- [ ] All tenant_id values are correct
- [ ] No orphaned records exist

### 10.2 Teacher Onboarding
- [ ] Teachers can login after admin setup completes
- [ ] Teachers see only grades created by admin
- [ ] Teachers see only sections created by admin
- [ ] Teachers see only subjects available for their grade
- [ ] Teachers can assign subjects to sections
- [ ] No missing grade/section/subject combinations
- [ ] Teacher onboarding flow works correctly

### 10.3 Admin Dashboard
- [ ] Admin can access admin dashboard after setup
- [ ] Dashboard shows configured grades
- [ ] Dashboard shows configured sections
- [ ] Dashboard shows configured subjects
- [ ] Admin can edit configuration from dashboard
- [ ] Changes propagate to teachers' views
- [ ] Admin sees correct data in all views

### 10.4 Subsequent Setups
- [ ] Admin can run setup wizard again
- [ ] Re-running updates existing configuration
- [ ] Old data is properly replaced
- [ ] New configuration is fully functional
- [ ] Teachers can see new configuration
- [ ] No conflicts with old data

---

## SECTION 11: SECURITY

### 11.1 Access Control
- [ ] Only admin users can access setup wizard
- [ ] Teachers cannot access admin setup
- [ ] Unauthenticated users cannot access
- [ ] Role is verified on backend
- [ ] Tenant ID is verified
- [ ] No unauthorized data access

### 11.2 Data Protection
- [ ] Database queries use parameterized statements
- [ ] No SQL injection vulnerabilities
- [ ] RLS policies enforce data isolation
- [ ] Admin cannot access other tenants' data
- [ ] Sensitive data is not logged
- [ ] Input is validated before storage

### 11.3 API Security
- [ ] API calls require authentication
- [ ] API requests include valid JWT tokens
- [ ] Tokens are not exposed in logs
- [ ] HTTPS is used for all requests
- [ ] CORS is properly configured
- [ ] No sensitive data in URLs

---

## SECTION 12: FINAL CHECKLIST

- [ ] All 12 sections above have been tested
- [ ] No critical bugs found
- [ ] All blocking issues resolved
- [ ] Minor issues documented
- [ ] Performance is acceptable
- [ ] User experience is smooth
- [ ] Data integrity verified
- [ ] Security measures verified
- [ ] Documentation is complete
- [ ] Ready for production

---

## BUG REPORT TEMPLATE

For each bug found, document:

```
Bug ID: [Number]
Title: [Short description]
Severity: [Critical/High/Medium/Low]
Step: [Which step: 1/2/3/4]
Steps to Reproduce:
1. [Step 1]
2. [Step 2]
...

Expected Behavior:
[What should happen]

Actual Behavior:
[What actually happens]

Screenshots:
[If applicable]

Environment:
- Device: [Phone/Tablet/Web]
- OS: [iOS/Android/Web]
- App Version: [Version number]
- Date: [Date tested]

Workaround (if any):
[If there's a workaround]

Notes:
[Additional context]
```

---

## NOTES & OBSERVATIONS

[Space for general notes, observations, and recommendations]

