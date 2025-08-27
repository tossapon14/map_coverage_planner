import 'package:flutter/material.dart';

class PaintDot extends CustomPainter{
  late final Color color;
  PaintDot({this.color=Colors.yellow});
  @override
  void paint(Canvas canvas, Size size) {
    // TODO: implement paint
    Paint paint = Paint()
      ..color = color;
    Paint paint2 = Paint()
      ..color = Colors.blue
    ..style = PaintingStyle.fill;

    Offset offset = Offset(size.width / 2, size.height / 2);
    double radius =  size.width/2;
    // canvas.drawRect(Offset(0,0) & size, paint2);
    canvas.drawCircle(offset, radius, paint);
  }

  @override
  bool shouldRepaint(PaintDot oldDelegate) {
    // TODO: implement shouldRepaint
    return false;
  }
}