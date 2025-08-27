import 'dart:io' show Platform,File;
import 'dart:math' as math;
import 'dart:ui';
import 'dart:convert' show utf8;
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:map_coverage_planner/GridValue.dart';
import 'package:map_coverage_planner/paintDot.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;

void main() async {
  if (!kIsWeb) {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      WindowManager.instance.setMinimumSize(const Size(1280, 720));
    }
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  // static const String ACCESS_TOKEN = String.fromEnvironment(
  //     "pk.eyJ1IjoiZmFrZXVzZXJnaXRodWIiLCJhIjoiY2pwOGlneGI4MDNnaDN1c2J0eW5zb2ZiNyJ9.mALv0tCpbYUPtzT7YysA2g");
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map planner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(
        title: 'Flutter Demo Home Page',
        access_token: "ACCESS_TOKEN",
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage(
      {super.key, required this.title, required this.access_token});

  final String title;
  final String access_token;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>  {
  final MapController _mapController = MapController();
  final List<Marker> _listPinMap = [];
  final List<LatLng> _areaPolygon = []; // draw Polygon use LatLng
  List<LatLng> pinClick = [];
  List<LatLng> _polyLine = [];
  List<Marker> _polyLineDot = [];
  List<LatLng> _wallArea = [];
  List<Marker> _startPoint = [];
  late LatLng center;
  double _windowHeight = 150;
  bool _openWindow = true;
  String? _mode; // "cover","line"
  double _stepVal = 1;
  double _horizontalVal = 1;
  double _rotatelVal = 0;
  double _walldist = 1;
  final GridMap Gm = new GridMap();
  final textController =TextEditingController();
     // 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
    // subdomains: ['a', 'b', 'c'],

  bool isNumeric(String str) {
    try {
      var value = double.parse(str);
    } on FormatException {
      return false;
    } finally {
      return true;
    }
  }
  void textLatLng(){
    if(textController.text!=""){
      List<String> input = textController.text!.split(',');
     try{
       if(isNumeric(input[0])||isNumeric(input[1])){
         double? lat = double.parse(input[0]);
         double? lng = double.parse(input[1]);
         _listPinMap.add(Marker(
           point: LatLng(lat,lng),
           alignment: Alignment.topCenter,
           child: Image.asset("images/location.png"),
         ));
         _areaPolygon.add(LatLng(lat,lng));
         textController.clear();
         setState(() {
           _listPinMap;
           _areaPolygon;
         });
       }
     }catch(e){
       debugPrint(e.toString());
     }
  }
  }

  void onSubmit() {
    //draw area
    if (_listPinMap.length > 2) {
      if(_mode=="Coverages"){
        setUpGrid();
      }else if(_mode == "Line"){
        _polyLine = pinClick;
        _startPoint = [
          Marker(
            point: pinClick[0],
            width: 10,
            height: 10,
            alignment: Alignment.center,
            child: CustomPaint(painter: PaintDot()),
          )
        ];
        setState(() {
          _polyLine;
          _startPoint;
        });
      }

    }
  }

  update(List<LatLng> poly) {
    _polyLine = poly;
    _startPoint = poly.isNotEmpty
        ? [
            Marker(
              point: poly[0],
              width: 10,
              height: 10,
              alignment: Alignment.center,
              child: CustomPaint(painter: PaintDot()),
            )
          ]
        : [];
    setPolyDot();
    _wallArea = Gm.getWallArea();
    setState(() {
      _polyLine;
      _startPoint;
      _wallArea;
    });
  }

  // void onSetHorizontal() {
  //   update(Gm.updateHorizontal(_horizontalVal));
  // }
  //
  // void onSetVertical() {
  //   update(Gm.updateVertical(_stepVal));
  // }
  void setStep(double value){
    if(Gm.enble){
      update(Gm.updateVertical(value));
    }
  }
  void setWall(double value){
    if(Gm.enble){
      update(Gm.updateWallBetween(value));
    }
  }
  void onRotation(bool button) {
    if (Gm.enble) {
      if (_rotatelVal > 180) {
        _rotatelVal = 0;
      } else if (button) {
        _rotatelVal += 1;
      }
      update(Gm.updateRotation(_rotatelVal));
    }
  }

  void onResize() {
    if (_windowHeight != 60) {
      _windowHeight = 60;
    } else if (_mode == "Coverages") {
      _windowHeight = 500;
    } else if (_mode == "Line") {
      _windowHeight = 300;
    } else {
      _windowHeight = 150;
    }
    setState(() {
      _windowHeight;
      _openWindow = !_openWindow;
    });
  }

  void onRemove() {
    if(_mode == "Coverages"){
      if (_listPinMap.isNotEmpty) {
        _listPinMap.removeLast();
       clearAll();
      }
      if (_areaPolygon.isNotEmpty) {
        _areaPolygon.removeLast();
      }
      setState(() {
        _listPinMap;
        _areaPolygon;
        _polyLine;
        _startPoint;
      });
    }else if(_mode == "Line"){
      if(_listPinMap.isNotEmpty){
        _startPoint.clear();
        _listPinMap.removeLast();
         pinClick.removeLast();
        setState(() {
          _listPinMap;
          _polyLine;
          _startPoint;
        });
      }

    }
  }
  void clearAll(){
    _startPoint.clear();
    _wallArea.clear();
    _polyLine.clear();
    _polyLineDot.clear();
    Gm.resetGrid();
  }
  void onclickMode(String mode) {
    if (_mode == mode) return;
    _mode = mode;
    clearAll();
    if (mode == "Coverages") {
      _windowHeight = 500;
    } else if (mode == "Line") {
      _windowHeight = 300;
    } else {
      _windowHeight = 150;
    }
    setState(() {
      _windowHeight;
    });
  }
 void onTapMap(LatLng latlng){
   if (_mode == "Coverages") {
     _areaPolygon.add(latlng);
     Marker pin = Marker(
       point: latlng,
       alignment: Alignment.topCenter,
       child: Image.asset("images/location.png"),
     );
     _listPinMap.add(pin);
     setState(() {
       _listPinMap;
       _areaPolygon;
     });
   }else if(_mode  =="Line"){
     pinClick.add(latlng);
     Marker pin = Marker(
       point: latlng,
       alignment: Alignment.topCenter,
       child: Image.asset("images/location.png"),
     );
     _listPinMap.add(pin);
     setState(() {
       _listPinMap;
     });

   }
  }

  void setPolyDot(){
    _polyLineDot.clear();
    List pathPoint = Gm.polyLine;
    for(LatLng o in pathPoint){
      Marker dot = Marker(
        point: o,
        alignment: Alignment.center,
        width:5,
        height: 5,
        child: CustomPaint(
          painter: PaintDot(color: Colors.yellow),
        ),
      );
      _polyLineDot.add(dot);
    }
  }
  void setUpGrid() {
    Gm.initGridMap(_areaPolygon,_walldist, _horizontalVal, _stepVal, _rotatelVal);
    _polyLine = Gm.getPolyLine;
    _wallArea = Gm.getWallArea();
    _startPoint = _polyLine.isNotEmpty
        ? [
            Marker(
              point: _polyLine[0],
              width: 10,
              height: 10,
              alignment: Alignment.center,
              child: CustomPaint(painter: PaintDot()),
            )
          ]
        : [];
    // List out = Gm.outSide;
    // for(LatLng o in out){
    //   Marker pin = Marker(
    //   point: o,
    //   alignment: Alignment.topCenter,
    //   width:5,
    //   height: 5,
    //   child: CustomPaint(
    //     painter: PaintDot(color: Colors.black),
    //   ),
    // );
    // _listPinMap.add(pin);
    // }
    setPolyDot();
    setState(() {
      _listPinMap;
      _polyLine;
    });
  }

  Future onExportCsv() async {
    final List<String> rowHead = <String>["latitude", "longitude"];
    List<List<String>> allData = [];
    allData.add(rowHead);
    for (int i = 0; i < _polyLine.length; i++) {
      List<String> row = [
        _polyLine[i].latitude.toString(),
        _polyLine[i].longitude.toString()
      ];
      allData.add(row);
    }
    try {
      String fileName = (_mode == "Coverages") ? "coverages.csv" : "line.csv";
      String csv = const ListToCsvConverter().convert(allData);

      /// if (kIsWeb) {   use web -----------------------------------------------------------
        final bytes = utf8.encode(csv);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..style.display = 'none'
          ..download = fileName;
        html.document.body!.children.add(anchor);
// download
        anchor.click();
// cleanup
        html.document.body!.children.remove(anchor);
        html.Url.revokeObjectUrl(url);
// // use windows ------------------------------------------------------------------------------------
//       final path = await FilePicker.platform.saveFile(fileName: fileName);
//       if (path == null) return;
//       final saveFile = File(path);
//       await saveFile.writeAsString(csv);
    // }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: const LatLng(13.763853986636219, 100.52801196158062),
          initialZoom: 16,
          onTap: (TapPosition k,LatLng latLng)=>onTapMap(latLng)
        ),
        children: [
          TileLayer(
            tileProvider: CancellableNetworkTileProvider(),
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          PolygonLayer(
            polygons: [
              Polygon(
                points: _areaPolygon,
                color: const Color(0x24FF6E03),
                isFilled: true,
              ),
            ],
          ),
          MarkerLayer(markers: _listPinMap),
          MarkerLayer(markers: _startPoint),
          MarkerLayer(markers: _polyLineDot),
          PolylineLayer(
            polylines: [
              Polyline(
                points: _wallArea,
                color: Colors.deepOrangeAccent,
              ),
            ],
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: _polyLine,
                color: Colors.blue,
              ),
            ],
          ),
          Stack(
            children: [
                Positioned(
                    top: 20,
                    left: MediaQuery.of(context).size.width / 2 - 170,
                    width: 350,
                    height: 40,
                    child: Wrap(
                      children: [
                        ElevatedButton.icon(
                            onPressed: onSubmit,
                            icon: const Icon(Icons.aspect_ratio),
                            label: const Text("submit")),
                        if (_mode == "Coverages") ElevatedButton.icon(
                            onPressed: () => onRotation(true),
                            icon: const Icon(Icons.rotate_90_degrees_cw),
                            label: const Text("หมุน")),
                        ElevatedButton.icon(
                            onPressed: onRemove,
                            icon: const Icon(Icons.remove_circle),
                            label: const Text("ลบ")),
                      ],
                    )),
              Positioned(
                  top: 56,
                  right: 30,
                  child: AnimatedContainer(
                    clipBehavior: Clip.hardEdge,
                    width: 270,
                    height: _windowHeight,
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    duration: const Duration(seconds: 1),
                    curve: Curves.fastOutSlowIn,
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(context)
                          .copyWith(scrollbars: false),
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _mode ?? "Mode Planner",
                                  style: const TextStyle(
                                      color: Colors.deepPurple, fontSize: 16),
                                ),
                                IconButton(
                                    onPressed: onResize,
                                    icon: Icon(_openWindow
                                        ? Icons.pin_invoke
                                        : Icons.rectangle_outlined))
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                InkWell(
                                  onTap: () => onclickMode("Coverages"),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.fastOutSlowIn,
                                    padding: const EdgeInsets.all(5.0),
                                    width: (_mode == "Coverages") ? 112 : 90,
                                    height: (_mode == "Coverages") ? 88 : 72,
                                    decoration: BoxDecoration(
                                        color: (_mode == "Coverages")
                                            ? Colors.orange[50]
                                            : Colors.grey[100],
                                        borderRadius:
                                            BorderRadius.circular(10.0)),
                                    child: const Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Icon(Icons.route_sharp,
                                            color: Colors.orange),
                                        // const SizedBox(height: 10),
                                        Text(
                                          "Coverages",
                                          style: TextStyle(
                                              color: Colors.deepOrange,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => onclickMode("Line"),
                                  child: AnimatedContainer(
                                    duration: const Duration(seconds: 1),
                                    curve: Curves.fastOutSlowIn,
                                    padding: const EdgeInsets.all(5.0),
                                    width: (_mode == "Line") ? 112 : 90,
                                    height: (_mode == "Line") ? 88 : 72,
                                    decoration: BoxDecoration(
                                        color: (_mode == "Line")
                                            ? Colors.green[100]
                                            : Colors.grey[100],
                                        borderRadius:
                                            BorderRadius.circular(10.0)),
                                    child: const Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        Icon(Icons.share, color: Colors.green),
                                        // const SizedBox(height: 10),
                                        Text(
                                          "Line",
                                          style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (_mode == "Coverages")
                              Column(
                                children: [
                                  Text("Step (m)  $_stepVal"),
                                  Slider(
                                    value: _stepVal,
                                    min: 1,
                                    max: 20,
                                    label: _stepVal.toString(),
                                    onChangeEnd: (double val) =>setStep(val),
                                    onChanged: (double value) {
                                      setState(() {
                                        _stepVal = value.round().toDouble();
                                      });
                                    },
                                  ),
                                  Text("Wall offset (m)  $_walldist"),
                                  Slider(
                                    value: _walldist,
                                    min: 0,
                                    max: 15,
                                    label: _walldist.toString(),
                                    onChangeEnd: (double val) =>setWall(val),
                                    onChanged: (double value) {
                                      setState(() {
                                        _walldist =
                                            value.round().toDouble();
                                      });
                                    },
                                  ),
                                  Text("Rotation $_rotatelVal"),
                                  Slider(
                                    value: _rotatelVal,
                                    min: -180,
                                    max: 180,
                                    divisions: 180,
                                    label: _rotatelVal.toString(),
                                    onChangeEnd: (_) => onRotation(false),
                                    onChanged: (double value) {
                                      setState(() {
                                        _rotatelVal = value.round().toDouble();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            SizedBox(
                              height:40,
                              width: 220,
                              child: TextField(
                                controller: textController,
                                style: const TextStyle(fontSize: 12),
                                decoration: const InputDecoration(
                                  contentPadding:EdgeInsets.symmetric(vertical: 0) ,
                                hintText: "input latlng",
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                      width: 1, color: Colors.deepPurple), //<-- SEE HERE
                                ),
                              ),),
                            ),
                            const SizedBox(height:20),
                            ButtonBar(
                              alignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                    onPressed: onExportCsv,
                                    child: const Text("export")),
                                ElevatedButton(
                                    onPressed: textLatLng,
                                    child: const Text("LatLng"))
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  )),
            ],
          ),
        ],
      ),
    );
  }
}
