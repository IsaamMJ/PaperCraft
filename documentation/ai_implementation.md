# AI Implementation Strategy for PaperCraft

**Last Updated:** January 2025
**Status:** Planning Phase

---

## Simple AI Feature: Question Polish & Improve

Instead of generating questions from scratch (syllabus problems), AI will **polish and improve** questions that teachers already wrote.

---

## What It Does

Teacher writes question → AI fixes:
- ✅ Spelling mistakes
- ✅ Grammar errors
- ✅ Punctuation
- ✅ Sentence clarity
- ✅ Question structure
- ✅ Option formatting (for MCQ)

---

## Why This Works Better

1. **No syllabus problem** - Teacher writes content, they know their syllabus
2. **Immediate value** - Every teacher needs grammar/spelling check
3. **Always useful** - Works for any board, subject, grade
4. **Build trust** - Small helpful feature first, bigger features later
5. **Low cost** - Only checking text, not generating from scratch

---

## Where to Add This Feature

**Location 1: Question Input Screens**
- File: `lib/features/paper_creation/presentation/widgets/question_input/*.dart`
- Add: "✨ Polish" button next to each question text field
- When clicked: AI fixes the question and shows suggestions

**Location 2: Paper Review**
- File: `lib/features/paper_review/presentation/pages/paper_review_page.dart`
- Auto-check all questions when paper submitted
- Show grammar/spelling issues to admin

---

## How It Works

```
Teacher types question with mistakes:
"What is the proces of fotosynthesis and it's importance"

AI polishes it to:
"What is the process of photosynthesis and its importance?"

Changes shown:
- Fixed: "proces" → "process"
- Fixed: "fotosynthesis" → "photosynthesis"
- Fixed: "it's" → "its"
```

---

## Implementation Steps

1. **Add AI service** - Call OpenAI API with prompt: "Fix grammar and spelling only"
2. **Add Polish button** - In each question input widget
3. **Show diff** - Highlight what changed (red = removed, green = added)
4. **Accept/Reject** - Teacher can accept all changes or keep original
5. **Auto-polish** - Optional setting to auto-fix on paper submit

**Cost:** ~$10-15/month for 100 teachers

---

## Technical Details

**Files to modify:**
- `lib/features/paper_creation/presentation/widgets/question_input/mcq_input_widget.dart`
- `lib/features/paper_creation/presentation/widgets/question_input/fill_blanks_input_widget.dart`
- (All other question input widgets)

**New service needed:**
- `lib/features/ai/domain/services/text_polish_service.dart`
- Simple API call: Send text → Get polished text back

**API Call:**
```
Send: "What is the proces of fotosynthesis"
Receive: {
  "polished": "What is the process of photosynthesis",
  "changes": ["proces→process", "fotosynthesis→photosynthesis"]
}
```

---

## Future: Add More Polish Features

Once teachers trust the basic feature, add:
- Improve clarity (make question clearer)
- Simplify language (easier for students)
- Make options parallel (for MCQ)
- Suggest better wording

