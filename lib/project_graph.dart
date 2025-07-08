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

  @override
  void initState() {
    super.initState();        
    graphLoader = ProjectGraphLoader(project:widget.project, onLoaded: onGraphLoaded);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.project.issues.isEmpty) {
      return const Center(
        child: Text(
          'No issues found in this project',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    if (!loaded) {
      return Center(child: graphLoader);
    }
    if (graph == null || issues.isEmpty) {
      return const Center(
        child: Text(
          'Graph is empty',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    return Container(
      color: Colors.white,
      child: InteractiveViewer(
        constrained: false,
        boundaryMargin: const EdgeInsets.all(100),
        minScale: 0.01,
        maxScale: 5.0,
        child: GraphView(
          graph: graph!,
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
    );
  }


  Widget nodeBuilder(Node node) {
    String? issueID = node.key?.value;
    if (issueID == null || !issues.containsKey(issueID)) {
      return const Text(
        'Unknown Issue',
        style: TextStyle(fontSize: 12, color: Colors.red),
      );
    }
    JiraIssue? issue = issues[issueID];

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
