import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/poi_service.dart';
import '../models/poi.dart';

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

class _PoiDetail extends StatelessWidget {
  final Poi poi;

  const _PoiDetail({required this.poi});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(poi.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(poi.description),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text("Play Audio"),
            onPressed: () {
              // TODO: trigger audio playback
            },
          ),
        ],
      ),
    );
  }
}
