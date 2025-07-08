import 'package:flutter/material.dart';
import 'package:kur/jira_issue.dart';
import 'package:kur/jira_service.dart';

class JiraIssueCard extends StatelessWidget {
  final JiraIssue issue;

  const JiraIssueCard({super.key, required this.issue});

  @override
  Widget build(BuildContext context) {
    var backgroundColor = getColorForType(issue.type);
    
    return SizedBox(
      width: 280,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: backgroundColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // First row: Title, Type, Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: onTitlePressed,
                    child: Text(
                      issue.key,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  if (issue.type != null)
                    Row(
                      children: [
                        const Icon(Icons.label, size: 14, color: Colors.grey),
                        const SizedBox(width: 2),
                        Text(
                          issue.type!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  if (issue.status != null)
                    Row(
                      children: [
                        const Icon(Icons.flag, size: 14, color: Colors.grey),
                        const SizedBox(width: 2),
                        Text(
                          issue.status!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              // Second row: Summary
              if (issue.summary != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    issue.summary!,
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                    textAlign: TextAlign.left,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // Third row: Assignee and Reporter
              if (issue.assignee != null || issue.reporter != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      if (issue.assignee != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              issue.assignee!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                            if (issue.reporter != null)
                              const SizedBox(width: 12),
                          ],
                        ),
                      if (issue.reporter != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.newspaper,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              "${issue.reporter} (rep)",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void onTitlePressed() {
    jiraService.openIssue(issue.key);
  }

  Color getColorForType(String? type) {
    if (type == null) return Colors.white;

    switch (type.toLowerCase()) {
      case 'initiative':
        return Colors.yellow.shade100;
      case 'epic':
        return Colors.purple.shade100;
      case 'story':
        return Colors.green.shade100;
      case 'task':
        return Colors.blue.shade100;
      case 'bug':
        return Colors.red.shade100;
      case 'sub-task':
        return Colors.blueGrey.shade100;
      default:
        debugPrint('Unknown type: $type');
        return Colors.grey.shade100; // Default color for unknown statuses
    }
  }
}
