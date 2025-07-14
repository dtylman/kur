import 'package:flutter/material.dart';
import 'package:kur/jira_issue.dart';
import 'package:kur/jira_service.dart';

class IssueListTile extends StatefulWidget {
  final String issueKey;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const IssueListTile({
    super.key,
    required this.issueKey,
    required this.isSelected,
    required this.onTap,
    this.onDelete,
  });

  @override
  State<IssueListTile> createState() => IssueListTileState();
}

class IssueListTileState extends State<IssueListTile> {
  JiraIssue? issue; // to hold the loaded issue  
  Exception? problem; // to handle any errors during issue loading

  @override
  void initState() {
    super.initState();

    loadIssue();
  }

  @override
  Widget build(BuildContext context) {
    if (problem != null) {
      return ListTile(
        title: Text(widget.issueKey),
        selected: widget.isSelected,
        onTap: widget.onTap,
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              icon: const Icon(Icons.error, color: Colors.red),
              tooltip: 'Show error',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(problem.toString())),
                );
              },
            ),
            if (widget.onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: widget.onDelete,
              ),
          ],
        ),
      );
    }
    if (issue == null) {
      return ListTile(
        title: Text(widget.issueKey),
        selected: widget.isSelected,
        onTap: widget.onTap,
        trailing: const CircularProgressIndicator(),
      );
    }
    return ListTile(
      title: Text(widget.issueKey),
      subtitle: issue!.summary != null ? Text(issue!.summary!) : null,
      selected: widget.isSelected,
      onTap: widget.onTap,
      trailing: widget.onDelete != null
          ? IconButton(
              icon: const Icon(Icons.delete),
              onPressed: widget.onDelete,
            )
          : null,
    );
  }

  void loadIssue() async {
    if (widget.issueKey.isEmpty) {
      return;
    }
    try {
      issue = await jiraService.getIssue(widget.issueKey, false);
    } catch (e) {
      problem = e as Exception;           
    }

    setState(() {});
  }
}
