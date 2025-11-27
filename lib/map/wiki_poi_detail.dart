import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../services/local_tts_service.dart';
import '../services/poi_service.dart';
import '../services/ai_tour_guide_service.dart';
import '../services/settings_service.dart';
import '../models/poi.dart';

class WikiPoiDetail extends StatefulWidget {
  final Poi poi;
  final ScrollController? scrollController;
  final Function(LatLng)? onNavigate;
  final List<Poi>? nearbyPois;
  const WikiPoiDetail({
    super.key,
    required this.poi,
    this.scrollController,
    this.onNavigate,
    this.nearbyPois,
  });

  @override
  State<WikiPoiDetail> createState() => _WikiPoiDetailState();
}

class _WikiPoiDetailState extends State<WikiPoiDetail> {
  late final LocalTtsService tts;
  late final PoiService poiService;
  late final AiTourGuideService aiTourGuideService;
  late final SettingsService settingsService;
  late Poi currentPoi;
  bool isLoadingDescription = false;
  bool isGeneratingAiNarration = false;
  bool aiTourGuidingEnabled = false;
  String? aiNarration;

  @override
  void initState() {
    super.initState();
    tts = LocalTtsService();
    poiService = PoiService();
    aiTourGuideService = MockAiTourGuideService();
    settingsService = SettingsService.instance;
    currentPoi = widget.poi;

    // Load settings and description
    _loadSettings();
    if (!currentPoi.isDescriptionLoaded) {
      _loadDescription();
    }
  }

  Future<void> _loadSettings() async {
    final settings = await settingsService.loadSettings();
    if (mounted) {
      setState(() {
        aiTourGuidingEnabled = settings.aiTourGuidingEnabled;
      });
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

  Future<void> _generateAiNarration() async {
    if (isGeneratingAiNarration) return;

    setState(() {
      isGeneratingAiNarration = true;
    });

    try {
      final narration = await aiTourGuideService.generateNarration(
        poi: currentPoi,
        nearbyPois: widget.nearbyPois,
      );
      if (mounted) {
        setState(() {
          aiNarration = narration;
          isGeneratingAiNarration = false;
        });
        // Automatically speak the narration
        tts.speak(narration);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isGeneratingAiNarration = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate AI narration')),
        );
      }
    }
  }

  @override
  void dispose() {
    tts.dispose();
    aiTourGuideService.dispose();
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
            // Action buttons
            if (!isLoadingDescription)
              Column(
                children: [
                  Row(
                    children: [
                      if (description.isNotEmpty)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => tts.speak(description),
                            icon: const Icon(Icons.volume_up),
                            label: const Text("Listen"),
                          ),
                        ),
                      if (description.isNotEmpty) const SizedBox(width: 8),
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
                  // AI Tour Guide button
                  if (aiTourGuidingEnabled) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isGeneratingAiNarration
                            ? null
                            : _generateAiNarration,
                        icon: isGeneratingAiNarration
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.smart_toy),
                        label: Text(
                          isGeneratingAiNarration
                              ? "Generating..."
                              : "AI Tour Guide",
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  // Show AI narration if available
                  if (aiNarration != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.deepPurple.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.smart_toy,
                                size: 16,
                                color: Colors.deepPurple,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'AI Tour Guide',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.replay, size: 18),
                                onPressed: () => tts.speak(aiNarration!),
                                tooltip: 'Listen again',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            aiNarration!,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
