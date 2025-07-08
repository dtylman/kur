import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:kur/config_service.dart';
import 'package:kur/jira_issue.dart';
import 'package:kur/jira_issue_card.dart';
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
      issues.entries.where((e) => e.value.status != 'Closed'),
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
              child: GraphView(
                graph: filteredGraph!,
                algorithm: SugiyamaAlgorithm(
                  SugiyamaConfiguration()
                    ..bendPointShape = MaxCurvedBendPointShape()
                    ..levelSeparation = 50
                    ..nodeSeparation = 30
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
  }
}
