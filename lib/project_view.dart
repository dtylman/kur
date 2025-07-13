import 'package:flutter/material.dart';
import 'package:kur/config_service.dart';
import 'package:kur/project_details.dart';
import 'package:kur/project_graph.dart';
import 'package:kur/project_issues_list.dart';

class ProjectView extends StatefulWidget {
  final String projectID;

  const ProjectView({super.key, required this.projectID});

  @override
  State<ProjectView> createState() => ProjectViewState();
}

class ProjectViewState extends State<ProjectView> {
  Project? project;
  String? selectedIssueKey;
  bool _isLeftPaneCollapsed = false;

  @override
  void initState() {
    super.initState();
    project = config.getProject(widget.projectID);
  }

  @override
  Widget build(BuildContext context) {
    if (project == null) {
      return Text('Project ${widget.projectID} not found');
    }
    return Row(
      children: [
        // Left pane
        buildLeftPane(),
        // Main panel
        buildMainPane(),
      ],
    );
  }

  void onAddIssue() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add Issue'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Issue Text'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    project!.issues.add(text);
                  });
                  config.saveProject(project!);
                }
                Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void onIssueDeleted(String value) {
    setState(() {
      project!.issues.remove(value);
      config.saveProject(project!);
    });
  }

  void onIssueSelected(String value) {
    setState(() {
      selectedIssueKey = value;
    });
    debugPrint('Issue selected: $value');
  }

  Widget buildLeftPane() {
    final double paneWidth = _isLeftPaneCollapsed ? 50 : 250;
    return Container(
      width: paneWidth,
      color: Colors.grey[200],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isLeftPaneCollapsed
                        ? Icons.chevron_right
                        : Icons.chevron_left,
                  ),
                  onPressed: () {
                    setState(() {
                      _isLeftPaneCollapsed = !_isLeftPaneCollapsed;
                    });
                  },
                  tooltip: _isLeftPaneCollapsed ? 'Expand' : 'Collapse',
                ),
                if (!_isLeftPaneCollapsed)
                  Text(
                    'Issues',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
              ],
            ),
          ),
          if (!_isLeftPaneCollapsed) ...[
            Expanded(
              child: ProjectsIssuesList(
                issues: project!.issues,
                onIssueSelected: onIssueSelected,
                onIssueDeleted: onIssueDeleted,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                onPressed: onAddIssue,
                icon: const Icon(Icons.add),
                label: const Text('Add Issue'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildMainPane() {
    return Expanded(
      child: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            TabBar(
              onTap: (value) => print(value),
              tabs: [
                Tab(text: 'Details'),
                Tab(text: 'Graph'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ProjectDetails(
                    key: ValueKey(project!.id),
                    project: project!,
                    selectedIssueKey: selectedIssueKey,
                  ),
                  ProjectGraph(
                    key: ValueKey(project!.id),
                    project: project!,
                    selectedIssueKey: selectedIssueKey,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
