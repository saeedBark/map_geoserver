import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  List<Marker> geoJsonMarkers = [];
  List<LatLng> routePoints = [];
  final MapController _mapController = MapController();
  LatLng? userLocation;
  LatLng? selectedStation;
  String distance = '';

  @override
  void initState() {
    super.initState();
    _startListeningToLocation();
    _loadGeoJsonData();
  }

  void _startListeningToLocation() {
    Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        userLocation = LatLng(position.latitude, position.longitude);
        if (selectedStation != null) {
          _calculateRoute();
        }
      });
    });
  }

  Future<void> _loadGeoJsonData() async {
    final url =
        'http://172.20.10.3:8080/geoserver/map/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=map%3Aamenity_school_Nouakchott_again&maxFeatures=50&outputFormat=application%2Fjson';

    try {
      final data = geoJsonData;

      if (data.isNotEmpty) {
        final features = data['features'];

        List<Marker> markers = [];
        for (var feature in features) {
          final geometry = feature['geometry'];
          if (geometry['type'] == 'MultiPolygon') {
            final coordinates = geometry['coordinates'][0][0];
            for (var coordinate in coordinates) {
              final point = LatLng(coordinate[1], coordinate[0]);
              markers.add(Marker(
                width: 80.0,
                height: 80.0,
                point: point,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedStation = point;
                    });
                    _calculateRoute();
                  },
                  child: const Icon(
                    Icons.school,
                    color: Colors.red,
                    size: 20.0,
                  ),
                ),
              ));
            }
          }
        }

        setState(() {
          geoJsonMarkers = markers;
        });
      } else {
        print('Failed to load GeoJSON data. Status code: ');
      }
    } catch (e) {
      print('Error loading GeoJSON data: $e');
    }
  }

  Future<void> _calculateRoute() async {
    if (userLocation == null || selectedStation == null) return;

    final apiKey = '5b3ce3597851110001cf62482a9fa2ebc51644fcbafae920e421322b';
    final url =
        'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$apiKey&start=${userLocation!.longitude},${userLocation!.latitude}&end=${selectedStation!.longitude},${selectedStation!.latitude}';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final coordinates = data['features'][0]['geometry']['coordinates'];
      final distanceInMeters =
          data['features'][0]['properties']['segments'][0]['distance'];

      List<LatLng> points = [];
      for (var coord in coordinates) {
        points.add(LatLng(coord[1], coord[0]));
      }

      setState(() {
        routePoints = points;
        distance = (distanceInMeters / 1000).toStringAsFixed(2) + ' km';
      });
    } else {
      throw Exception('Failed to load route data');
    }
  }

  void _zoomIn() {
    _mapController.move(_mapController.center, _mapController.zoom + 1);
  }

  void _zoomOut() {
    _mapController.move(_mapController.center, _mapController.zoom - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stations Services à Nouakchott"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              onTap: (tapPosition, point) {
                print(point.longitude);
              },
              onMapEvent: (p0) {
                p0.camera;
              },
              initialCenter: const LatLng(18.079021,
                  -15.965238), // Coordinates approximative de Nouakchott
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              MarkerLayer(
                markers: geoJsonMarkers,
              ),
              if (userLocation !=
                  null) // Afficher le marqueur de la position de l'utilisateur
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 80.0,
                      height: 80.0,
                      point: userLocation!,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.blue,
                        size: 40.0,
                      ),
                    )
                  ],
                ),
              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Column(
              children: [
                FloatingActionButton(
                  onPressed: _zoomIn,
                  child: const Icon(Icons.zoom_in),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  onPressed: _zoomOut,
                  child: const Icon(Icons.zoom_out),
                ),
              ],
            ),
          ),
          if (selectedStation != null)
            Positioned(
              bottom: 10,
              left: 10,
              child: Container(
                color: const Color.fromRGBO(18, 45, 220, 0.5),
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Distance: $distance',
                  style: const TextStyle(fontSize: 16.0, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Map<String, dynamic> geoJsonData = {
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.1",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9366764, 18.1162767],
              [-15.9363309, 18.116706],
              [-15.9359409, 18.1163653],
              [-15.93621, 18.1159483],
              [-15.9366764, 18.1162767]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229021206",
        "osm_id": "229021206",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": "École primaire"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.2",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9291538, 18.1115568],
              [-15.9286654, 18.1122565],
              [-15.9282672, 18.1119857],
              [-15.9287521, 18.111328],
              [-15.9291538, 18.1115568]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229021207",
        "osm_id": "229021207",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.3",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9286371, 18.1112641],
              [-15.9281345, 18.1118848],
              [-15.9278178, 18.1116611],
              [-15.9283062, 18.111069],
              [-15.9286371, 18.1112641]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229021208",
        "osm_id": "229021208",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.4",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9307623, 18.1075977],
              [-15.9306308, 18.1077674],
              [-15.9301564, 18.1083797],
              [-15.9297743, 18.1081212],
              [-15.9303905, 18.1073196],
              [-15.9307623, 18.1075977]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229021214",
        "osm_id": "229021214",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.5",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9281815, 18.1023137],
              [-15.9278859, 18.1026916],
              [-15.9274172, 18.1023604],
              [-15.9277128, 18.1019825],
              [-15.9281815, 18.1023137]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229021215",
        "osm_id": "229021215",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.6",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9334978, 18.0933378],
              [-15.9327214, 18.0932379],
              [-15.9328279, 18.0924896],
              [-15.9336044, 18.0925895],
              [-15.9334978, 18.0933378]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229021218",
        "osm_id": "229021218",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.7",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9371281, 18.0838789],
              [-15.9366621, 18.0837912],
              [-15.9368411, 18.0831129],
              [-15.9369522, 18.0825772],
              [-15.9373657, 18.0826638],
              [-15.9372615, 18.0832876],
              [-15.9371281, 18.0838789]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229021219",
        "osm_id": "229021219",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": "ÉCOLE FATIMA ZAHRA",
        "barrier": "wall",
        "name": "مدرسة الزعتر الابتدائية"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.8",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.941411, 18.075611],
              [-15.9406956, 18.0754281],
              [-15.9409341, 18.0745652],
              [-15.9416495, 18.0747371],
              [-15.941411, 18.075611]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229021221",
        "osm_id": "229021221",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": "مدرسة",
        "name:fr": null,
        "barrier": null,
        "name": "مدرسة"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.9",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9470958, 18.0837549],
              [-15.9468095, 18.0837215],
              [-15.9466552, 18.0837035],
              [-15.9463899, 18.0836726],
              [-15.9463673, 18.08367],
              [-15.9461572, 18.0836455],
              [-15.9461658, 18.0835548],
              [-15.9461886, 18.0833131],
              [-15.9461964, 18.0832299],
              [-15.9462402, 18.0827658],
              [-15.9471796, 18.0828114],
              [-15.9471379, 18.0832805],
              [-15.9471193, 18.0834904],
              [-15.9470958, 18.0837549]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229021222",
        "osm_id": "229021222",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.10",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9388058, 18.126883],
              [-15.9381093, 18.1277103],
              [-15.9369069, 18.1268576],
              [-15.9376071, 18.1259793],
              [-15.9388058, 18.126883]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229122017",
        "osm_id": "229122017",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": "طريق صكوك",
        "addr:city": "نواكشوط",
        "name:ar": "مدرسة ثانوية تيارت",
        "name:fr": "Lycée Teyaret",
        "barrier": null,
        "name": "مدرسة ثانوية تيارت"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.11",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9376071, 18.1259793],
              [-15.9369069, 18.1268576],
              [-15.9363773, 18.1264699],
              [-15.9361685, 18.1263246],
              [-15.9362874, 18.1261702],
              [-15.9368571, 18.1254383],
              [-15.9376071, 18.1259793]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229122019",
        "osm_id": "229122019",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": "طريق صكوك",
        "addr:city": "نواكشوط",
        "name:ar": "كلية",
        "name:fr": "COLLEGE",
        "barrier": null,
        "name": "كلية"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.12",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9306625, 18.1324426],
              [-15.9304851, 18.1326579],
              [-15.930478, 18.1326615],
              [-15.9303259, 18.1328571],
              [-15.9299194, 18.1325716],
              [-15.9302587, 18.1321352],
              [-15.9302759, 18.1321549],
              [-15.9304844, 18.1323101],
              [-15.9305905, 18.132389],
              [-15.9306625, 18.1324426]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229122021",
        "osm_id": "229122021",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.13",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9352265, 18.1329026],
              [-15.9348247, 18.1334093],
              [-15.9341464, 18.1329235],
              [-15.9345482, 18.1324167],
              [-15.9352265, 18.1329026]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229122022",
        "osm_id": "229122022",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.14",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9381827, 18.1189317],
              [-15.9378993, 18.1192956],
              [-15.9374715, 18.1189948],
              [-15.9377549, 18.1186307],
              [-15.9381827, 18.1189317]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229228322",
        "osm_id": "229228322",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.15",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9408725, 18.1243051],
              [-15.9404872, 18.1247692],
              [-15.9401165, 18.1244913],
              [-15.9395926, 18.1240985],
              [-15.939611, 18.1240763],
              [-15.9395837, 18.1240558],
              [-15.9399507, 18.1236138],
              [-15.9404836, 18.1240135],
              [-15.9408725, 18.1243051]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229228369",
        "osm_id": "229228369",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": "Mo-Fr 08:00-14:00",
        "name:en": "Primary School",
        "addr:street": null,
        "addr:city": "نواكشوط",
        "name:ar": "مدرسة ابتدائية",
        "name:fr": null,
        "barrier": "wall",
        "name": "École Primaire"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.16",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9450573, 18.0420844],
              [-15.9449427, 18.0422815],
              [-15.9448477, 18.0424389],
              [-15.9447628, 18.0425751],
              [-15.9447548, 18.0425955],
              [-15.9447252, 18.0426439],
              [-15.9446944, 18.0426935],
              [-15.944599, 18.042858],
              [-15.944009, 18.042542],
              [-15.9444674, 18.0417684],
              [-15.9450573, 18.0420844]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229232444",
        "osm_id": "229232444",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.17",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9341949, 18.0778079],
              [-15.9332235, 18.0776925],
              [-15.9333543, 18.076849],
              [-15.9343116, 18.0769378],
              [-15.9341949, 18.0778079]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229232449",
        "osm_id": "229232449",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": "نواكشوط",
        "name:ar": "مدرسة",
        "name:fr": null,
        "barrier": null,
        "name": "مدرسة"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.18",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9325524, 18.0723133],
              [-15.9321409, 18.0722343],
              [-15.9315828, 18.0721271],
              [-15.9315499, 18.0721208],
              [-15.9317133, 18.0715081],
              [-15.9317796, 18.0712594],
              [-15.9327049, 18.071404],
              [-15.9325524, 18.0723133]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229232453",
        "osm_id": "229232453",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.19",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9266287, 18.0691952],
              [-15.9258689, 18.0691953],
              [-15.9258944, 18.0682844],
              [-15.9266418, 18.0682976],
              [-15.9266287, 18.0691952]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229232454",
        "osm_id": "229232454",
        "osm_type": "way",
        "amenity": "school",
        "office": "educational_institution",
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": "ثانوية بوحديده",
        "name:fr": "Lycée Bouhdida",
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.20",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9211395, 18.0748592],
              [-15.9203729, 18.0747334],
              [-15.9205383, 18.0736638],
              [-15.9214428, 18.0738735],
              [-15.9211395, 18.0748592]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229232457",
        "osm_id": "229232457",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.21",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9135627, 18.0744322],
              [-15.912655, 18.0743152],
              [-15.9127473, 18.0734303],
              [-15.9136499, 18.0734935],
              [-15.9135627, 18.0744322]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229232459",
        "osm_id": "229232459",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": "نواكشوط",
        "name:ar": "مدرسة",
        "name:fr": null,
        "barrier": "wall",
        "name": "مدرسة"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.22",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9334508, 18.1409849],
              [-15.933085, 18.1414188],
              [-15.9326878, 18.1411165],
              [-15.9330536, 18.1406825],
              [-15.9334508, 18.1409849]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229481330",
        "osm_id": "229481330",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.23",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9259132, 18.1381477],
              [-15.9254714, 18.1388656],
              [-15.9254011, 18.138833],
              [-15.9250786, 18.1386838],
              [-15.9250478, 18.1386695],
              [-15.9246011, 18.1384626],
              [-15.925034, 18.1377404],
              [-15.9254424, 18.1379296],
              [-15.9259132, 18.1381477]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229481331",
        "osm_id": "229481331",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.24",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9142676, 18.1197363],
              [-15.9138137, 18.1203065],
              [-15.9134189, 18.1200342],
              [-15.9133702, 18.120004],
              [-15.9138502, 18.1194238],
              [-15.9139393, 18.1194905],
              [-15.9141416, 18.119642],
              [-15.9142676, 18.1197363]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229481332",
        "osm_id": "229481332",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.25",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9213689, 18.1129374],
              [-15.9209733, 18.113416],
              [-15.9207238, 18.1132342],
              [-15.9205832, 18.1131236],
              [-15.920572, 18.1131163],
              [-15.9210294, 18.112563],
              [-15.9212558, 18.112732],
              [-15.921194, 18.1128068],
              [-15.9213689, 18.1129374]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229481333",
        "osm_id": "229481333",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.26",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9045823, 18.0655595],
              [-15.9041684, 18.0660528],
              [-15.9037894, 18.065881],
              [-15.9039002, 18.0655318],
              [-15.9045823, 18.0655595]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229838925",
        "osm_id": "229838925",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.27",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9036872, 18.0667225],
              [-15.903484, 18.0670888],
              [-15.9029795, 18.0669056],
              [-15.9032528, 18.0664527],
              [-15.9036872, 18.0667225]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229838926",
        "osm_id": "229838926",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.28",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9208126, 18.0650381],
              [-15.9206353, 18.0650296],
              [-15.9197665, 18.0650203],
              [-15.9197689, 18.0654127],
              [-15.9197701, 18.0656706],
              [-15.9197732, 18.0657312],
              [-15.919895, 18.0657401],
              [-15.9201864, 18.0657593],
              [-15.9203388, 18.0657255],
              [-15.9205915, 18.0656624],
              [-15.9208798, 18.0655806],
              [-15.9208612, 18.0653911],
              [-15.9208126, 18.0650381]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229839702",
        "osm_id": "229839702",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.29",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9295284, 18.0619947],
              [-15.9289581, 18.0618541],
              [-15.9292079, 18.0611041],
              [-15.9297819, 18.0612775],
              [-15.9295284, 18.0619947]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229839703",
        "osm_id": "229839703",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.30",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9352253, 18.0668509],
              [-15.9347872, 18.0667716],
              [-15.9349238, 18.0660894],
              [-15.9353619, 18.0661686],
              [-15.9353097, 18.0664292],
              [-15.9352253, 18.0668509]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w229839722",
        "osm_id": "229839722",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.31",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9293426, 18.0666599],
              [-15.9289134, 18.0672168],
              [-15.9284103, 18.0667925],
              [-15.9287509, 18.0663435],
              [-15.9293426, 18.0666599]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w230051572",
        "osm_id": "230051572",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.32",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9273626, 18.0991763],
              [-15.9269149, 18.0988539],
              [-15.9272207, 18.0984701],
              [-15.9276684, 18.0987925],
              [-15.9273626, 18.0991763]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w230056952",
        "osm_id": "230056952",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": "نواكشوط",
        "name:ar": "مدرسة",
        "name:fr": null,
        "barrier": null,
        "name": "مدرسة"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.33",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9333449, 18.0997914],
              [-15.932997, 18.1002048],
              [-15.9325778, 18.0999004],
              [-15.9329139, 18.0994832],
              [-15.9333449, 18.0997914]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w230280332",
        "osm_id": "230280332",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.34",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9311879, 18.1414806],
              [-15.9310578, 18.141616],
              [-15.9309456, 18.1415187],
              [-15.9310758, 18.1413832],
              [-15.9311879, 18.1414806]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w230488585",
        "osm_id": "230488585",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.35",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9080806, 18.0734202],
              [-15.9077314, 18.0733882],
              [-15.9076622, 18.073602],
              [-15.9073749, 18.0735824],
              [-15.9076007, 18.0728274],
              [-15.908241, 18.0729062],
              [-15.9080806, 18.0734202]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w230777723",
        "osm_id": "230777723",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.36",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.8990647, 18.0628807],
              [-15.8991255, 18.0628857],
              [-15.8990469, 18.0627138],
              [-15.8985765, 18.0617301],
              [-15.898193, 18.0625962],
              [-15.8985284, 18.0627057],
              [-15.8990647, 18.0628807]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231278243",
        "osm_id": "231278243",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.37",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.8991955, 18.0627058],
              [-15.8994548, 18.0620388],
              [-15.8985765, 18.0617301],
              [-15.8982472, 18.0625771],
              [-15.8991255, 18.0628857],
              [-15.8991955, 18.0627058]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231278244",
        "osm_id": "231278244",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.38",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.8995772, 18.0638979],
              [-15.8988402, 18.0638374],
              [-15.8988514, 18.0635351],
              [-15.8989712, 18.0634427],
              [-15.8989749, 18.0633822],
              [-15.8988776, 18.0633182],
              [-15.8989001, 18.063055],
              [-15.8996782, 18.0631226],
              [-15.8995772, 18.0638979]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231278245",
        "osm_id": "231278245",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": "wall",
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.39",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.931045, 18.1251352],
              [-15.9304604, 18.1247867],
              [-15.9301956, 18.1252165],
              [-15.9308244, 18.1255441],
              [-15.931045, 18.1251352]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231392093",
        "osm_id": "231392093",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": "مدرسة ابتدائية",
        "name:fr": "École primaire",
        "barrier": null,
        "name": "مدرسة ابتدائية"
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.40",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.931045, 18.1251352],
              [-15.9312987, 18.1247395],
              [-15.9306534, 18.1244145],
              [-15.9304604, 18.1247867],
              [-15.931045, 18.1251352]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231392094",
        "osm_id": "231392094",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.41",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.8969698, 18.0685211],
              [-15.8962337, 18.0684079],
              [-15.8963455, 18.0677504],
              [-15.8970817, 18.0678636],
              [-15.8969698, 18.0685211]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231490639",
        "osm_id": "231490639",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.42",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9098312, 18.1412086],
              [-15.9094574, 18.1415858],
              [-15.9091168, 18.1412809],
              [-15.9094906, 18.1409037],
              [-15.9098312, 18.1412086]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231520010",
        "osm_id": "231520010",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.43",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9094976, 18.1201135],
              [-15.9100483, 18.1194276],
              [-15.9084763, 18.1183233],
              [-15.9080018, 18.1188949],
              [-15.9094976, 18.1201135]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231520458",
        "osm_id": "231520458",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.44",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9193068, 18.1092319],
              [-15.9188971, 18.1089373],
              [-15.9192186, 18.1085334],
              [-15.9196282, 18.108828],
              [-15.9193068, 18.1092319]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231622335",
        "osm_id": "231622335",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.45",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9238777, 18.122189],
              [-15.923536, 18.1226092],
              [-15.9232305, 18.1223847],
              [-15.9235722, 18.1219645],
              [-15.9236259, 18.122008],
              [-15.9238777, 18.122189]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231658738",
        "osm_id": "231658738",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.46",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9299603, 18.124366],
              [-15.9294588, 18.1250283],
              [-15.9291006, 18.1246259],
              [-15.9295044, 18.1240874],
              [-15.9299603, 18.124366]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231658773",
        "osm_id": "231658773",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.47",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9079077, 18.1321178],
              [-15.9075611, 18.132539],
              [-15.9074609, 18.1324657],
              [-15.9074612, 18.1324245],
              [-15.9073127, 18.1323057],
              [-15.907268, 18.1323065],
              [-15.9072024, 18.1322581],
              [-15.9071877, 18.1322481],
              [-15.9071537, 18.132223],
              [-15.9074864, 18.1318118],
              [-15.9079077, 18.1321178]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231666545",
        "osm_id": "231666545",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.48",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.931899, 18.0313997],
              [-15.9318274, 18.0313565],
              [-15.9313664, 18.0311639],
              [-15.9316812, 18.0307294],
              [-15.9321877, 18.0309551],
              [-15.9320648, 18.0311407],
              [-15.9320327, 18.0311896],
              [-15.931899, 18.0313997]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231978097",
        "osm_id": "231978097",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.49",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.9250392, 18.0336273],
              [-15.9252834, 18.0332119],
              [-15.924956, 18.0330378],
              [-15.9247118, 18.0334533],
              [-15.9250392, 18.0336273]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w231978098",
        "osm_id": "231978098",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": null,
        "name:ar": null,
        "name:fr": null,
        "barrier": null,
        "name": null
      }
    },
    {
      "type": "Feature",
      "id": "amenity_school_Nouakchott_again.50",
      "geometry": {
        "type": "MultiPolygon",
        "coordinates": [
          [
            [
              [-15.915344, 18.1490497],
              [-15.9148964, 18.1489344],
              [-15.915092, 18.1482484],
              [-15.9155397, 18.1483637],
              [-15.915344, 18.1490497]
            ]
          ]
        ]
      },
      "geometry_name": "geom",
      "properties": {
        "full_id": "w236838484",
        "osm_id": "236838484",
        "osm_type": "way",
        "amenity": "school",
        "office": null,
        "opening_hours": null,
        "name:en": null,
        "addr:street": null,
        "addr:city": "نواكشوط",
        "name:ar": "مدرسة الإمام البخاري",
        "name:fr": "Ecole El Imame Elboukhari",
        "barrier": null,
        "name": "مدرسة الإمام البخاري"
      }
    }
  ],
  "totalFeatures": 62,
  "numberMatched": 62,
  "numberReturned": 50,
  "timeStamp": "2024-06-01T15:18:32.945Z",
  "crs": {
    "type": "name",
    "properties": {"name": "urn:ogc:def:crs:EPSG::4326"}
  }
};
