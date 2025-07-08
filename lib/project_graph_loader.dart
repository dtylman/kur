import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:kur/config_service.dart';
import 'package:kur/jira_issue.dart';
import 'package:kur/jira_service.dart';

class ProjectGraphLoader extends StatefulWidget {
  final void Function(Map<String, JiraIssue>, Graph) onLoaded;
  final Project project;

  const ProjectGraphLoader({
    super.key,
    required this.onLoaded,
    required this.project,
  });

  @override
  ProjectGraphLoaderState createState() => ProjectGraphLoaderState();
}

class ProjectGraphLoaderState extends State<ProjectGraphLoader> {
  Map<String, JiraIssue> issues = {};
  Graph graph = Graph();
  var progress = 0.0;
  String status = 'Loading...';
  final Set<String> visited = <String>{};

  @override
  void initState() {
    super.initState();

    buildGraph();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(status),
        const SizedBox(height: 20),
        LinearProgressIndicator(
          semanticsLabel: 'Graph loading progress',
          value: progress,
        ),
      ],
    );
  }

  void buildGraph() async {
    debugPrint('Building graph for project: ${widget.project.name}');
    visited.clear();
    try {
      for (var key in widget.project.issues) {
        await addIssue(key);
        setState(() {
          progress = (issues.length / widget.project.issues.length);
        });
      }
    } finally {
      widget.onLoaded(issues, graph);
    }
  }

  Future<void> addLinks(
    Map<String, JiraIssueLink> links,
    Node node,
    bool inbound,
  ) async {
    var current = 0;

    for (var link in links.values) {
      Node childeNode = await addIssue(link.key);
      MaterialColor color = getLinkColor(link.name);

      if (inbound) {
        graph.addEdge(childeNode, node, paint: Paint()..color = color);
      } else {
        graph.addEdge(node, childeNode, paint: Paint()..color = color);
      }

      debugPrint(
        'Added link from ${node.key?.value} to ${childeNode.key?.value} with color $color',
      );

      setState(() {
        progress = current / links.length;
      });
    }
  }

  Future<Node> addIssue(String key) async {
    if (visited.contains(key)) {
      return graph.getNodeUsingId(key);
    }
    visited.add(key);
    Node? node;
    JiraIssue? issue = issues[key];
    if (issue == null) {
      issue = await jiraService.getIssue(key, true);
      issues[key] = issue;
      node = Node.Id(issue.key);
      graph.addNode(node);
    } else {
      node = graph.getNodeUsingId(issue.key);
    }

    await addLinks(issue.outLinks, node, false);
    //await addLinks(issue.inLinks, node, true);

    setState(() {
      status = 'Reading issue: ${issue!.key}: ${issue.summary}';
    });

    return node;
  }

  MaterialColor getLinkColor(String name) {
    switch (name.toLowerCase()) {
      case 'subtask':
        return Colors.green;
      case 'relates':
        return Colors.orange;
      case 'blocks':
        return Colors.red;
      case 'clones':
      case 'cloners':
        return Colors.purple;
      case 'duplicate':
        return Colors.grey;
      case 'bonfire testing':
        return Colors.teal;
      case 'child':
        return Colors.lightBlue;
      default:
        debugPrint('Unknown link type: $name');
        return Colors.blue; // Default color for unknown links
    }
  }
}
