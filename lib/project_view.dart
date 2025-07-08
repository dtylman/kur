import 'package:flutter/material.dart';
import 'package:kur/config_service.dart';
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
        Container(
          width: 250,
          color: Colors.grey[200],
          child: Column(
            children: [
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
          ),
        ),
        // Main panel
        Expanded(
          child: ProjectGraph(
            key: ValueKey(project!.id),
            project: project!,
            selectedIssueKey: selectedIssueKey,
          ),
        ),
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
}
