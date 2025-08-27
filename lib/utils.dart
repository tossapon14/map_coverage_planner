import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
double lerp(A,B,t)=> A+(B-A)*t;

List<double>? getIntersection(List<double> A,List<double> B,List<double> C,List<double> D){
  double tTop=(D[0]-C[0])*(A[1]-C[1])-(D[1]-C[1])*(A[0]-C[0]);
  double  uTop=(C[1]-A[1])*(A[0]-B[0])-(C[0]-A[0])*(A[1]-B[1]);
  double  bottom=(D[1]-C[1])*(B[0]-A[0])-(D[0]-C[0])*(B[1]-A[1]);

  if(bottom!=0){
    double t=tTop/bottom;
    double u=uTop/bottom;
    if (t>=0&&t<=1&&u>=0&&u<=1){
      double x=lerp(A[0],B[0],t);
      double y=lerp(A[1],B[1],t);
      return [x,y,t];
    }
    return null;
  }
  return null;
}



List calculate_normal_vector(List p1,List p2){
  double dx = p2[0] - p1[0];
  double dy = p2[1] - p1[1];
  double length = math.sqrt(dx*dx + dy*dy);
  double nx = dy / length;  // Reverse direction for inside offset
  double ny = -dx / length; // # Reverse direction for inside offset
  return [nx, ny];
}
List<LatLng> convertListToLatLng(List point){
   List<LatLng> latlng =[];
   for(int i=0;i<point.length;i++){
      latlng.add(LatLng(point[i][1], point[i][0]));
   }
   return latlng;
}