
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/question_paper_model.dart';

abstract class PaperLocalDataSource {
  Future<void> saveDraft(QuestionPaperModel paper);
  Future<List<QuestionPaperModel>> getDrafts();
  Future<QuestionPaperModel?> getDraftById(String id);
  Future<void> deleteDraft(String id);
  Future<void> clearAllDrafts();
}

class PaperLocalDataSourceImpl implements PaperLocalDataSource {
  static const String _keyPrefix = 'draft_paper_';
  static const String _indexKey = 'draft_papers_index';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<void> saveDraft(QuestionPaperModel paper) async {
    final prefs = await _prefs;
    final key = '$_keyPrefix${paper.id}';

    // Save the paper
    await prefs.setString(key, jsonEncode(paper.toJson()));

    // Update index
    await _updateIndex(paper.id, add: true);
  }

  @override
  Future<List<QuestionPaperModel>> getDrafts() async {
    final prefs = await _prefs;
    final index = await _getIndex();

    final List<QuestionPaperModel> drafts = [];

    for (final id in index) {
      final key = '$_keyPrefix$id';
      final jsonString = prefs.getString(key);

      if (jsonString != null) {
        try {
          final jsonData = jsonDecode(jsonString);
          final paper = QuestionPaperModel.fromJson(jsonData);
          drafts.add(paper);
        } catch (e) {
          // Remove corrupted entry
          await prefs.remove(key);
          await _updateIndex(id, add: false);
        }
      }
    }

    // Sort by modified date (newest first)
    drafts.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return drafts;
  }

  @override
  Future<QuestionPaperModel?> getDraftById(String id) async {
    final prefs = await _prefs;
    final key = '$_keyPrefix$id';
    final jsonString = prefs.getString(key);

    if (jsonString == null) return null;

    try {
      final jsonData = jsonDecode(jsonString);
      return QuestionPaperModel.fromJson(jsonData);
    } catch (e) {
      // Remove corrupted entry
      await prefs.remove(key);
      await _updateIndex(id, add: false);
      return null;
    }
  }

  @override
  Future<void> deleteDraft(String id) async {
    final prefs = await _prefs;
    final key = '$_keyPrefix$id';

    await prefs.remove(key);
    await _updateIndex(id, add: false);
  }

  @override
  Future<void> clearAllDrafts() async {
    final prefs = await _prefs;
    final index = await _getIndex();

    // Remove all draft papers
    for (final id in index) {
      await prefs.remove('$_keyPrefix$id');
    }

    // Clear index
    await prefs.remove(_indexKey);
  }

  Future<Set<String>> _getIndex() async {
    final prefs = await _prefs;
    final indexJson = prefs.getString(_indexKey);

    if (indexJson == null) return <String>{};

    try {
      final List<dynamic> indexList = jsonDecode(indexJson);
      return indexList.cast<String>().toSet();
    } catch (e) {
      return <String>{};
    }
  }

  Future<void> _updateIndex(String id, {required bool add}) async {
    final prefs = await _prefs;
    final index = await _getIndex();

    if (add) {
      index.add(id);
    } else {
      index.remove(id);
    }

    await prefs.setString(_indexKey, jsonEncode(index.toList()));
  }
}
