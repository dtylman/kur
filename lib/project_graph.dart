import 'dart:math';

import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:kur/config_service.dart';
import 'package:kur/jira_issue.dart';
import 'package:kur/jira_issue_card.dart';
import 'package:kur/jira_service.dart';
import 'package:kur/project_graph_loader.dart';

class ProjectGraph extends StatefulWidget {
  final Project project;
  final String? selectedIssueKey;

  const ProjectGraph({super.key, required this.project, this.selectedIssueKey});

  @override
  State<ProjectGraph> createState() => ProjectGraphState();
}

class ProjectGraphState extends State<ProjectGraph> {
  ProjectGraphLoader? graphLoader;
  Map<String, JiraIssue> issues = {};
  Graph? graph;
  bool loaded = false;
  bool showClosed = true;
  final TextEditingController filterController = TextEditingController();
  String? filterText;
  String? highlightedIssueKey;

  @override
  void initState() {
    super.initState();
    graphLoader = ProjectGraphLoader(
      project: widget.project,
      onLoaded: onGraphLoaded,
    );
  }

  void onShowClosedChanged(bool? value) {
    setState(() {
      showClosed = value ?? true;
    });
  }

  Map<String, JiraIssue> get filteredIssues {
    if (showClosed) return issues;
    return Map.fromEntries(
      issues.entries.where((e) => e.value.status?.toLowerCase() != 'closed'),
    );
  }

  Graph? get filteredGraph {
    if (graph == null) return null;
    if (showClosed) return graph;
    // Filter nodes and edges based on filteredIssues
    final filtered = Graph();
    final allowedIds = filteredIssues.keys.toSet();
    for (final node in graph!.nodes) {
      final id = node.key?.value;
      if (id != null && allowedIds.contains(id)) {
        filtered.addNode(node);
      }
    }
    for (final edge in graph!.edges) {
      final sourceId = edge.source.key?.value;
      final targetId = edge.destination.key?.value;
      if (sourceId != null &&
          targetId != null &&
          allowedIds.contains(sourceId) &&
          allowedIds.contains(targetId)) {
        filtered.addEdge(edge.source, edge.destination);
      }
    }
    return filtered;
  }

  void onRefreshPressed() async {
    await jiraService.clearCachedItems(issues.values);
    setState(() {
      loaded = false;
    });
    graphLoader = ProjectGraphLoader(
      project: widget.project,
      onLoaded: onGraphLoaded,
    );
  }

  @override
  Widget build(BuildContext context) {
    SugiyamaAlgorithm sugyama = SugiyamaAlgorithm(
      SugiyamaConfiguration()
        ..bendPointShape = MaxCurvedBendPointShape()
        ..levelSeparation = 30
        ..nodeSeparation = 30
        ..orientation = SugiyamaConfiguration.ORIENTATION_LEFT_RIGHT,
    );
    sugyama.renderer = MySugiyamaEdgeRenderer(
      sugyama.renderer as SugiyamaEdgeRenderer,
    );
    if (widget.project.issues.isEmpty) {
      return Expanded(
        child: Center(
          child: Text(
            'No issues found in this project',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }
    if (!loaded) {
      return Expanded(child: Center(child: graphLoader));
    }
    if (filteredGraph == null || filteredIssues.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text(
            'Graph is empty',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }
    return Column(
      children: [
        buildTopPanel(),
        Expanded(
          child: Container(
            color: Colors.white,
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(100),
              minScale: 0.5,
              maxScale: 2.0,
              child: GraphView(
                graph: filteredGraph!,
                algorithm: sugyama,
                paint: Paint()
                  ..color = Colors.blue
                  ..strokeWidth = 2
                  ..style = PaintingStyle.stroke,
                builder: nodeBuilder,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void onFilterSearch() {
    final query = filterController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        highlightedIssueKey = null;
      });
      return;
    }
    String? foundKey;
    for (final entry in filteredIssues.entries) {
      final issue = entry.value;
      if (issue.key.toLowerCase().contains(query) ||
          (issue.summary?.toLowerCase().contains(query) ?? false) ||
          (issue.type?.toLowerCase().contains(query) ?? false) ||
          (issue.status?.toLowerCase().contains(query) ?? false) ||
          (issue.assignee?.toLowerCase().contains(query) ?? false) ||
          (issue.reporter?.toLowerCase().contains(query) ?? false)) {
        foundKey = issue.key;
        break;
      }
    }
    setState(() {
      highlightedIssueKey = foundKey;
    });
  }

  Widget nodeBuilder(Node node) {
    String? issueID = node.key?.value;
    if (issueID == null || !filteredIssues.containsKey(issueID)) {
      return const Text(
        'Unknown Issue',
        style: TextStyle(fontSize: 12, color: Colors.red),
      );
    }
    JiraIssue? issue = filteredIssues[issueID];
    final isSelected =
        (widget.selectedIssueKey == issueID) ||
        (highlightedIssueKey == issueID);
    return JiraIssueCard(issue: issue!, isSelected: isSelected);
  }

  void onGraphLoaded(Map<String, JiraIssue> issues, Graph graph) {
    setState(() {
      this.issues = issues;
      this.graph = graph;
      loaded = true;
      debugPrint(
        'Graph loaded with ${issues.length} issues and ${graph.nodes.length} nodes',
      );
    });
  }

  Widget buildTopPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Checkbox(value: showClosed, onChanged: onShowClosedChanged),
          const Text('Show closed'),
          const SizedBox(width: 16),
          // Filter input and search button
          SizedBox(
            width: 200,
            child: TextField(
              controller: filterController,
              decoration: const InputDecoration(
                labelText: 'Filter',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => onFilterSearch(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onFilterSearch,
            child: const Text('Search'),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: onRefreshPressed,
            child: const Text('Refresh'),
          ),
          // ...add more actions here if needed...
        ],
      ),
    );
  }
}

class MySugiyamaEdgeRenderer extends ArrowEdgeRenderer {
  late Map<Node, SugiyamaNodeData> nodeData;
  late Map<Edge, SugiyamaEdgeData> edgeData;
  late BendPointShape bendPointShape;

  var path = Path();

  MySugiyamaEdgeRenderer(SugiyamaEdgeRenderer renderer) : super() {
    nodeData = renderer.nodeData;
    edgeData = renderer.edgeData;
    bendPointShape = renderer.bendPointShape;
  }

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
        final dx = triangleCentroid[0] - bendPointsWithoutDuplication[bendPointsWithoutDuplication.length - 2].dx;
        final dy = triangleCentroid[1] - bendPointsWithoutDuplication[bendPointsWithoutDuplication.length - 2].dy;
        _drawEdgeLabel(canvas, triangleCentroid[0], triangleCentroid[1], dx, dy, currentPaint.color);
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
        _drawEdgeLabel(canvas, triangleCentroid[0], triangleCentroid[1], dx, dy, currentPaint.color);
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
  void _drawEdgeLabel(Canvas canvas, double x, double y, double dx, double dy, Color lineColor) {
    const label = 'this is a\n long line';
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
    textPainter.paint(
      canvas,
      Offset(rect.left + padding, rect.top + padding),
    );
  }
}
