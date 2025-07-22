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
    final description = poi.description ?? 'No description';

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        children: [
          Text(
            poi.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
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
}
