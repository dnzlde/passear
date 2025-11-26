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

  Future<void> _updateCategorySetting(
    PoiCategory category,
    bool enabled,
  ) async {
    await _settingsService.updateCategoryEnabled(category, enabled);
    setState(() {
      final updatedCategories = Map<PoiCategory, bool>.from(
        _settings.enabledCategories,
      );
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

  Future<void> _updateVoiceGuidanceEnabled(bool enabled) async {
    await _settingsService.updateVoiceGuidanceEnabled(enabled);
    setState(() {
      _settings = _settings.copyWith(voiceGuidanceEnabled: enabled);
    });
  }

  Future<void> _updateMapProvider(MapProvider provider) async {
    await _settingsService.updateMapProvider(provider);
    setState(() {
      _settings = _settings.copyWith(mapProvider: provider);
    });
  }

  Future<void> _updateRoutingProvider(RoutingProvider provider) async {
    await _settingsService.updateRoutingProvider(provider);
    setState(() {
      _settings = _settings.copyWith(routingProvider: provider);
    });
  }

  Future<void> _updatePoiProvider(PoiProvider provider) async {
    await _settingsService.updatePoiProvider(provider);
    setState(() {
      _settings = _settings.copyWith(poiProvider: provider);
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
        return Icons.account_balance;
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
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), elevation: 0),
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

          // Voice Guidance Setting
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Navigation Settings',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Voice Guidance'),
                    subtitle: const Text(
                      'Enable voice instructions during navigation',
                    ),
                    secondary: const Icon(Icons.volume_up),
                    value: _settings.voiceGuidanceEnabled,
                    onChanged: (value) {
                      _updateVoiceGuidanceEnabled(value);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Map Provider Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Map Provider',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose which map tiles to display',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ...MapProvider.values.map((provider) {
                    return RadioListTile<MapProvider>(
                      title: Text(provider.displayName),
                      subtitle: Row(
                        children: [
                          Text(provider.description),
                          if (provider.isFree) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'FREE',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      value: provider,
                      // ignore: deprecated_member_use
                      groupValue: _settings.mapProvider,
                      // ignore: deprecated_member_use
                      onChanged: (value) {
                        if (value != null) {
                          _updateMapProvider(value);
                        }
                      },
                      secondary: Icon(
                        provider == MapProvider.openStreetMap
                            ? Icons.map
                            : Icons.satellite,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Routing Provider Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Navigation/Routing Provider',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose which service to use for route calculation',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ...RoutingProvider.values.map((provider) {
                    return RadioListTile<RoutingProvider>(
                      title: Text(provider.displayName),
                      subtitle: Row(
                        children: [
                          Text(provider.description),
                          if (provider.isFree) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'FREE',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      value: provider,
                      // ignore: deprecated_member_use
                      groupValue: _settings.routingProvider,
                      // ignore: deprecated_member_use
                      onChanged: (value) {
                        if (value != null) {
                          _updateRoutingProvider(value);
                        }
                      },
                      secondary: Icon(
                        provider == RoutingProvider.osrm
                            ? Icons.directions
                            : Icons.navigation,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // POI Provider Selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'POI Provider',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose which service to use for Points of Interest',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ...PoiProvider.values.map((provider) {
                    return RadioListTile<PoiProvider>(
                      title: Text(provider.displayName),
                      subtitle: Row(
                        children: [
                          Flexible(child: Text(provider.description)),
                          if (provider.isFree) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'FREE',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      value: provider,
                      // ignore: deprecated_member_use
                      groupValue: _settings.poiProvider,
                      // ignore: deprecated_member_use
                      onChanged: (value) {
                        if (value != null) {
                          _updatePoiProvider(value);
                        }
                      },
                      secondary: Icon(
                        provider == PoiProvider.wikipedia
                            ? Icons.menu_book
                            : provider == PoiProvider.overpass
                            ? Icons.location_on
                            : Icons.place,
                      ),
                    );
                  }),
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
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
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
