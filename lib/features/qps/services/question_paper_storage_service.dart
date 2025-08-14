import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/question_paper_model.dart';
import '../domain/entities/exam_type_entity.dart';
import '../domain/entities/subject_entity.dart';
import '../presentation/widgets/question_input_widget.dart';

class QuestionPaperStorageService {
  static const String _keyPrefix = 'question_paper_';
  static const String _indexKey = 'question_paper_index';

  // Get SharedPreferences instance
  Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  // Get all question paper IDs with their status
  Future<Map<String, String>> _getQuestionPaperIndex() async {
    final prefs = await _getPrefs();
    final indexJson = prefs.getString(_indexKey);
    if (indexJson == null) return {};

    try {
      final Map<String, dynamic> indexData = jsonDecode(indexJson);
      return indexData.cast<String, String>();
    } catch (e) {
      print('Error parsing question paper index: $e');
      return {};
    }
  }

  // Update the question paper index
  Future<void> _updateQuestionPaperIndex(Map<String, String> index) async {
    final prefs = await _getPrefs();
    await prefs.setString(_indexKey, jsonEncode(index));
  }

  // Save question paper
  Future<bool> saveQuestionPaper(QuestionPaperModel questionPaper) async {
    try {
      final prefs = await _getPrefs();
      final key = '$_keyPrefix${questionPaper.id}';

      final jsonString = jsonEncode(questionPaper.toJson());
      await prefs.setString(key, jsonString);

      // Update index
      final index = await _getQuestionPaperIndex();
      index[questionPaper.id] = questionPaper.status;
      await _updateQuestionPaperIndex(index);

      return true;
    } catch (e) {
      print('Error saving question paper: $e');
      return false;
    }
  }

  // Load question paper by ID
  Future<QuestionPaperModel?> loadQuestionPaper(String id, String status) async {
    try {
      final prefs = await _getPrefs();
      final key = '$_keyPrefix$id';

      final jsonString = prefs.getString(key);
      if (jsonString == null) return null;

      final jsonData = jsonDecode(jsonString);
      final questionPaper = QuestionPaperModel.fromJson(jsonData);

      // Verify status matches (optional check)
      if (questionPaper.status != status) {
        print('Warning: Status mismatch for question paper $id');
      }

      return questionPaper;
    } catch (e) {
      print('Error loading question paper: $e');
      return null;
    }
  }

  // Get all question papers by status
  Future<List<QuestionPaperModel>> getQuestionPapersByStatus(String status) async {
    try {
      final prefs = await _getPrefs();
      final index = await _getQuestionPaperIndex();

      List<QuestionPaperModel> questionPapers = [];

      // Filter by status and load each question paper
      for (final entry in index.entries) {
        if (entry.value == status) {
          final key = '$_keyPrefix${entry.key}';
          final jsonString = prefs.getString(key);

          if (jsonString != null) {
            try {
              final jsonData = jsonDecode(jsonString);
              final questionPaper = QuestionPaperModel.fromJson(jsonData);
              questionPapers.add(questionPaper);
            } catch (e) {
              print('Error parsing question paper ${entry.key}: $e');
            }
          }
        }
      }

      // Sort by modified date (newest first)
      questionPapers.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));

      return questionPapers;
    } catch (e) {
      print('Error getting question papers: $e');
      return [];
    }
  }

  // Get all question papers
  Future<List<QuestionPaperModel>> getAllQuestionPapers() async {
    try {
      final prefs = await _getPrefs();
      final index = await _getQuestionPaperIndex();

      List<QuestionPaperModel> allPapers = [];

      // Load all question papers
      for (final id in index.keys) {
        final key = '$_keyPrefix$id';
        final jsonString = prefs.getString(key);

        if (jsonString != null) {
          try {
            final jsonData = jsonDecode(jsonString);
            final questionPaper = QuestionPaperModel.fromJson(jsonData);
            allPapers.add(questionPaper);
          } catch (e) {
            print('Error parsing question paper $id: $e');
          }
        }
      }

      // Sort by modified date (newest first)
      allPapers.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));

      return allPapers;
    } catch (e) {
      print('Error getting all question papers: $e');
      return [];
    }
  }

  // Delete question paper
  Future<bool> deleteQuestionPaper(String id, String status) async {
    try {
      final prefs = await _getPrefs();
      final key = '$_keyPrefix$id';

      // Remove from SharedPreferences
      await prefs.remove(key);

      // Update index
      final index = await _getQuestionPaperIndex();
      index.remove(id);
      await _updateQuestionPaperIndex(index);

      return true;
    } catch (e) {
      print('Error deleting question paper: $e');
      return false;
    }
  }

  // Move question paper between statuses
  Future<bool> moveQuestionPaper(QuestionPaperModel questionPaper, String newStatus) async {
    try {
      // Update the question paper with new status
      final updatedQuestionPaper = questionPaper.copyWith(
        status: newStatus,
        modifiedAt: DateTime.now(),
      );

      // Save the updated question paper
      return await saveQuestionPaper(updatedQuestionPaper);
    } catch (e) {
      print('Error moving question paper: $e');
      return false;
    }
  }

  // Update question paper status (for approval/rejection)
  Future<bool> updateQuestionPaperStatus({
    required QuestionPaperModel questionPaper,
    required String newStatus,
    String? rejectionReason,
    String? approvedBy,
  }) async {
    try {
      final updatedQuestionPaper = questionPaper.copyWith(
        status: newStatus,
        rejectionReason: rejectionReason,
        approvedBy: approvedBy,
        approvedAt: newStatus == 'approved' ? DateTime.now() : null,
        modifiedAt: DateTime.now(),
      );

      return await saveQuestionPaper(updatedQuestionPaper);
    } catch (e) {
      print('Error updating question paper status: $e');
      return false;
    }
  }

  // Search question papers
  Future<List<QuestionPaperModel>> searchQuestionPapers({
    String? title,
    String? subject,
    String? status,
    String? createdBy,
  }) async {
    final allPapers = status != null
        ? await getQuestionPapersByStatus(status)
        : await getAllQuestionPapers();

    return allPapers.where((paper) {
      bool matches = true;

      if (title != null && title.isNotEmpty) {
        matches = matches && paper.title.toLowerCase().contains(title.toLowerCase());
      }

      if (subject != null && subject.isNotEmpty) {
        matches = matches && paper.subject.toLowerCase().contains(subject.toLowerCase());
      }

      if (createdBy != null && createdBy.isNotEmpty) {
        matches = matches && paper.createdBy.toLowerCase().contains(createdBy.toLowerCase());
      }

      return matches;
    }).toList();
  }

  // Clear all question papers (for testing/cleanup)
  Future<bool> clearAllQuestionPapers() async {
    try {
      final prefs = await _getPrefs();
      final index = await _getQuestionPaperIndex();

      // Remove all question paper data
      for (final id in index.keys) {
        await prefs.remove('$_keyPrefix$id');
      }

      // Clear the index
      await prefs.remove(_indexKey);

      return true;
    } catch (e) {
      print('Error clearing question papers: $e');
      return false;
    }
  }

  // Get storage statistics
  Future<Map<String, int>> getStorageStats() async {
    final index = await _getQuestionPaperIndex();

    Map<String, int> stats = {
      'draft': 0,
      'submitted': 0,
      'approved': 0,
      'rejected': 0,
    };

    for (final status in index.values) {
      stats[status] = (stats[status] ?? 0) + 1;
    }

    return stats;
  }
}