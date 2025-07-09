import 'dart:math';
import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

class MySugiyamaEdgeRenderer extends ArrowEdgeRenderer {
  Map<Node, SugiyamaNodeData> nodeData;
  Map<Edge, SugiyamaEdgeData> edgeData;
  BendPointShape bendPointShape;
  Map<int, String> edgeLabels;

  var path = Path();

  MySugiyamaEdgeRenderer({
    required this.nodeData,
    required this.edgeData,
    required this.bendPointShape,
    required this.edgeLabels,
  }) : super();

  @override
  void render(Canvas canvas, Graph graph, Paint paint) {
    var trianglePaint = Paint()
      ..color = paint.color
      ..style = PaintingStyle.fill;

    graph.edges.forEach((edge) {
      final source = edge.source;

      var x = source.x;
      var y = source.y;

      var destination = edge.destination;

      var x1 = destination.x;
      var y1 = destination.y;
      path.reset();

      var clippedLine = <double>[];

      Paint? edgeTrianglePaint;
      if (edge.paint != null) {
        edgeTrianglePaint = Paint()
          ..color = edge.paint?.color ?? paint.color
          ..style = PaintingStyle.fill;
      }

      var currentPaint = edge.paint ?? paint
        ..style = PaintingStyle.stroke;

      if (edgeData.containsKey(edge) && edgeData[edge]!.bendPoints.isNotEmpty) {
        // draw bend points
        var bendPoints = edgeData[edge]!.bendPoints;
        final size = bendPoints.length;

        if (nodeData[source]!.isReversed) {
          clippedLine = clipLine(
            bendPoints[2],
            bendPoints[3],
            bendPoints[0],
            bendPoints[1],
            destination,
          );
        } else {
          clippedLine = clipLine(
            bendPoints[size - 4],
            bendPoints[size - 3],
            bendPoints[size - 2],
            bendPoints[size - 1],
            destination,
          );
        }

        final triangleCentroid = drawTriangle(
          canvas,
          edgeTrianglePaint ?? trianglePaint,
          clippedLine[0],
          clippedLine[1],
          clippedLine[2],
          clippedLine[3],
        );

        path.reset();
        path.moveTo(bendPoints[0], bendPoints[1]);

        final bendPointsWithoutDuplication = <Offset>[];

        for (var i = 0; i < bendPoints.length; i += 2) {
          final isLastPoint = i == bendPoints.length - 2;

          final x = bendPoints[i];
          final y = bendPoints[i + 1];
          final x2 = isLastPoint ? -1 : bendPoints[i + 2];
          final y2 = isLastPoint ? -1 : bendPoints[i + 3];
          if (x == x2 && y == y2) {
            // Skip when two consecutive points are identical
            // because drawing a line between would be redundant in this case.
            continue;
          }
          bendPointsWithoutDuplication.add(Offset(x, y));
        }

        if (bendPointShape is MaxCurvedBendPointShape) {
          _drawMaxCurvedBendPointsEdge(bendPointsWithoutDuplication);
        } else if (bendPointShape is CurvedBendPointShape) {
          final shape = bendPointShape as CurvedBendPointShape;
          _drawCurvedBendPointsEdge(
            bendPointsWithoutDuplication,
            shape.curveLength,
          );
        } else {
          _drawSharpBendPointsEdge(bendPointsWithoutDuplication);
        }

        path.lineTo(triangleCentroid[0], triangleCentroid[1]);
        canvas.drawPath(path, currentPaint);
        // Calculate direction for label placement
        final dx =
            triangleCentroid[0] -
            bendPointsWithoutDuplication[bendPointsWithoutDuplication.length -
                    2]
                .dx;
        final dy =
            triangleCentroid[1] -
            bendPointsWithoutDuplication[bendPointsWithoutDuplication.length -
                    2]
                .dy;
        _drawEdgeLabel(
          canvas,
          triangleCentroid[0],
          triangleCentroid[1],
          dx,
          dy,
          currentPaint.color,
          edge,
        );
      } else {
        final startX = x + source.width / 2;
        final startY = y + source.height / 2;
        final stopX = x1 + destination.width / 2;
        final stopY = y1 + destination.height / 2;

        clippedLine = clipLine(startX, startY, stopX, stopY, destination);

        final triangleCentroid = drawTriangle(
          canvas,
          edgeTrianglePaint ?? trianglePaint,
          clippedLine[0],
          clippedLine[1],
          clippedLine[2],
          clippedLine[3],
        );

        canvas.drawLine(
          Offset(clippedLine[0], clippedLine[1]),
          Offset(triangleCentroid[0], triangleCentroid[1]),
          currentPaint,
        );
        // Calculate direction for label placement
        final dx = triangleCentroid[0] - clippedLine[0];
        final dy = triangleCentroid[1] - clippedLine[1];
        _drawEdgeLabel(
          canvas,
          triangleCentroid[0],
          triangleCentroid[1],
          dx,
          dy,
          currentPaint.color,
          edge,
        );
      }
    });
  }

  void _drawSharpBendPointsEdge(List<Offset> bendPoints) {
    for (var i = 1; i < bendPoints.length - 1; i++) {
      path.lineTo(bendPoints[i].dx, bendPoints[i].dy);
    }
  }

  void _drawMaxCurvedBendPointsEdge(List<Offset> bendPoints) {
    for (var i = 1; i < bendPoints.length - 1; i++) {
      final nextNode = bendPoints[i];
      final afterNextNode = bendPoints[i + 1];
      final curveEndPoint = Offset(
        (nextNode.dx + afterNextNode.dx) / 2,
        (nextNode.dy + afterNextNode.dy) / 2,
      );
      path.quadraticBezierTo(
        nextNode.dx,
        nextNode.dy,
        curveEndPoint.dx,
        curveEndPoint.dy,
      );
    }
  }

  void _drawCurvedBendPointsEdge(List<Offset> bendPoints, double curveLength) {
    for (var i = 1; i < bendPoints.length - 1; i++) {
      final previousNode = i == 1 ? null : bendPoints[i - 2];
      final currentNode = bendPoints[i - 1];
      final nextNode = bendPoints[i];
      final afterNextNode = bendPoints[i + 1];

      final arcStartPointRadians = atan2(
        nextNode.dy - currentNode.dy,
        nextNode.dx - currentNode.dx,
      );
      final arcStartPoint =
          nextNode - Offset.fromDirection(arcStartPointRadians, curveLength);
      final arcEndPointRadians = atan2(
        nextNode.dy - afterNextNode.dy,
        nextNode.dx - afterNextNode.dx,
      );
      final arcEndPoint =
          nextNode - Offset.fromDirection(arcEndPointRadians, curveLength);

      if (previousNode != null &&
          ((currentNode.dx == nextNode.dx && nextNode.dx == afterNextNode.dx) ||
              (currentNode.dy == nextNode.dy &&
                  nextNode.dy == afterNextNode.dy))) {
        path.lineTo(nextNode.dx, nextNode.dy);
      } else {
        path.lineTo(arcStartPoint.dx, arcStartPoint.dy);
        path.quadraticBezierTo(
          nextNode.dx,
          nextNode.dy,
          arcEndPoint.dx,
          arcEndPoint.dy,
        );
      }
    }
  }

  // Helper to draw a small label above the arrow, with direction-based placement
  void _drawEdgeLabel(
    Canvas canvas,
    double x,
    double y,
    double dx,
    double dy,
    Color lineColor,
    Edge edge,
  ) {
    final label = getLabel(edge);

    const fontSize = 10.0;
    const padding = 2.0;
    const spacing = 2.0; // 2 pixels between arrow and label
    final textStyle = TextStyle(
      color: Colors.black.withAlpha(700),
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
    );
    final textSpan = TextSpan(text: label, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final width = textPainter.width + padding * 2;
    final height = textPainter.height + padding * 2;

    // Determine direction
    Offset offset = Offset.zero;
    if (dx.abs() > dy.abs()) {
      // Horizontal arrow
      if (dx < 0) {
        // Facing left: above and rightish
        offset = Offset(width / 2 + spacing, -height / 2 - spacing);
      } else {
        // Facing right: above and leftish
        offset = Offset(-width / 2 - spacing, -height / 2 - spacing);
      }
    } else {
      // Vertical arrow
      if (dy < 0) {
        // Facing up: below
        offset = Offset(0, height / 2 + spacing);
      } else {
        // Facing down: above
        offset = Offset(0, -height / 2 - spacing);
      }
    }
    final rect = Rect.fromCenter(
      center: Offset(x, y) + offset,
      width: width,
      height: height,
    );
    final bgPaint = Paint()
      ..color = lineColor.withAlpha(50)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(4)),
      bgPaint,
    );
    textPainter.paint(canvas, Offset(rect.left + padding, rect.top + padding));
  }

  String getLabel(Edge edge) {
    var label = edgeLabels[edge.hashCode] ?? '';
    // Limit label to 8 characters per line, wrapping at word boundaries
    if (label.length > 8) {
      final words = label.split(' ');
      final lines = <String>[];
      var currentLine = '';
      for (final word in words) {
        if (currentLine.isEmpty) {
          currentLine = word;
        } else if ((currentLine.length + 1 + word.length) <= 8) {
          currentLine += ' $word';
        } else {
          lines.add(currentLine);
          currentLine = word;
        }
      }
      if (currentLine.isNotEmpty) {
        lines.add(currentLine);
      }
      label = lines.join('\n');
    }

    return label;
  }
}
