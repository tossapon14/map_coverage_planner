import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'utils.dart';

enum Sweep {
  UP(1),
  DOWN(-1);

  final int value;
  const Sweep(this.value);
}

enum MoveDirect {
  RIGHT(1),
  LEFT(-1);

  final int value;
  const MoveDirect(this.value);
}

class GridValue {
  double data = 0.0;
  GridValue(this.data);
  @override
  String toString() {
    // TODO: implement toString
    return "Grid data ${data}";
  }
}

class GridMap {
  List<LatLng>? originArea;
  late List<LatLng> area;
  late double wallBetween;
  late double horizontal;
  late double vertical;
  late LatLng center;
  late double degree;
  late LatLng left_lower;
  late List dataGrid;
  late int n_dataIndex;
  late int gridWidth;
  late int gridHeight;
  late int sweep;
  late int direct;
  late List goalLine;
  late List<int> startPoint;
  bool wantExpand = false;
  List<LatLng> polyLine = [];
  List<LatLng> outSide = [];
  List<LatLng> inSide = [];
  late LatLng? pointRotation;
  bool enble = false;
  List<LatLng> allPath = [];
  List<LatLng> get getPolyLine => polyLine;
  List<LatLng> wallArea = [];
  List<LatLng> getWallArea() {
    return [...wallArea, wallArea[0]];
  }

  initGridMap(
      List<LatLng> area, double wallBetween, double horizontal, double vertical, double degree,
      {double offsetGrid = 16}) {
    originArea ??= area;
    this.wallBetween =wallBetween;
    wallArea =wallBetween!=0? offsetPolygon(area, wallBetween):area;
    this.area = wallArea;
    this.horizontal = horizontal;
    this.vertical = vertical;
    this.degree = degree;
    sweep = Sweep.UP.value;
    direct = MoveDirect.RIGHT.value;
    if (degree != 0) {
      this.area = newAreaWhenRotate(this.area, degree);
    }
    List xMaxMin = findMaxMin(this.area, diractWidth: true);
    List yMaxMin = findMaxMin(this.area, diractWidth: false);
    double horizonToLong = metersToLongitude(horizontal, yMaxMin[0]);
    double verticalToLat = metersToLatitude(vertical);
    double width =
        (xMaxMin[0] - xMaxMin[1]) + metersToLongitude(offsetGrid, yMaxMin[0]);
    double height = (yMaxMin[0] - yMaxMin[1]) + metersToLatitude(offsetGrid);
    center =
        LatLng((yMaxMin[0] + yMaxMin[1]) / 2, (xMaxMin[0] + xMaxMin[1]) / 2);
    left_lower =
        LatLng(center.latitude - height / 2, center.longitude - width / 2);
    gridWidth = (width ~/ horizonToLong) + 1;
    gridHeight = (height ~/ verticalToLat) + 1;
    n_dataIndex = gridWidth * gridHeight;
    dataGrid = List.filled(n_dataIndex, GridValue(0.0));
    setGridFromPolygon();
    startPlanning();
    if (degree != 0) {
      convertAfterRotation();
    }
    enble = true;
  }

  void resetGrid() {
    enble = false;
    originArea = null;
    outSide.clear();
    inSide.clear();
    polyLine.clear();
  }

  List<LatLng> updateRotation(double degree) {
    initGridMap(originArea!,wallBetween, horizontal, vertical, degree);
    return polyLine;
  }

  List<LatLng> updateVertical(double v) {
    initGridMap(originArea!,wallBetween, horizontal, v, degree);
    return polyLine;
  }

  List<LatLng> updateHorizontal(double h) {
    initGridMap(originArea!,wallBetween, h, vertical, degree);
    return polyLine;
  }
  List<LatLng> updateWallBetween(double w) {
    initGridMap(originArea!,w, horizontal, vertical, degree);
    return polyLine;
  }

  LatLng rotationLatLng(LatLng l, LatLng around, angleDegrees) {
    double angleRadians = degToRadian(angleDegrees);
    double latRadians = degToRadian(l.latitude);
    double lngRadians = degToRadian(l.longitude);

    double centerLatRadians = degToRadian(around.latitude);
    double centerLngRadians = degToRadian(around.longitude);
    double translatedLat = latRadians - centerLatRadians;
    double translatedLng = lngRadians - centerLngRadians;

    // Perform rotation
    double rotatedLat = translatedLat * math.cos(angleRadians) -
        translatedLng * math.sin(angleRadians);
    double rotatedLng = translatedLat * math.sin(angleRadians) +
        translatedLng * math.cos(angleRadians);

    double newLat = radianToDeg(rotatedLat);
    double newLng = radianToDeg(rotatedLng);
    return LatLng(newLat, newLng);
  }

  void convertAfterRotation() {
    double angleRadians = -degToRadian(this.degree);
    List<LatLng> l = [];
    for (LatLng p in this.polyLine) {
      double rotatedLat = p.latitude * math.cos(angleRadians) -
          p.longitude * math.sin(angleRadians);
      double rotatedLng = p.latitude * math.sin(angleRadians) +
          p.longitude * math.cos(angleRadians);
      l.add(LatLng(rotatedLat + pointRotation!.latitude,
          rotatedLng + pointRotation!.longitude));
    }
    polyLine = l;
  }

  static double metersToLongitude(double meters, double latitude) {
    // Approximate meters per degree of longitude at the equator
    const metersPerDegreeLonAtEquator = 111320.0;

    // Calculate the change in longitude
    double changeInLon =
        meters / (metersPerDegreeLonAtEquator * math.cos(latitude * pi / 180));

    return changeInLon;
  }

  static double metersToLatitude(double meters) {
    // Approximate meters per degree of latitude at the equator
    const metersPerDegreeLat = 111320.0;

    // Calculate the change in latitude
    double changeInLat = meters / metersPerDegreeLat;

    return changeInLat;
  }

  List<LatLng> offsetPolygon(List<LatLng> polygon, double distance) {
    List<List<double>> offsetVertices1 = [];
    List<List<double>> offsetVertices2 = [];
    List<List<double>> offsetintersecttion1 = [];
    List<List<double>> offsetintersecttion2 = [];
    int numPoints = polygon.length;
    for (int i = 0; i < numPoints; i++) {
      List p1 = [polygon[i].longitude, polygon[i].latitude];
      List p2 = [
        polygon[(i + 1) % numPoints].longitude,
        polygon[(i + 1) % numPoints].latitude
      ];

      List normalVec = calculate_normal_vector(p1, p2); // [long,lat]
      offsetVertices1.add([
        p1[0] + normalVec[0] * metersToLongitude(distance, p1[1]),
        p1[1] + normalVec[1] * metersToLatitude(distance)
      ]);
      offsetVertices1.add([
        p2[0] + normalVec[0] * metersToLongitude(distance, p2[1]),
        p2[1] + normalVec[1] * metersToLatitude(distance)
      ]);
      offsetVertices2.add([
        p1[0] + normalVec[0] * -metersToLongitude(distance, p1[1]),
        p1[1] + normalVec[1] * -metersToLatitude(distance)
      ]);
      offsetVertices2.add([
        p2[0] + normalVec[0] * -metersToLongitude(distance, p2[1]),
        p2[1] + normalVec[1] * -metersToLatitude(distance)
      ]);
    }
    int numVertices1 = offsetVertices1.length;
    for (int i = 0; i < numVertices1; i += 2) {
      List<double> s1 = offsetVertices1[i]; //[long,lat]
      List<double> s2 = offsetVertices1[(i + 1) % numVertices1];
      List<double> s3 = offsetVertices1[(i + 2) % numVertices1];
      List<double> s4 = offsetVertices1[(i + 3) % numVertices1];
      List<double>? pointintersecttion =
          getIntersection(s1, s2, s3, s4); //[x,y]
      // print("EEE $pointintersecttion");
      if (pointintersecttion != null) {
        offsetintersecttion1.add(pointintersecttion);
      } else {
        offsetintersecttion1.add(s2);
        offsetintersecttion1.add(s3);
      }
      //********************************************//
      s1 = offsetVertices2[i]; //[long,lat]
      s2 = offsetVertices2[(i + 1) % numVertices1];
      s3 = offsetVertices2[(i + 2) % numVertices1];
      s4 = offsetVertices2[(i + 3) % numVertices1];
      pointintersecttion = getIntersection(s1, s2, s3, s4); //[x,y]
      // print("EEE222 $pointintersecttion");
      if (pointintersecttion != null) {
        offsetintersecttion2.add(pointintersecttion);
      } else {
        offsetintersecttion2.add(s2);
        offsetintersecttion2.add(s3);
      }
    }
    if (offsetintersecttion1.length < offsetintersecttion2.length) {
      return convertListToLatLng(offsetintersecttion1);
    } else {
      return convertListToLatLng(offsetintersecttion2);
    }
  }

  List<LatLng> newAreaWhenRotate(List<LatLng> area, double degree) {
    double max = 0.0;
    LatLng maxPoint = area[0];
    for (LatLng l in area) {
      if (l.longitude > max) {
        max = l.longitude;
        maxPoint = l;
      }
    }
    List<LatLng> area2 = [];
    pointRotation = maxPoint;
    for (LatLng point in area) {
      area2.add(rotationLatLng(point, maxPoint, degree));
    }
    return area2;
  }

  List<double> findMaxMin(List<LatLng> area, {bool diractWidth = true}) {
    double max = 0.0;
    double min = 10000;
    double wantMax = 0, wantMin = 0;
    for (LatLng p in area) {
      if (diractWidth) {
        if (p.longitude > max) {
          max = p.longitude;
          wantMax = p.longitude;
        }
        if (p.longitude < min) {
          min = p.longitude;
          wantMin = p.longitude;
        }
      } else {
        if (p.latitude > max) {
          max = p.latitude;
          wantMax = p.latitude;
        }
        if (p.latitude < min) {
          min = p.latitude;
          wantMin = p.latitude;
        }
      }
    }
    return [wantMax, wantMin];
  }


  void swepMoveing() {
    direct *= -1;
  }

  List setGridFromPolygon({bool inside = false}) {
    List l = [];
    List<LatLng> _out = [];
    List<LatLng> _in = [];
    for (int i = 0; i < gridWidth; i++) {
      for (int j = 0; j < gridHeight; j++) {
        LatLng latlng = calLatLngFromIndex(i, j) as LatLng;
        bool flag = checkInsidePolygon(latlng);
        if (flag == inside) {
          setValueFromIndex(i, j, GridValue(1.0));
          l.add(latlng);
          if (wantExpand) {
            setValueFromIndex(i + 1, j, GridValue(1.0));
            setValueFromIndex(i, j + 1, GridValue(1.0));
            setValueFromIndex(i - 1, j, GridValue(1.0));
            setValueFromIndex(i, j - 1, GridValue(1.0));
          }
        }
        if (flag) {
          // true = in
          _in.add(latlng);
        } else {
          _out.add(latlng);
        }
        inSide = _in;
        outSide = _out;
      }
    }
    return l;
  }

  void startPlanning() {
    polyLine.clear();
    try {
      goalLine =
          searchFreeGridGoal(Sweep.UP, MoveDirect.RIGHT); //[[x1,x2,..],y]
      startPoint = searchGridStart(Sweep.UP, MoveDirect.RIGHT); //[x,y];
      LatLng ll = calLatLngFromIndex(startPoint[0], startPoint[1]) as LatLng;
      polyLine.add(ll);
      List<int>? xyindex = startPoint; // [st1,st2]
      while (true) {
        xyindex = movingTarget(xyindex!);
        if (isSearchDone() || xyindex == null) {
          break;
        }
        setValueFromIndex(xyindex[0], xyindex[1], GridValue(0.5));
        LatLng ll = calLatLngFromIndex(xyindex[0], xyindex[1]) as LatLng;
        polyLine.add(ll);
      }
    } catch (error) {
      debugPrint(error.toString());
    }
  }

  List<int>? movingTarget(List<int> st) {
    int nX = direct + st[0];
    int nY = st[1];
    if (checkFreeGridFromIndex(nX, nY, GridValue(0.5))) {
      return [nX, nY];
    } else {
      findPointEdgeCurrent(st[0], st[1]);
      List<int>? step;
      if (st[1] >= goalLine[1]) {
        return null;
      }else{
        int xstep = 0;
        int ystep = st[1] + sweep; // next step Y
        if (direct == 1) {
          xstep = gridWidth - 1;
        }
        while (xstep >= 0 && xstep < gridWidth) {
          if (checkFreeGridFromIndex(xstep, ystep, GridValue(0.1))) {
            // find free grid 0.0
            List? intersect = latlngintersect(xstep, ystep);
            if (intersect != null) {
              if (intersect[2] <= 0.25) {
                polyLine.add(LatLng(intersect[1], intersect[0]));
                step =[xstep-direct,ystep];
              } else {
                polyLine.add(LatLng(intersect[1], intersect[0]));
                step =[xstep,ystep];
              }
            }
            break;
          }
          xstep -= direct;
        }
      }
      swepMoveing();
      return step;
    }
  }

  void findPointEdgeCurrent(int ix, int iy, {bool removeLast=true}) {
    List? intersect = latlngintersect(ix, iy);
    if (intersect != null) {
      if (intersect[2] <= 0.25&&removeLast) {
        polyLine.removeLast();
        polyLine.add(LatLng(intersect[1], intersect[0]));
      } else {
        polyLine.add(LatLng(intersect[1], intersect[0]));
      }
    }
  }

  void findPointEdgeTop(int ix, int iy) {
    int indexY = iy + sweep;
    int xst = 0;
    if (direct == 1) {
      xst = gridWidth - 1;
    }
    while (xst >= 0 && xst < gridWidth) {
      if (checkFreeGridFromIndex(xst, indexY, GridValue(0.1))) {
        //find grid 0.0
        List? intersect = latlngintersect(xst, indexY);
        if (intersect != null) {
          if (intersect[2] <= 0.25) {
            setValueFromIndex(xst, indexY, GridValue(0.5));
            polyLine.add(LatLng(intersect[1], intersect[0]));
          } else {
            polyLine.add(LatLng(intersect[1], intersect[0]));
          }
        }
        break;
      }
      xst = xst - direct;
    }
  }

  List<double>? latlngintersect(int ix, int iy) {
    LatLng latLng1 = calLatLngFromIndex(ix, iy) as LatLng;
    LatLng latLng2 = calLatLngFromIndex(ix + direct, iy) as LatLng;
    List<double> s1 = [latLng1.longitude, latLng1.latitude];
    List<double> s2 = [latLng2.longitude, latLng2.latitude];
    int length = area.length;
    for (int i = 0; i < length; i++) {
      List<double> s3 = [area[i].longitude, area[i].latitude];
      List<double> s4 = [
        area[(i + 1) % length].longitude,
        area[(i + 1) % length].latitude
      ];
      List<double>? intersect = getIntersection(s1, s2, s3, s4);
      if (intersect != null) {
        return intersect;
      }
    }
    return null;
  }

  bool isSearchDone() {
    for (int ix in goalLine[0]) {
      if (checkFreeGridFromIndex(ix, goalLine[1], GridValue(0.5))) {
        return false;
      }
    }
    return true;
  }

  Object calLatLngFromIndex(int i, int j) {
    if (i > gridWidth || j > gridHeight) {
      return Exception("Out of grid");
    } else {
      double lat = left_lower.latitude + metersToLatitude(j * vertical);
      double lng =
          left_lower.longitude + metersToLongitude(i * horizontal, lat);
      return LatLng(lat, lng);
    }
  }

  bool checkInsidePolygon(LatLng latlng) {
    bool inside = false;
    double minLng, maxLng;
    for (int i = 0; i < area.length; i++) {
      int j = (i + 1) % area.length;
      if (area[i].longitude >= area[j].longitude) {
        (minLng, maxLng) = (area[j].longitude, area[i].longitude);
      } else {
        (minLng, maxLng) = (area[i].longitude, area[j].longitude);
      }
      if ((minLng >= latlng.longitude) ||
          (latlng.longitude > maxLng) ||
          area[i].longitude == area[j].longitude) {
        continue;
      }
      double tmp1 = (area[j].latitude - area[i].latitude) /
          (area[j].longitude - area[i].longitude);
      if ((area[i].latitude +
              tmp1 * (latlng.longitude - area[i].longitude) -
              latlng.latitude) >
          0.0) {
        inside = !inside;
      }
    }
    return inside;
  }

  bool setValueFromIndex(int x, int y, var value) {
    int gridInx = y * gridWidth + x;
    if ((0 <= gridInx) && (gridInx < n_dataIndex) && value is GridValue) {
      dataGrid[gridInx] = value;
      return true;
    } else {
      return false;
    }
  }

  bool checkFreeGridFromIndex(int x, int y, GridValue value) {
    int gridInx = y * gridWidth + x;
    GridValue gv = dataGrid[gridInx];
    if (x > gridWidth || y > gridHeight || x < 0 || y < 0) {
      return false;
    } else if (gv.data < value.data) {
      // find 0.0 free grid
      return true;
    }
    return false;
  }

  List<dynamic> searchFreeGridGoal(Sweep sweep, MoveDirect direct) {
    int? yGoal;
    List<int> goallineX = [];
    bool findGoal = false;
    // fine y line is Goal
    if (sweep == Sweep.UP) {
      //UP fine Goal in top
      for (int j = gridHeight - 1; j >= 0; j--) {
        for (int i = gridWidth - 1; i >= 0; i--) {
          try {
            if (checkFreeGridFromIndex(i, j, GridValue(0.5))) {
              yGoal = j;
              goallineX.add(i);
            }
          } catch (e) {
            debugPrint(e.toString());
            continue;
          }
        }
        if (yGoal != null) {
          break;
        }
      }
    } else if (sweep == Sweep.DOWN) {
      for (int j = 0; j < gridHeight; j++) {
        for (int i = 0; i < gridWidth; i++) {
          try {
            if (checkFreeGridFromIndex(i, j, GridValue(0.5))) {
              yGoal = j;
              goallineX.add(i);
            }
          } catch (e) {
            debugPrint(e.toString());
            continue;
          }
        }
        if (yGoal != null) {
          break;
        }
      }
    } else {
      throw Exception("mode Sweep incorrect 1");
    }
    if (yGoal == null || goallineX.isEmpty) {
      throw Exception("goal is null");
    }
    return [goallineX, yGoal];
  }

  List<int> searchGridStart(Sweep sweep, MoveDirect direct) {
    int? yStart;
    List startlineX = [];
    if (sweep == Sweep.UP) {
      for (int j = 0; j < gridHeight; j++) {
        for (int i = 0; i < gridWidth; i++) {
          try {
            if (checkFreeGridFromIndex(i, j, GridValue(0.5))) {
              yStart = j;
              startlineX.add(i);
            }
          } catch (e) {
            debugPrint(e.toString());
            continue;
          }
        }
        if (yStart != null) {
          break;
        }
      }
    } else if (sweep == Sweep.DOWN) {
      for (int j = gridHeight - 1; j >= 0; j--) {
        for (int i = gridWidth - 1; i >= 0; i--) {
          try {
            if (checkFreeGridFromIndex(i, j, GridValue(0.5))) {
              yStart = j;
              startlineX.add(i);
            }
          } catch (e) {
            debugPrint(e.toString());
            continue;
          }
        }
        if (yStart != null) {
          break;
        }
      }
    }
    if (yStart == null || startlineX.isEmpty) {
      throw Exception("can not find point Start 3");
    }
    if (direct == MoveDirect.RIGHT) {
      int x = startlineX
          .reduce((min, element) => min < element ? min : element); // min
      return [x, yStart];
    } else if (direct == MoveDirect.LEFT) {
      int x = startlineX
          .reduce((max, element) => max > element ? max : element); // max
      return [x, yStart];
    } else {
      throw Exception("mode MoveDirect incorrect 4");
    }
  }
}
