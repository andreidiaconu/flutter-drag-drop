import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Flutter Demo',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: new Container(
          decoration:
              new BoxDecoration(color: new Color.fromARGB(255, 250, 250, 255)),
          child: new MyHomePage(title: 'Flutter Demo Home Page')),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => new _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<BoxViewModel> boxes;

  List<SnapLine> verticalSnapLines;
  List<SnapLine> horizontalSnapLines;
  double gridSquareSize;
  double snapTolerance;

  BoxViewModel selectedBox;
  Offset originalTouchPoint;
  bool dragUsesSnap;
  bool dragUsesKinetics;

  final reference = FirebaseDatabase.instance.reference().child('boxes');

  @override
  void initState() {
    super.initState();
    gridSquareSize = 32.0;
    snapTolerance = 15.0;
    dragUsesSnap = true;
    dragUsesKinetics = true;
    boxes = new List<BoxViewModel>();
//    reference.onValue.listen((event){
//      event.
//    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  _calculateSnapLines(Size widgetSize) {
    verticalSnapLines = new List();
    horizontalSnapLines = new List();
    for (int i = 0; i < (widgetSize.width / gridSquareSize); i++) {
      verticalSnapLines.add(new SnapLine(i * gridSquareSize));
    }
    for (int i = 0; i < (widgetSize.height / gridSquareSize); i++) {
      horizontalSnapLines.add(new SnapLine(i * gridSquareSize));
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: new Column(
        children: <Widget>[
          new Container(
            decoration: new BoxDecoration(color: Colors.white),
            height: 56.0,
            child: new Row(
              children: <Widget>[
                new Container(width: 28.0),
                new Text(
                  "kinetics",
                  style: new TextStyle(color: Colors.black, fontSize: 18.0),
                ),
                new Switch(
                    value: dragUsesKinetics,
                    onChanged: (kineticsEnabled) {
                      setState(() {
                        this.dragUsesKinetics = kineticsEnabled;
                      });
                    }),
                new Text(
                  "grid size",
                  style: new TextStyle(color: Colors.black, fontSize: 18.0),
                ),
                new Expanded(
                  child: new Align(
                    alignment: Alignment.centerLeft,
                    child: new ConstrainedBox(
                      constraints:
                          new BoxConstraints.loose(new Size(343.0, 100.0)),
                      child: new SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                            thumbShape: new RoundSliderThumbShape(1.8)),
                        child: new Slider(
                            value: gridSquareSize,
                            min: 4.0,
                            max: 128.0,
                            onChanged: (value) {
                              setState(() {
                                gridSquareSize = value;
                              });
                            }),
                      ),
                    ),
                  ),
                ),
                new InkWell(
                  onTap: () {
                    setState(() {
                      boxes.add(new BoxViewModel(
                          new Random().nextBool()
                              ? new Color.fromARGB(255, 191, 19, 99)
                              : new Color.fromARGB(255, 14, 121, 178),
                          new Rect.fromLTWH(100.0 + new Random().nextInt(50),
                              100.0 + new Random().nextInt(50), 160.0, 160.0)));
                    });
                  },
                  child: new Container(
                    width: 46.0,
                    height: 46.0,
                    decoration: new BoxDecoration(
                        color: Colors.blue,
                        borderRadius: new BorderRadius.circular(10.0)),
                    margin: new EdgeInsets.only(right: 8.0),
                    alignment: Alignment.center,
                    child: new Text(
                      "+",
                      style: new TextStyle(
                          color: Colors.white,
                          fontSize: 28.0,
                          decoration: null),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              ],
            ),
          ),
          new Expanded(
            child: new LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
              _calculateSnapLines(
                  new Size(constraints.maxWidth, constraints.maxHeight));
              return new Stack(
                children: <Widget>[
                  new GridPainter(verticalSnapLines, horizontalSnapLines),
                  new GestureDetector(
                    child: new Stack(
                        children: boxes
                            .map((boxViewModel) => new Box(boxViewModel))
                            .toList()),
                    onScaleStart: _onPanStart,
                    onScaleUpdate: _onPanUpdate,
                    onScaleEnd: _onPanEnd,
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  void _onPanStart(ScaleStartDetails details) {
    RenderBox getBox = context.findRenderObject();
    var local = getBox.globalToLocal(details.focalPoint);
    var selected = boxes.lastWhere((box) => box.rectangle.contains(local));
    setState(() {
      selectedBox = selected;
      originalTouchPoint = details.focalPoint;
    });
  }

  void _onPanUpdate(ScaleUpdateDetails details) {
    var movementOffset = details.focalPoint - originalTouchPoint;
    setState(() {
      originalTouchPoint = details.focalPoint;
      selectedBox.rectangle =
          selectedBox.rectangle.translate(movementOffset.dx, movementOffset.dy);
    });
  }

  void _onPanEnd(ScaleEndDetails details) {
    Rect wantedRect = selectedBox.rectangle;
    double closestVerticalSnap = _getClosestVerticalSnap(wantedRect);
    double closestHorizontalSnap = _getClosestHorizontaSnap(wantedRect);
    Rect actualRect =
        wantedRect.translate(-closestVerticalSnap, -closestHorizontalSnap);
    setState(() {
      selectedBox.rectangle = actualRect;
    });
    _saveData();
  }

  Rect _getSnappedRectangle(Rect wantedRect, double closestVerticalSnap,
      double closestHorizontalSnap) {
    Rect actualRect = wantedRect.translate(
        closestVerticalSnap.abs() < snapTolerance ? -closestVerticalSnap : 0.0,
        closestHorizontalSnap.abs() < snapTolerance
            ? -closestHorizontalSnap
            : 0.0);
    return actualRect;
  }

  double _getClosestHorizontaSnap(Rect wantedRect) {
    double smallestHorizontalSnap = double.infinity;
    horizontalSnapLines.forEach((snapLine) {
      var topSnap = wantedRect.top - snapLine.offset;
      if (topSnap.abs() < smallestHorizontalSnap.abs())
        smallestHorizontalSnap = topSnap;
//      var bottomSnap = wantedRect.bottom - snapLine.offset;
//      if (bottomSnap.abs() < smallestHorizontalSnap.abs())
//        smallestHorizontalSnap = bottomSnap;
    });
    return smallestHorizontalSnap;
  }

  double _getClosestVerticalSnap(Rect wantedRect) {
    double smallestVerticalSnap = double.infinity;
    verticalSnapLines.forEach((snapLine) {
      var leftSnap = wantedRect.left - snapLine.offset;
      if (leftSnap.abs() < smallestVerticalSnap.abs())
        smallestVerticalSnap = leftSnap;
//      var rightSnap = wantedRect.right - snapLine.offset;
//      if (rightSnap.abs() < smallestVerticalSnap.abs())
//        smallestVerticalSnap = rightSnap;
    });
    return smallestVerticalSnap;
  }

  void _saveData() {
    var boxesFirebaseFormat = boxes
        .asMap()
        .map((key, box) => new MapEntry(key.toString(), box.toJson()));
    reference.set(boxesFirebaseFormat);
  }
}

class BoxViewModel {
  Color color;
  Rect rectangle;

  BoxViewModel(this.color, this.rectangle);

  BoxViewModel.fromJson(Map<String, dynamic> json)
      : color = new Color(json['color']),
        rectangle = new Rect.fromLTWH(
            json['left'], json['top'], json['width'], json['height']);

  Map<String, dynamic> toJson() => {
        'color': color.value,
        'left': rectangle.left,
        'top': rectangle.top,
        'width': rectangle.width,
        'height': rectangle.height,
      };
}

class SnapLine {
  bool visible = false;
  double offset;

  SnapLine(this.offset);
}

class Box extends StatelessWidget {
  final BoxViewModel viewModel;

  Box(this.viewModel);

  @override
  Widget build(BuildContext context) {
    return new Positioned.fromRect(
      child: new Container(
              decoration: new BoxDecoration(
                border: new Border.all(
                  color: Colors.black.withOpacity(0.5),
                  width: 4.0,
                  style: BorderStyle.solid
                ),
//                borderRadius: new BorderRadius.all(new Radius.elliptical(20.0, 20.0)),
                color: viewModel.color,
              ),
      ),
      rect: viewModel.rectangle,
    );
  }
}

class GridPainter extends StatelessWidget {
  List<SnapLine> verticalSnapLines;
  List<SnapLine> horizontalSnapLines;

  GridPainter(this.verticalSnapLines, this.horizontalSnapLines);

  @override
  Widget build(BuildContext context) {
    return new CustomPaint(
      painter: new _GridPainter(verticalSnapLines, horizontalSnapLines),
      size: Size.infinite,
    );
  }
}

class _GridPainter extends CustomPainter {
  final List<SnapLine> verticalSnapLines;
  final List<SnapLine> horizontalSnapLines;
  Paint linePaint = new Paint();

  _GridPainter(this.verticalSnapLines, this.horizontalSnapLines) {
    linePaint.color = new Color.fromARGB(255, 242, 235, 230);
    linePaint.strokeWidth = 1.0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    verticalSnapLines.forEach((snapLine) => canvas.drawLine(
        new Offset(snapLine.offset, 0.0),
        new Offset(snapLine.offset, size.height),
        linePaint));
    horizontalSnapLines.forEach((snapLine) => canvas.drawLine(
        new Offset(0.0, snapLine.offset),
        new Offset(size.width, snapLine.offset),
        linePaint));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}

/// This is the default shape to a [Slider]'s thumb if no
/// other shape is specified.
///
/// See also:
///
///  * [Slider] for the component that this is meant to display this shape.
///  * [SliderThemeData] where an instance of this class is set to inform the
///    slider of the shape of the its thumb.
class RoundSliderThumbShape extends SliderComponentShape {
  static const double _thumbRadius = 6.0;
  static const double _disabledThumbRadius = 4.0;

  final sizeMultiplier;

  RoundSliderThumbShape(this.sizeMultiplier);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return new Size.fromRadius(
        sizeMultiplier * (isEnabled ? _thumbRadius : _disabledThumbRadius));
  }

  @override
  void paint(
    PaintingContext context,
    bool isDiscrete,
    Offset thumbCenter,
    Animation<double> activationAnimation,
    Animation<double> enableAnimation,
    TextPainter labelPainter,
    SliderThemeData sliderTheme,
    TextDirection textDirection,
    double textScaleFactor,
    double value,
  ) {
    final Canvas canvas = context.canvas;
    final Tween<double> radiusTween = new Tween<double>(
        begin: sizeMultiplier * _disabledThumbRadius,
        end: sizeMultiplier * _thumbRadius);
    final ColorTween colorTween = new ColorTween(
        begin: sliderTheme.disabledThumbColor, end: sliderTheme.thumbColor);
    canvas.drawCircle(
      thumbCenter,
      radiusTween.evaluate(enableAnimation),
      new Paint()..color = colorTween.evaluate(enableAnimation),
    );
  }
}
