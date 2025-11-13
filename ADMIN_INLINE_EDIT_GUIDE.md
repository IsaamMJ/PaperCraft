# Admin Inline Edit Guide

## New Features Available in Paper Details Page

You can now edit more content directly from the paper details page without opening the full editor!

---

## Feature 1: Edit Section Headings

### How to Use
1. Open a paper in **edit/draft mode** (not view-only)
2. Look for each section heading in the "Questions" section
3. Click the **edit icon** (pencil ✏️) next to the section heading
4. A modal will open with the current section name
5. Edit the name as needed
6. Click **"Save Changes"**
7. The section name updates immediately

### Example
- Before: "Section 1: Arithmetic (5 questions)"
- Edit: Change "Arithmetic" to "Basic Mathematics"
- After: "Section 1: Basic Mathematics (5 questions)"

---

## Feature 2: Edit Match the Following Questions

### About This Question Type
Match the Following questions have two columns:
- **Column A**: Items to match
- **Column B**: Answers/matches

### How to Edit
1. Find a "Match the Following" question in the Questions section
2. Click the **edit icon** (pencil ✏️) next to it
3. The modal opens with a **two-column layout**:
   - **Left side**: Column A items
   - **Right side**: Column B items
4. Edit items in either column as needed
5. To **add a pair**: Click "Add Pair" button
6. To **remove a pair**: Click the delete icon (trash 🗑️) on that row
7. Click **"Save Changes"**

### Rules for Match the Following
⚠️ **Important**: Column A and Column B must have the **same number of items**

❌ Invalid:
- Column A: 3 items, Column B: 2 items
- Column A: empty, Column B: has items

✅ Valid:
- Column A: 3 items, Column B: 3 items
- Both columns are equally populated

### Example
```
Column A                  →  Column B
1. Mitochondria          →  Powerhouse of cell
2. Chloroplast           →  Site of photosynthesis
3. Nucleus               →  Controls cell activities
```

If you add a 4th item to Column A, you MUST also add a 4th match to Column B.

---

## Feature 3: Edit Question Text & Options

This feature already existed - quick reminder:

1. Click the edit icon (pencil ✏️) next to any question
2. Edit the question text
3. Edit options as needed:
   - **MCQ**: Add/remove answer choices
   - **Fill in the Blanks**: Add/remove words for the word bank
   - **Regular Questions**: Edit text only
4. Click **"Save Changes"**

---

## Things You CANNOT Edit (Yet)

- ❌ Add new questions to a section (use full editor)
- ❌ Delete questions (use full editor)
- ❌ Change question type (use full editor)
- ❌ Change question marks (use full editor)

---

## Tips & Tricks

### ✅ Do:
- Edit one thing at a time
- Save after each change
- Use descriptive section names
- Ensure matching pairs are balanced

### ❌ Don't:
- Leave section names empty
- Create unbalanced matching pairs
- Edit while offline (changes need database save)
- Edit paper after submission (if you want to resubmit, use "Edit Again")

---

## Validation Messages

If you see an error:

| Error | Cause | Solution |
|-------|-------|----------|
| "Section name cannot be empty" | Empty section name | Enter a section name |
| "Question text cannot be empty" | Empty question | Enter question text |
| "Both columns must have the same number of items" | Mismatched pair counts | Add/remove items to balance columns |
| "Both columns must have at least one item" | A column is empty | Add at least one item to each column |
| "At least one option is required" | No MCQ options | Add option text |

---

## Keyboard Shortcuts

Currently available:
- Press **Escape** to close any edit modal
- Click **Cancel** button to discard changes

---

## Questions or Issues?

If editing doesn't work:
1. Make sure you're in **edit mode** (not view-only)
2. Try **refreshing** the page
3. Check your **internet connection**
4. Contact support if problem persists

---

## Related Features

- **Print PDF**: Click "Print PDF" to preview the paper with your changes
- **Submit for Review**: After editing, use "Submit for Review" to send to approver
- **Edit Again**: If rejected, use "Edit Again" to make a new draft

---

**Last Updated**: November 2025
**Version**: 1.0 - Initial Release
