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

  // Controllers for LLM settings
  late final TextEditingController _llmApiKeyController;
  late final TextEditingController _llmApiEndpointController;
  late final TextEditingController _llmModelController;
  
  // Controllers for TTS settings
  late final TextEditingController _ttsVoiceController;

  @override
  void initState() {
    super.initState();
    _llmApiKeyController = TextEditingController();
    _llmApiEndpointController = TextEditingController();
    _llmModelController = TextEditingController();
    _ttsVoiceController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _llmApiKeyController.dispose();
    _llmApiEndpointController.dispose();
    _llmModelController.dispose();
    _ttsVoiceController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsService.loadSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
        // Update controllers with loaded settings
        _llmApiKeyController.text = settings.llmApiKey;
        _llmApiEndpointController.text = settings.llmApiEndpoint;
        _llmModelController.text = settings.llmModel;
        _ttsVoiceController.text = settings.ttsVoice;
      });
    } catch (e) {
      setState(() {
        _settings = AppSettings();
        _isLoading = false;
        // Update controllers with default settings
        _llmApiKeyController.text = _settings.llmApiKey;
        _llmApiEndpointController.text = _settings.llmApiEndpoint;
        _llmModelController.text = _settings.llmModel;
        _ttsVoiceController.text = _settings.ttsVoice;
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

  Future<void> _updateTourAudioEnabled(bool enabled) async {
    await _settingsService.updateTourAudioEnabled(enabled);
    setState(() {
      _settings = _settings.copyWith(tourAudioEnabled: enabled);
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

  Future<void> _updateLlmApiKey(String apiKey) async {
    await _settingsService.updateLlmApiKey(apiKey);
    setState(() {
      _settings = _settings.copyWith(llmApiKey: apiKey);
    });
  }

  Future<void> _updateLlmApiEndpoint(String endpoint) async {
    await _settingsService.updateLlmApiEndpoint(endpoint);
    setState(() {
      _settings = _settings.copyWith(llmApiEndpoint: endpoint);
    });
  }

  Future<void> _updateLlmModel(String model) async {
    await _settingsService.updateLlmModel(model);
    setState(() {
      _settings = _settings.copyWith(llmModel: model);
    });
  }

  Future<void> _updateTtsVoice(String voice) async {
    final updatedSettings = _settings.copyWith(ttsVoice: voice);
    await _settingsService.saveSettings(updatedSettings);
    setState(() {
      _settings = updatedSettings;
    });
  }

  Future<void> _updateTtsOfflineMode(bool offlineMode) async {
    final updatedSettings = _settings.copyWith(ttsOfflineMode: offlineMode);
    await _settingsService.saveSettings(updatedSettings);
    setState(() {
      _settings = updatedSettings;
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
                    'Audio Settings',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Voice Guidance'),
                    subtitle: const Text(
                      'Enable voice instructions during navigation',
                    ),
                    secondary: const Icon(Icons.directions_walk),
                    value: _settings.voiceGuidanceEnabled,
                    onChanged: (value) {
                      _updateVoiceGuidanceEnabled(value);
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Tour Audio'),
                    subtitle: const Text(
                      'Enable audio playback for POI descriptions',
                    ),
                    secondary: const Icon(Icons.volume_up),
                    value: _settings.tourAudioEnabled,
                    onChanged: (value) {
                      _updateTourAudioEnabled(value);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // AI Story (LLM) Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.purple[400]),
                      const SizedBox(width: 8),
                      Text(
                        'AI Story Configuration',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure LLM API for AI-generated POI stories',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _settings.isLlmConfigured
                          ? Colors.green[100]
                          : Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _settings.isLlmConfigured
                              ? Icons.check_circle
                              : Icons.info,
                          size: 16,
                          color: _settings.isLlmConfigured
                              ? Colors.green[800]
                              : Colors.orange[800],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _settings.isLlmConfigured
                              ? 'LLM Configured'
                              : 'LLM Not Configured',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _settings.isLlmConfigured
                                ? Colors.green[800]
                                : Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // API Key field
                  TextField(
                    controller: _llmApiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'API Key',
                      hintText: 'Enter your LLM API key',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vpn_key),
                    ),
                    obscureText: true,
                    onChanged: (value) {
                      _updateLlmApiKey(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  // API Endpoint field
                  TextField(
                    controller: _llmApiEndpointController,
                    decoration: const InputDecoration(
                      labelText: 'API Endpoint',
                      hintText: 'https://api.openai.com/v1/chat/completions',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                    onChanged: (value) {
                      _updateLlmApiEndpoint(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Model field
                  TextField(
                    controller: _llmModelController,
                    decoration: const InputDecoration(
                      labelText: 'Model',
                      hintText: 'gpt-3.5-turbo',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.model_training),
                    ),
                    onChanged: (value) {
                      _updateLlmModel(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Help text
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 20, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                           child: Text(
                            'To get AI-generated stories for POI, configure your OpenAI API key or compatible LLM endpoint. Get your API key from platform.openai.com',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // TTS (Text-to-Speech) Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.record_voice_over, color: Colors.blue[400]),
                      const SizedBox(width: 8),
                      Text(
                        'Text-to-Speech Voice',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose voice for TTS. Uses the same OpenAI API key as AI stories above.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _settings.llmApiKey.isNotEmpty
                          ? Colors.green[100]
                          : Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _settings.llmApiKey.isNotEmpty
                              ? Icons.check_circle
                              : Icons.info,
                          size: 16,
                          color: _settings.llmApiKey.isNotEmpty
                              ? Colors.green[800]
                              : Colors.orange[800],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _settings.llmApiKey.isNotEmpty
                              ? 'OpenAI TTS Enabled'
                              : 'Using Offline TTS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _settings.llmApiKey.isNotEmpty
                                ? Colors.green[800]
                                : Colors.orange[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Voice field
                  TextField(
                    controller: _ttsVoiceController,
                    decoration: const InputDecoration(
                      labelText: 'Voice',
                      hintText: 'alloy, echo, fable, onyx, nova, shimmer',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.voice_chat),
                    ),
                    onChanged: (value) {
                      _updateTtsVoice(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Offline mode checkbox for testing
                  CheckboxListTile(
                    title: const Text('Force Offline Mode (Testing)'),
                    subtitle: const Text(
                      'Test Piper offline TTS without disabling internet. AI features will still work.',
                    ),
                    value: _settings.ttsOfflineMode,
                    onChanged: (value) {
                      _updateTtsOfflineMode(value ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 12),
                  // Help text
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            size: 20, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'TTS uses the OpenAI API key configured above for high-quality multilingual speech. Without a key, offline TTS is used automatically. Choose from voices: alloy (neutral), echo (male), fable (expressive), onyx (deep male), nova (female), shimmer (gentle female).',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
                      ],
                    ),
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
