import 'package:flutter/material.dart';
import 'package:kur/issue_list_tile.dart';

class ProjectsIssuesList extends StatefulWidget {
  final List<String> issues;
  final ValueChanged<String> onIssueSelected;
  final ValueChanged<String>? onIssueDeleted;

  const ProjectsIssuesList({
    super.key,
    required this.issues,
    required this.onIssueSelected,
    this.onIssueDeleted,
  });

  @override
  ProjectsIssuesListState createState() => ProjectsIssuesListState();
}

class ProjectsIssuesListState extends State<ProjectsIssuesList> {
  String? _selectedIssue;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.issues.length,
      itemBuilder: (context, index) {
        final issue = widget.issues[index];
        final isSelected = _selectedIssue == issue;
        return IssueListTile(issueKey: issue, 
          isSelected: isSelected,
          onTap: () {
            setState(() {
              _selectedIssue = issue;
            });
            widget.onIssueSelected(issue);
          },
          onDelete: () {
            if (widget.onIssueDeleted != null) {
              widget.onIssueDeleted!(issue);
            }
          },
        );
      },
    );
  }
}
