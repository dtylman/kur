import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:kur/config_service.dart';
import 'package:kur/jira_issue.dart';
import 'package:kur/jira_issue_card.dart';
import 'package:kur/jira_service.dart';
import 'package:kur/project_graph_loader.dart';

class ProjectGraph extends StatefulWidget {
  final Project project;

  const ProjectGraph({super.key, required this.project});

  @override
  State<ProjectGraph> createState() => ProjectGraphState();
}

class ProjectGraphState extends State<ProjectGraph> {
  ProjectGraphLoader? graphLoader;
  Map<String, JiraIssue> issues = {};
  Graph? graph;
  bool loaded = false;
  bool showClosed = true;
  final TransformationController transformationController = TransformationController();

  @override
  void initState() {
    super.initState();        
    graphLoader = ProjectGraphLoader(project:widget.project, onLoaded: onGraphLoaded);
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
      if (sourceId != null && targetId != null && allowedIds.contains(sourceId) && allowedIds.contains(targetId)) {
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
    graphLoader = ProjectGraphLoader(project: widget.project, onLoaded: onGraphLoaded);
  }

  @override
  Widget build(BuildContext context) {
    // Top panel with filter and actions
    Widget topPanel = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Checkbox(
            value: showClosed,
            onChanged: onShowClosedChanged,
          ),
          const Text('Show closed'),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: onRefreshPressed,
            child: const Text('Refresh'),
          ),
          // ...add more actions here if needed...
        ],
      ),
    );

    if (widget.project.issues.isEmpty) {
      return Column(
        children: [
          topPanel,
          const Expanded(
            child: Center(
              child: Text(
                'No issues found in this project',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ),
        ],
      );
    }
    if (!loaded) {
      return Column(
        children: [
          topPanel,
          Expanded(child: Center(child: graphLoader)),
        ],
      );
    }
    if (filteredGraph == null || filteredIssues.isEmpty) {
      return Column(
        children: [
          topPanel,
          const Expanded(
            child: Center(
              child: Text(
                'Graph is empty',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      children: [
        topPanel,
        Expanded(
          child: Container(
            color: Colors.white,
            child: InteractiveViewer(
              constrained: false,
              boundaryMargin: const EdgeInsets.all(100),
              minScale: 0.01,
              maxScale: 5.0,
              transformationController: transformationController,
              child: GraphView(
                graph: filteredGraph!,
                algorithm: SugiyamaAlgorithm(
                  SugiyamaConfiguration()
                    ..bendPointShape = MaxCurvedBendPointShape()
                    ..levelSeparation = 30
                    ..nodeSeparation = 10
                    ..orientation = SugiyamaConfiguration.ORIENTATION_LEFT_RIGHT,
                ),
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

  Widget nodeBuilder(Node node) {
    String? issueID = node.key?.value;
    if (issueID == null || !filteredIssues.containsKey(issueID)) {
      return const Text(
        'Unknown Issue',
        style: TextStyle(fontSize: 12, color: Colors.red),
      );
    }
    JiraIssue? issue = filteredIssues[issueID];
    return JiraIssueCard(issue: issue!);
  }

  void onGraphLoaded(Map<String, JiraIssue> issues, Graph graph) {
    setState(() {
      this.issues = issues;
      this.graph = graph;
      loaded = true;
      debugPrint('Graph loaded with ${issues.length} issues and ${graph.nodes.length} nodes');
    });
    // Fit graph to view after loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fitGraphToView();
    });
  }

  void fitGraphToView() {
    // Try to fit the graph to the available viewport by computing the bounding box of all nodes
    if (filteredGraph == null || filteredGraph!.nodes.isEmpty) {
      transformationController.value = Matrix4.identity();
      return;
    }

    // Find the bounding box of all node positions
    double? minX, minY, maxX, maxY;
    for (final node in filteredGraph!.nodes) {
      final pos = node.position;
      minX = minX == null ? pos.dx : (pos.dx < minX ? pos.dx : minX);
      minY = minY == null ? pos.dy : (pos.dy < minY ? pos.dy : minY);
      maxX = maxX == null ? pos.dx : (pos.dx > maxX ? pos.dx : maxX);
      maxY = maxY == null ? pos.dy : (pos.dy > maxY ? pos.dy : maxY);
    }
    if (minX == null || minY == null || maxX == null || maxY == null) {
      transformationController.value = Matrix4.identity();
      return;
    }

    // Padding around the graph
    const double padding = 40.0;
    final graphWidth = (maxX - minX) + padding * 2;
    final graphHeight = (maxY - minY) + padding * 2;

    // Get the size of the InteractiveViewer by using the context
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      transformationController.value = Matrix4.identity();
      return;
    }
    final Size viewportSize = renderBox.size;

    // Compute scale to fit graph into viewport
    final double scaleX = viewportSize.width / graphWidth;
    final double scaleY = viewportSize.height / graphHeight;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    // Center the graph in the viewport
    final double translateX = -minX + padding + (viewportSize.width / scale - graphWidth) / 2;
    final double translateY = -minY + padding + (viewportSize.height / scale - graphHeight) / 2;

    transformationController.value = Matrix4.identity()
      ..scale(scale, scale)
      ..translate(translateX, translateY);
  }
    
}
