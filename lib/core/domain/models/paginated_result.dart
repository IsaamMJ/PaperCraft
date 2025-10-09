// core/domain/models/paginated_result.dart
import 'package:equatable/equatable.dart';

/// Generic paginated result wrapper for list queries
class PaginatedResult<T> extends Equatable {
  final List<T> items;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final bool hasMore;
  final int pageSize;

  const PaginatedResult({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.hasMore,
    required this.pageSize,
  });

  bool get isFirstPage => currentPage == 1;
  bool get isLastPage => !hasMore;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;

  /// Create an empty paginated result
  factory PaginatedResult.empty({int pageSize = 20}) {
    return PaginatedResult<T>(
      items: [],
      currentPage: 1,
      totalPages: 0,
      totalItems: 0,
      hasMore: false,
      pageSize: pageSize,
    );
  }

  /// Create a single-page result (no pagination)
  factory PaginatedResult.single(List<T> items) {
    return PaginatedResult<T>(
      items: items,
      currentPage: 1,
      totalPages: 1,
      totalItems: items.length,
      hasMore: false,
      pageSize: items.length,
    );
  }

  /// Calculate pagination info from total count
  factory PaginatedResult.fromCount({
    required List<T> items,
    required int currentPage,
    required int totalItems,
    required int pageSize,
  }) {
    final totalPages = (totalItems / pageSize).ceil();
    final hasMore = currentPage < totalPages;

    return PaginatedResult<T>(
      items: items,
      currentPage: currentPage,
      totalPages: totalPages,
      totalItems: totalItems,
      hasMore: hasMore,
      pageSize: pageSize,
    );
  }

  PaginatedResult<T> copyWith({
    List<T>? items,
    int? currentPage,
    int? totalPages,
    int? totalItems,
    bool? hasMore,
    int? pageSize,
  }) {
    return PaginatedResult<T>(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalItems: totalItems ?? this.totalItems,
      hasMore: hasMore ?? this.hasMore,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  @override
  List<Object?> get props => [
        items,
        currentPage,
        totalPages,
        totalItems,
        hasMore,
        pageSize,
      ];
}
