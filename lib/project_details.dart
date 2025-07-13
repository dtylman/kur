import 'package:flutter/material.dart';
import 'package:kur/jira_issue.dart';
import 'package:kur/project_graph_loader.dart';

class ProjectDetails extends StatefulWidget {
  final Key key;
  final dynamic project;
  final String? selectedIssueKey;

  const ProjectDetails({
    required this.key,
    required this.project,
    this.selectedIssueKey,
  }) : super(key: key);

  @override
  State<ProjectDetails> createState() => ProjectDetailsState();
}

class ProjectDetailsState extends State<ProjectDetails> {
  ProjectGraphLoader? graphLoader;
  
  bool loaded = false;

  Map<String, JiraIssue> issues= {};

    @override
  void initState() {
    super.initState();
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

    var sortedIssues = issues.values.toList()
      ..sort((a, b) => (b.status ?? '').compareTo(a.status ?? ''));
    
    return Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: DataTable(                    
            columns: const [
            DataColumn(label: Text('Key')),
            DataColumn(label: Text('Summary')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Assignee')),
            DataColumn(label: Text('Reporter')),
            DataColumn(label: Text('Type')),

            ],          
          rows: sortedIssues.map((issue) {
            return DataRow(
              cells: [                
                DataCell(Text(issue.key)),
                DataCell(Text(issue.summary ?? '')),
                DataCell(Text(issue.status ?? '')),
                DataCell(Text(issue.assignee ?? '')),
                DataCell(Text(issue.reporter ?? '')),
                DataCell(Text(issue.type ?? '')),
               
              ],
            );
          }).toList(),
        ),
      ),
    );
    
  }

  void onGraphLoaded(GraphLoadedEventArgs args) {
    
    setState(() {
      issues = args.issues;
      loaded = true;
    });
  }
}