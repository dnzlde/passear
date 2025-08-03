import 'package:flutter/material.dart';
import '../services/local_tts_service.dart';
import '../models/poi.dart';

class WikiPoiDetail extends StatefulWidget {
  final Poi poi;
  const WikiPoiDetail({super.key, required this.poi});

  @override
  State<WikiPoiDetail> createState() => _WikiPoiDetailState();
}

class _WikiPoiDetailState extends State<WikiPoiDetail> {
  late final LocalTtsService tts;

  @override
  void initState() {
    super.initState();
    tts = LocalTtsService();
  }

  @override
  void dispose() {
    tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poi = widget.poi;
    final description = poi.description;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Text(description),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => tts.speak(description),
            icon: const Icon(Icons.volume_up),
            label: const Text("Listen"),
          ),
        ],
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
