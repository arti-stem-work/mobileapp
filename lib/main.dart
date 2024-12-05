import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:proj4dart/proj4dart.dart';


String baseUrl = 'http://65.0.105.229:8080/geoserver/wms';
List<String> layerNames = [
  'Avl_N',
  'Avl_P',
  'Avl_K',
  'N_Maize (37.5 - Yield)',
  'N_Soybean (18.75-Yield)',
  'N_Wheat (33.75-Yield)',
  'P_Maize (37.5 - Yield)',
  'P_Soybean (18.75-Yield)',
  'P_Wheat (33.75-Yield)',
  'K_Maize (37.5 - Yield)',
  'K_Soybean (18.75-Yield)',
  'K_Wheat (33.75-Yield)',
   
    'Geoda_N_req',
    'Raisina_N_req',
    'K_Geoda_soil',
    'N_Geoda_soil',
    'P_Geoda_soil',
    'K_Raisina_soil',
    'N_Raisina_soil',
    'P_Raisina_soil',
    'MP_Testing',
  
  //Kawardha
  'Kawardha_N_Fert',
  'Kawardha_P_Fert',
  'Kawardha_K_Fert',
  'Kawardha_N',
  'Kawardha_P',
  'Kawardha_K',
  
  //'Kawardha_pH',
  //'Kawardha_OC',
  
  'SOC',
  
];

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Precision Soil Fertilizer',
      theme: ThemeData(
        primarySwatch: Colors.teal,
      ),
      home: LandingPage(),
    );
  }
}

class LandingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/landing_page.png', // Replace with the path to your landing page background image
              fit: BoxFit.cover,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Precision Soil Fertilizer Recommendation System',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Times New Roman',
                  fontStyle: FontStyle.italic
                  //color: Colors.green,
                  
                ),
              ),
              SizedBox(height: 80),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Container(
                      height: 70,
                      child: Image.asset('assets/logo/ICAR_left.jpeg'),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 70,
                      child: Image.asset('assets/logo/IISSLogo.jpeg'),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 70,
                      child: Image.asset('assets/logo/IARI.jpeg'),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 70,
                      child: Image.asset('assets/logo/NBSS.jpg'),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 70,
                      child: Image.asset('assets/logo/Neppa.jpg'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 100),
              Text(
                'ICAR - Indian Institute of Soil Science, Nabibagh Bhopal',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Times New Roman',
                  //fontStyle: FontStyle.italic
                  //color: Colors.blue,
                ),
              ),
              SizedBox(height: 190),
              ElevatedButton(
                onPressed: () => _requestLocationPermission(context),
                child: Text(
                  'Get Started',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  primary: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _requestLocationPermission(BuildContext context) async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Location Access'),
            content: Text('Location access is important for this app to work.'),
            actions: [
              TextButton(
                child: Text('Try Again'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _requestLocationPermission(context);
                },
              ),
            ],
          );
        },
      );
    } else {
      // Location permission granted, navigate to the home screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GrayIndexScreen(
            geoServerService: GeoServerService(),
          ),
        ),
      );
    }
  }
}



class GrayIndexScreen extends StatefulWidget {
  final GeoServerService geoServerService;

  GrayIndexScreen({required this.geoServerService});

  @override
  _GrayIndexScreenState createState() => _GrayIndexScreenState();
}

class _GrayIndexScreenState extends State<GrayIndexScreen> {
  
  Timer? _locationUpdateTimer;
  bool _isLoading = false;
  List<String?> _grayIndexValues = [];

  Position? _currentPosition;
  Position? _previousPosition;
  StreamSubscription<Position>? _locationSubscription;
  bool _grayIndexFetched = false;
  String _noFeaturesMessage = '';

  String? _selectedOption;
  List<String> _associatedLayers = [];
  String? _previousOption;
  double? _previousLatitude;
  double? _previousLongitude;

  final TextEditingController _farmAreaController = TextEditingController();
  double _convertedArea = 0.0;

  Map<String, List<String>> _options = {
    'Wheat': [
      'Avl_N',
      'Avl_P',
      'Avl_K',
      'N_Wheat (33.75-Yield)',
      'P_Wheat (33.75-Yield)',
      'K_Wheat (33.75-Yield)',
      
      'Geoda_N_req',
      'Raisina_N_req',

      'K_Geoda_soil',
      'N_Geoda_soil',
      'P_Geoda_soil',

      'K_Raisina_soil',
      'N_Raisina_soil',
      'P_Raisina_soil',
      //'MP_Testing',

      
     
    ],
    'Maize': [
      'Avl_N',
      'Avl_P',
      'Avl_K',
      'N_Maize (37.5 - Yield)',
      'P_Maize (37.5 - Yield)',
      'K_Maize (37.5 - Yield)',
      
    ],
    'Soybean': [
      'Avl_N',
      'Avl_P',
      'Avl_K',
      'N_Soybean (18.75-Yield)',
      'P_Soybean (18.75-Yield)',
      'K_Soybean (18.75-Yield)',
      
    ],
    'Rice': [
      'Kawardha_N',
      'Kawardha_P',
      'Kawardha_K',

      'Kawardha_N_Fert',
      'Kawardha_P_Fert',
      'Kawardha_K_Fert',
],
    'Groundnut': [],
    'Moongbean': [],
    'Bajra': [],
    'Arhar': [],
    'Soil Organic Carbon': ['SOC',],
  };

  @override
  void initState() {
    super.initState();
    _initLocationUpdates();
    _farmAreaController.addListener(_convertFarmArea);
  }

  void _convertFarmArea() {
    final farmArea = double.tryParse(_farmAreaController.text);
    if (farmArea != null) {
      // Convert farm area from acres to hectares
      _convertedArea = farmArea / 2.47105; // 1 hectare = 2.47105 acres
    } else {
      _convertedArea = 0.0;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }
  
  void _initLocationUpdates() {
    _locationSubscription = Geolocator.getPositionStream().listen((Position position) {
      if (position != null && position != _currentPosition) {
        setState(() {
          _previousPosition = _currentPosition;
          _currentPosition = position;
        });
       _locationUpdateTimer?.cancel(); // Cancel previous timer, if any
        _locationUpdateTimer = Timer(Duration(minutes: 5), () {
          // After 5 minutes of no location update, stop fetching data
          _locationUpdateTimer?.cancel();
          _getGrayIndexValuesForLocation(position);
        });
      }
    });
  }

  Future<void> _getGrayIndexValuesForLocation(Position position) async {
  if (_selectedOption == _previousOption && position.latitude == _previousLatitude && position.longitude == _previousLongitude) {
    // Option and location haven't changed, do not update gray index values
    return;
  }

  setState(() {
    _isLoading = true;
    _noFeaturesMessage = ''; // Clear the no features message
    _previousOption = _selectedOption;
    _previousLatitude = position.latitude;
    _previousLongitude = position.longitude;
  });

  _grayIndexValues.clear();

  if (_selectedOption != null && _options.containsKey(_selectedOption)) {
    List<String> layerNames = _options[_selectedOption]!;
    List<String?> values = await Future.wait(layerNames.map((layerName) {
      return widget.geoServerService.getGrayIndex(layerName, position.latitude, position.longitude);
    }));

    for (String? value in values) {
      if (value != null) {
        double grayIndex = double.tryParse(value.split(':').last.trim()) ?? 0;
        if (grayIndex >= 0) {
          _grayIndexValues.add(value);
        }
      }
    }
  }

  setState(() {
    _isLoading = false;
  });

  if (_grayIndexValues.isEmpty) {
    setState(() {
      _noFeaturesMessage = 'No features found for this location.';
    });
  } else {
    setState(() {
      _noFeaturesMessage = '';
    });
  }
}


 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text(
        'Precision Soil Fertilizer Recommendation System',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          fontFamily: 'Arial',
        ),
      ),
      centerTitle: true,
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/home_page.jpg', // Replace with the path to your image
          fit: BoxFit.cover,
        ),
        Container(
          color: Colors.black.withOpacity(0.0), // Adjust the opacity as desired
        ),
        Column(
          children: [
            SizedBox(height: 16),
            DropdownButton<String>(
              value: _selectedOption,
              hint: Text(
                'Select an option',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Arial',
                ),
              ),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedOption = newValue;
                  _grayIndexValues.clear();
                });
                if (_currentPosition != null) {
                  _getGrayIndexValuesForLocation(_currentPosition!);
                }
              },
              items: _options.keys.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      fontFamily: 'Arial',
                    ),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Center(
                child: _isLoading
                    ? CircularProgressIndicator()
                    : _grayIndexValues.isEmpty
                        ? Text(
                            _noFeaturesMessage.isNotEmpty ? _noFeaturesMessage : 'No features found for this location.',
                            style: TextStyle(fontSize: 18),
                          )
                        : ListView.builder(
                            itemCount: _grayIndexValues.length,
                            itemBuilder: (context, index) {
                              final grayIndex = _grayIndexValues[index];
                              final parts = grayIndex?.split(':');
                              final layerName = parts?.elementAt(0)?.trim() ?? '';
                              final value = parts?.elementAt(1)?.trim() ?? '';

                              final formattedValue = double.tryParse(value)?.toStringAsFixed(5) ?? '';

                              if (layerName != 'Avl_N' && layerName != 'Avl_P' && layerName != 'Avl_K'
                              && layerName != 'K_Geoda_soil' && layerName != 'N_Geoda_soil' && layerName != 'P_Geoda_soil'
                              && layerName != 'K_Raisina_soil' && layerName != 'N_Raisina_soil' && layerName != 'P_Raisina_soil'
                              && layerName != 'Kawardha_N' && layerName != 'Kawardha_P' && layerName != 'Kawardha_K') {
                                double updatedValue = double.tryParse(value) ?? 0.0;
                                if (_farmAreaController.text.isNotEmpty) {
                                  final farmArea = double.tryParse(_farmAreaController.text) ?? 0.0;
                                  updatedValue *= _convertedArea ?? 0.0;
                                }

                                return Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 70, vertical: 5),
                                  child: Card(
                                    color: Colors.yellow.shade50,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(color: Colors.grey.shade300, width: 1),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(10),
                                      child: Column(
                                        children: [
                                          Text(
                                            layerName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              fontFamily: 'Times New Roman',
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          _farmAreaController.text.isNotEmpty
                                              ? Text(
                                                  updatedValue.toStringAsFixed(5),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                )
                                              : Text(
                                                  formattedValue,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              } else {
                                return Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 70, vertical: 5),
                                  child: Card(
                                    color: Colors.yellow.shade50,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(color: Colors.grey.shade300, width: 1),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(10),
                                      child: Column(
                                        children: [
                                          Text(
                                            layerName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              fontFamily: 'Times New Roman',
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            formattedValue,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: TextField(
                controller: _farmAreaController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(
                      color: Colors.yellow.shade900,
                      width: 2.0,
                    ),
                  ),
                  labelText: 'Farm Area (in acres)',
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    fontFamily: 'Times New Roman',
                    color: Colors.black,
                  ),
                  filled: true,
                  fillColor: Colors.yellow.shade50,
                  contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: () async {
        final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        _getGrayIndexValuesForLocation(position);
      },
      child: Icon(Icons.refresh),
    ),
  );
}
}


class GeoServerService {
  final String baseUrl = 'http://65.0.105.229:8080/geoserver/wms';

  Future<String?> getGrayIndex(String layerName, double lat, double lon) async {
    try {
      var pointSrc = Point(y: lat, x: lon);
      var projSrc = Projection.get('EPSG:4326')!;
      var projDst = Projection.get('EPSG:32643') ??
          Projection.add(
              'EPSG:32643',
              '+proj=utm +zone=43 +datum=WGS84 +units=m +no_defs');

      var pointForward = projSrc.transform(projDst, pointSrc);

      var lat32643 = pointForward.y;
      var lon32643 = pointForward.x;

      var scale = 1000000.0;
      var resolution = scale / 0.0254 / 96;
      var zoom = (math.log(2 * math.pi * 6378137 / (256 * resolution)) / math.log(2)) - 1;

      var bbox_width = 0.01 * math.pow(2, (21 - zoom)) / 512;
      var bbox_height = 0.01 * math.pow(2, (21 - zoom)) / 512;
      var bbox_top = lat32643 + bbox_height / 2;
      var bbox_bottom = lat32643 - bbox_height / 2;
      var bbox_left = lon32643 - bbox_width / 2;
      var bbox_right = lon32643 + bbox_width / 2;

      var x = ((lon32643 - bbox_left) / bbox_width) * 512;
      var y = ((bbox_top - lat32643) / bbox_height) * 512;

      final randomQueryParameter = DateTime.now().millisecondsSinceEpoch.toString();
      
      
      String requestUrl = '$baseUrl?${randomQueryParameter}&service=WMS&version=1.1.0&request=GetFeatureInfo&layers=$layerName&query_layers=$layerName&info_format=text/plain&exceptions=application/vnd.ogc.se_xml&crs=EPSG:32643&bbox=${bbox_left},${bbox_bottom},${bbox_right},${bbox_top}&width=512&height=512&x=${x.toInt()}&y=${y.toInt()}';

      final response = await http.get(Uri.parse(requestUrl), headers: {'Cache-Control': 'no-cache'});

      if (response.statusCode == 200) {
        String grayIndex = response.body;
        //print('Gray Index for layer $layerName: $grayIndex');// Console printing

        // Filter and format the gray index value
        String? filteredGrayIndex = grayIndex
            .split('\n')
            .firstWhere((line) => line.contains('GRAY_INDEX'), orElse: () => '')
            .replaceAll('GRAY_INDEX = ', '');

        if (filteredGrayIndex?.isEmpty ?? true) {
          return null;
        }

        String formattedResult = '$layerName: $filteredGrayIndex';

        return formattedResult;
      } else {
        throw Exception('Failed to retrieve gray index from GeoServer');
      }
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }
}
