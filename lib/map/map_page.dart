import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/poi_service.dart';
import '../models/poi.dart';
import '../services/local_tts_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  List<Poi> _pois = [];

  @override
  void initState() {
    super.initState();
    _loadPois();
  }

  Future<void> _loadPois() async {
    final pois = await PoiService().loadPoi();
    setState(() {
      _pois = pois;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passear')),
      body: FlutterMap(
        options: MapOptions(
          center: LatLng(32.0741, 34.7924),
          zoom: 15,
          interactionOptions: const InteractionOptions(),
        ),
        children: [
          TileLayer(
            // urlTemplate: 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.passear',
          ),
          MarkerLayer(
            markers: _pois
                .map(
                  (poi) => Marker(
                    width: 40,
                    height: 40,
                    point: LatLng(poi.lat, poi.lon),
                    child: GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (_) => _PoiDetail(poi: poi),
                        );
                      },
                      child: const Icon(Icons.location_on, color: Colors.red),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _PoiDetail extends StatefulWidget {
  final Poi poi;
  const _PoiDetail({required this.poi});

  @override
  State<_PoiDetail> createState() => _PoiDetailState();
}

class _PoiDetailState extends State<_PoiDetail> {
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
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        children: [
          Text(poi.name,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(poi.description),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              tts.speak(poi.description);
            },
            icon: const Icon(Icons.volume_up),
            label: const Text("Listen"),
          )
        ],
      ),
    );
  }
}
