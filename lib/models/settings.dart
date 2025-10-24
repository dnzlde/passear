// lib/models/settings.dart
import 'poi.dart';

class AppSettings {
  final Map<PoiCategory, bool> enabledCategories;
  final int maxPoiCount;

  AppSettings({
    Map<PoiCategory, bool>? enabledCategories,
    this.maxPoiCount = 20,
  }) : enabledCategories = enabledCategories ?? _defaultEnabledCategories();

  static Map<PoiCategory, bool> _defaultEnabledCategories() {
    return {for (PoiCategory category in PoiCategory.values) category: true};
  }

  AppSettings copyWith({
    Map<PoiCategory, bool>? enabledCategories,
    int? maxPoiCount,
  }) {
    return AppSettings(
      enabledCategories: enabledCategories ?? this.enabledCategories,
      maxPoiCount: maxPoiCount ?? this.maxPoiCount,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final enabledCategoriesJson =
        json['enabledCategories'] as Map<String, dynamic>? ?? {};
    final enabledCategories = <PoiCategory, bool>{};

    for (PoiCategory category in PoiCategory.values) {
      enabledCategories[category] =
          enabledCategoriesJson[category.name] as bool? ?? true;
    }

    return AppSettings(
      enabledCategories: enabledCategories,
      maxPoiCount: json['maxPoiCount'] as int? ?? 20,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabledCategories': {
        for (var entry in enabledCategories.entries)
          entry.key.name: entry.value,
      },
      'maxPoiCount': maxPoiCount,
    };
  }

  /// Get count of enabled categories
  int get enabledCategoryCount =>
      enabledCategories.values.where((enabled) => enabled).length;

  /// Check if a category is enabled
  bool isCategoryEnabled(PoiCategory category) =>
      enabledCategories[category] ?? true;
}
