import 'package:flutter/material.dart';
import '../services/local_tts_service.dart';
import '../services/poi_service.dart';
import '../models/poi.dart';

class WikiPoiDetail extends StatefulWidget {
  final Poi poi;
  final ScrollController? scrollController;
  const WikiPoiDetail({super.key, required this.poi, this.scrollController});

  @override
  State<WikiPoiDetail> createState() => _WikiPoiDetailState();
}

class _WikiPoiDetailState extends State<WikiPoiDetail> {
  late final LocalTtsService tts;
  late final PoiService poiService;
  late Poi currentPoi;
  bool isLoadingDescription = false;

  @override
  void initState() {
    super.initState();
    tts = LocalTtsService();
    poiService = PoiService();
    currentPoi = widget.poi;
    
    // Load description if not already loaded
    if (!currentPoi.isDescriptionLoaded) {
      _loadDescription();
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

  @override
  void dispose() {
    tts.dispose();
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
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
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
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            const SizedBox(height: 16),
            if (description.isNotEmpty && !isLoadingDescription)
              ElevatedButton.icon(
                onPressed: () => tts.speak(description),
                icon: const Icon(Icons.volume_up),
                label: const Text("Listen"),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
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
