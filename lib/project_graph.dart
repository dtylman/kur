import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:kur/config_service.dart';
import 'package:kur/jira_issue.dart';
import 'package:kur/jira_issue_card.dart';
import 'package:kur/jira_service.dart';
import 'package:kur/my_sugiyama_edge_renderer.dart';
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
  // Edge labels for the graph
  Map<int, String> edgeLabels = {};
  double separationValue = 30.0;

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
        filtered.addEdge(edge.source, edge.destination, paint: edge.paint);
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

    SugiyamaAlgorithm sugyama = SugiyamaAlgorithm(
      SugiyamaConfiguration()
        ..bendPointShape = MaxCurvedBendPointShape()
        ..levelSeparation = separationValue.toInt()
        ..nodeSeparation = separationValue.toInt()
        ..orientation = SugiyamaConfiguration.ORIENTATION_LEFT_RIGHT,
    );
    SugiyamaEdgeRenderer existingRenderer = sugyama.renderer as SugiyamaEdgeRenderer;
    sugyama.renderer = MySugiyamaEdgeRenderer(
      nodeData: existingRenderer.nodeData,
      edgeData: existingRenderer.edgeData,
      bendPointShape: existingRenderer.bendPointShape,
      edgeLabels: edgeLabels,
    );

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

  void onGraphLoaded(GraphLoadedEventArgs event) {
    setState(() {
      issues = event.issues;
      graph = event.graph;
      edgeLabels = event.edgeLabels;
      loaded = true;
      debugPrint(
        'Graph loaded with ${issues.length} issues and ${graph!.nodes.length} nodes',
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
          // Slider for level/node separation
          SizedBox(
            width: 180,
            child: Row(
              children: [
                const Text('Separation'),
                Expanded(
                  child: Slider(
                    min: 10,
                    max: 100,
                    divisions: 18,
                    value: separationValue,
                    label: separationValue.round().toString(),
                    onChanged: (v) {
                      setState(() {
                        separationValue = v;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
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
