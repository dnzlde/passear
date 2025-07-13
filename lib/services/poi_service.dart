import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/poi.dart';

class PoiService {
  Future<List<Poi>> loadPoi() async {
    final jsonStr = await rootBundle.loadString('assets/data/poi.json');
    final List<dynamic> jsonList = json.decode(jsonStr);
    return jsonList.map((e) => Poi.fromJson(e)).toList();
  }
}
