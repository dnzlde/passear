import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/local_tts_service.dart';
import '../services/poi_service.dart';
import '../services/llm_service.dart';
import '../services/settings_service.dart';
import '../models/poi.dart';

class WikiPoiDetail extends StatefulWidget {
  final Poi poi;
  final ScrollController? scrollController;
  final Function(LatLng)? onNavigate;
  const WikiPoiDetail({
    super.key,
    required this.poi,
    this.scrollController,
    this.onNavigate,
  });

  @override
  State<WikiPoiDetail> createState() => _WikiPoiDetailState();
}

class _WikiPoiDetailState extends State<WikiPoiDetail> {
  late final LocalTtsService tts;
  late final PoiService poiService;
  late final SettingsService settingsService;
  late Poi currentPoi;
  bool isLoadingDescription = false;
  bool isGeneratingStory = false;
  String? aiStory;
  LlmService? llmService;
  StoryStyle currentStyle = StoryStyle.neutral;

  @override
  void initState() {
    super.initState();
    tts = LocalTtsService();
    poiService = PoiService();
    settingsService = SettingsService.instance;
    currentPoi = widget.poi;

    // Load description if not already loaded
    if (!currentPoi.isDescriptionLoaded) {
      _loadDescription();
    }

    // Initialize LLM service
    _initializeLlmService();
  }

  Future<void> _initializeLlmService() async {
    final settings = await settingsService.loadSettings();
    if (settings.isLlmConfigured) {
      llmService = LlmService(
        config: LlmConfig(
          apiEndpoint: settings.llmApiEndpoint,
          apiKey: settings.llmApiKey,
          model: settings.llmModel,
        ),
      );
    }
  }

  Future<void> _loadDescription() async {
    if (isLoadingDescription || currentPoi.isDescriptionLoaded) return;

    setState(() {
      isLoadingDescription = true;
    });

    try {
      final updatedPoi = await poiService.fetchPoiDescription(currentPoi);
      setState(() {
        currentPoi = updatedPoi;
        isLoadingDescription = false;
      });
    } catch (e) {
      setState(() {
        isLoadingDescription = false;
      });
      // Handle error gracefully - the POI will remain without a description
    }
  }

  Future<void> _generateAiStory() async {
    if (llmService == null) {
      _showLlmNotConfiguredDialog();
      return;
    }

    if (currentPoi.description.isEmpty) {
      _showSnackBar('Please wait for the description to load first.');
      return;
    }

    setState(() {
      isGeneratingStory = true;
      aiStory = null;
    });

    try {
      final story = await llmService!.generateStory(
        poiName: currentPoi.name,
        poiDescription: currentPoi.description,
        style: currentStyle,
      );

      setState(() {
        aiStory = story;
        isGeneratingStory = false;
      });

      // Automatically play the story via TTS
      await tts.speak(story);
    } catch (e) {
      setState(() {
        isGeneratingStory = false;
      });
      _showSnackBar('Failed to generate AI story: ${e.toString()}');
    }
  }

  void _showLlmNotConfiguredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('LLM Not Configured'),
        content: const Text(
          'To use AI-generated stories, please configure your LLM API key in the app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    tts.dispose();
    llmService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poi = currentPoi;
    final description = poi.description;

    return SingleChildScrollView(
      controller: widget.scrollController,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    poi.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildInterestBadge(poi.interestLevel),
              ],
            ),
            const SizedBox(height: 8),
            if (poi.category != PoiCategory.generic)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Chip(
                  label: Text(_getCategoryDisplayName(poi.category)),
                  backgroundColor: _getCategoryColor(poi.category),
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            // Description section with loading state
            if (isLoadingDescription)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading description...'),
                    ],
                  ),
                ),
              )
            else if (description.isNotEmpty)
              Text(
                description,
                style: const TextStyle(fontSize: 16, height: 1.5),
              )
            else
              const Text(
                'No description available.',
                style: TextStyle(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            const SizedBox(height: 16),
            // AI Story section
            if (!isLoadingDescription && description.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed: isGeneratingStory ? null : _generateAiStory,
                    icon: isGeneratingStory
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: const Text('AI Story'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  if (isGeneratingStory)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Generating AI story...',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  if (aiStory != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.purple.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                size: 16,
                                color: Colors.purple,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'AI-Generated Story',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            aiStory!,
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => tts.speak(aiStory!),
                            icon: const Icon(Icons.volume_up, size: 16),
                            label: const Text('Play Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            // Action buttons
            if (description.isNotEmpty && !isLoadingDescription)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => tts.speak(description),
                      icon: const Icon(Icons.volume_up),
                      label: const Text("Listen"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.onNavigate != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          widget.onNavigate!(LatLng(poi.lat, poi.lon));
                        },
                        icon: const Icon(Icons.directions_walk),
                        label: const Text("Navigate"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            // Add extra padding at bottom for comfortable scrolling
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestBadge(PoiInterestLevel level) {
    IconData icon;
    Color color;
    String label;

    switch (level) {
      case PoiInterestLevel.high:
        icon = Icons.star;
        color = Colors.amber;
        label = 'Premium';
        break;
      case PoiInterestLevel.medium:
        icon = Icons.place;
        color = Colors.blue;
        label = 'Notable';
        break;
      case PoiInterestLevel.low:
        icon = Icons.location_on;
        color = Colors.grey;
        label = 'Local';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryDisplayName(PoiCategory category) {
    switch (category) {
      case PoiCategory.museum:
        return 'Museum';
      case PoiCategory.historicalSite:
        return 'Historical Site';
      case PoiCategory.landmark:
        return 'Landmark';
      case PoiCategory.religiousSite:
        return 'Religious Site';
      case PoiCategory.park:
        return 'Park';
      case PoiCategory.monument:
        return 'Monument';
      case PoiCategory.university:
        return 'University';
      case PoiCategory.theater:
        return 'Theater';
      case PoiCategory.gallery:
        return 'Gallery';
      case PoiCategory.architecture:
        return 'Architecture';
      case PoiCategory.generic:
        return 'Location';
    }
  }

  Color _getCategoryColor(PoiCategory category) {
    switch (category) {
      case PoiCategory.museum:
      case PoiCategory.gallery:
        return Colors.purple;
      case PoiCategory.historicalSite:
      case PoiCategory.landmark:
        return Colors.orange;
      case PoiCategory.religiousSite:
        return Colors.indigo;
      case PoiCategory.park:
        return Colors.green;
      case PoiCategory.monument:
        return Colors.red;
      case PoiCategory.university:
        return Colors.blue;
      case PoiCategory.theater:
        return Colors.pink;
      case PoiCategory.architecture:
        return Colors.teal;
      case PoiCategory.generic:
        return Colors.grey;
    }
  }
}
