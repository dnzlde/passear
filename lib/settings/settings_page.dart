// lib/settings/settings_page.dart
import 'package:flutter/material.dart';
import '../models/poi.dart';
import '../models/settings.dart';
import '../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _settingsService = SettingsService.instance;
  late AppSettings _settings;
  bool _isLoading = true;
  int _totalPoiCount = 0; // Will be updated by parent/POI service

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsService.loadSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _settings = AppSettings();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateCategorySetting(PoiCategory category, bool enabled) async {
    await _settingsService.updateCategoryEnabled(category, enabled);
    setState(() {
      final updatedCategories = Map<PoiCategory, bool>.from(_settings.enabledCategories);
      updatedCategories[category] = enabled;
      _settings = _settings.copyWith(enabledCategories: updatedCategories);
    });
  }

  Future<void> _updateMaxPoiCount(int count) async {
    await _settingsService.updateMaxPoiCount(count);
    setState(() {
      _settings = _settings.copyWith(maxPoiCount: count);
    });
  }

  String _getCategoryDisplayName(PoiCategory category) {
    switch (category) {
      case PoiCategory.museum:
        return 'Museums';
      case PoiCategory.historicalSite:
        return 'Historical Sites';
      case PoiCategory.landmark:
        return 'Landmarks';
      case PoiCategory.religiousSite:
        return 'Religious Sites';
      case PoiCategory.park:
        return 'Parks';
      case PoiCategory.monument:
        return 'Monuments';
      case PoiCategory.university:
        return 'Universities';
      case PoiCategory.theater:
        return 'Theaters';
      case PoiCategory.gallery:
        return 'Galleries';
      case PoiCategory.architecture:
        return 'Architecture';
      case PoiCategory.generic:
        return 'Other POIs';
    }
  }

  IconData _getCategoryIcon(PoiCategory category) {
    switch (category) {
      case PoiCategory.museum:
        return Icons.museum;
      case PoiCategory.historicalSite:
        return Icons.castle;
      case PoiCategory.landmark:
        return Icons.landscape;
      case PoiCategory.religiousSite:
        return Icons.temple_buddhist;
      case PoiCategory.park:
        return Icons.park;
      case PoiCategory.monument:
        return Icons.monument;
      case PoiCategory.university:
        return Icons.school;
      case PoiCategory.theater:
        return Icons.theater_comedy;
      case PoiCategory.gallery:
        return Icons.palette;
      case PoiCategory.architecture:
        return Icons.architecture;
      case PoiCategory.generic:
        return Icons.place;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('POI Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'POI Display Settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Categories enabled: ${_settings.enabledCategoryCount} of ${PoiCategory.values.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    'Max POIs to show: ${_settings.maxPoiCount}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Max POI Count Setting
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Maximum POIs to Display',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _settings.maxPoiCount.toDouble(),
                    min: 5,
                    max: 50,
                    divisions: 9,
                    label: '${_settings.maxPoiCount}',
                    onChanged: (value) {
                      _updateMaxPoiCount(value.round());
                    },
                  ),
                  Text(
                    'Current: ${_settings.maxPoiCount} POIs',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // POI Categories
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'POI Categories',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toggle which types of Points of Interest to show on the map',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...PoiCategory.values.map((category) {
                    final isEnabled = _settings.isCategoryEnabled(category);
                    return SwitchListTile(
                      title: Text(_getCategoryDisplayName(category)),
                      subtitle: Text(category.name),
                      secondary: Icon(_getCategoryIcon(category)),
                      value: isEnabled,
                      onChanged: (value) {
                        _updateCategorySetting(category, value);
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Quick Actions
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Enable all categories
                            for (final category in PoiCategory.values) {
                              await _updateCategorySetting(category, true);
                            }
                          },
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Enable All'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            // Disable all categories
                            for (final category in PoiCategory.values) {
                              await _updateCategorySetting(category, false);
                            }
                          },
                          icon: const Icon(Icons.cancel),
                          label: const Text('Disable All'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}