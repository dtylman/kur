import 'package:flutter/material.dart';
import 'package:kur/jira_issue.dart';
import 'package:kur/jira_service.dart';
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
  Map<String, JiraIssue> issues = {};

  // Add state for filter and showClosed
  String filterText = '';
  bool showClosed = false;

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
      return Center(
        child: Text(
          'No issues found in this project',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }
    if (!loaded) {
      return Center(child: graphLoader);
    }

    // Filter and sort issues
    var filteredIssues = issues.values.where((issue) {
      final matchesFilter =
          filterText.isEmpty ||
          (issue.summary?.toLowerCase().contains(filterText.toLowerCase()) ??
              false) ||
          (issue.key.toLowerCase().contains(filterText.toLowerCase()));
      final isClosed = (issue.status?.toLowerCase() == 'closed');
      return matchesFilter && (showClosed || !isClosed);
    }).toList();
    filteredIssues.sort(tableRowSorter);

    return Column(
      children: [
        // Commands pane
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Checkbox(
                value: showClosed,
                onChanged: (val) {
                  setState(() {
                    showClosed = val ?? false;
                  });
                },
              ),
              const Text('Show Closed'),
              const SizedBox(width: 24),
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Filter by key or summary',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (val) {
                    setState(() {
                      filterText = val;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Key')),
                DataColumn(
                  label: Text('Summary'),
                  columnWidth: FixedColumnWidth(300),
                ),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Assignee')),
                DataColumn(label: Text('Reporter')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Created')),
                DataColumn(label: Text('Fix Versions')),
                DataColumn(label: Text('Labels')),
              ],
              rows: filteredIssues.map((issue) {
                return DataRow(
                  cells: [
                    DataCell(
                      TextButton(
                        onPressed: () {
                          onIssuePressed(issue);
                        },
                        child: Text(issue.key),
                      ),
                    ),
                    DataCell(Text(issue.summary ?? '')),
                    DataCell(Text(issue.status ?? '')),
                    DataCell(Text(issue.assignee ?? '')),
                    DataCell(Text(issue.reporter ?? '')),
                    DataCell(Text(issue.type ?? '')),
                    DataCell(Text('${humanizeTimeAgo(issue.age)} ago')),
                    DataCell(buildBubbles(issue.fixVersions)),
                    DataCell(buildBubbles(issue.labels)),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  void onGraphLoaded(GraphLoadedEventArgs args) {
    setState(() {
      issues = args.issues;
      loaded = true;
    });
  }

  int tableRowSorter(JiraIssue a, JiraIssue b) {
    int statusCompare = (a.status ?? '').compareTo(b.status ?? '');
    if (statusCompare != 0) return statusCompare;
    int typeCompare = (a.type ?? '').compareTo(b.type ?? '');
    if (typeCompare != 0) return typeCompare;

    // Sort by created date, most recent first
    if (a.created != null && b.created != null) {
      return b.created!.compareTo(a.created!);
    } else if (a.created != null) {
      return -1; // a is more recent
    } else if (b.created != null) {
      return 1; // b is more recent
    }

    return typeCompare;
  }

  String humanizeTimeAgo(Duration? age) {
    if (age == null) return 'N/A';
    var res = '';
    int years = age.inDays ~/ 365;
    if (years > 0) {
      int month = (age.inDays % 365) ~/ 30;
      return '$years year${years > 1 ? 's' : ''} ${month > 0 ? '$month month${month > 1 ? 's' : ''}' : ''}';
    }
    int months = age.inDays ~/ 30;
    if (months > 0) {
      res += '$months month${months > 1 ? 's' : ''} ';
      return res.trim(); // Return early if we have months
    }
    int days = age.inDays % 30;
    if (days > 0) {
      res += '$days day${days > 1 ? 's' : ''} ';
      return res.trim(); // Return early if we have days
    }
    int hours = age.inHours % 24;
    if (hours > 0) {
      res += '$hours hour${hours > 1 ? 's' : ''} ';
      return res.trim(); // Return early if we have hours
    }
    int minutes = age.inMinutes % 60;
    if (minutes > 0) {
      res += '$minutes minute${minutes > 1 ? 's' : ''} ';
      return res.trim(); // Return early if we have minutes
    }
    int seconds = age.inSeconds % 60;
    if (seconds > 0) {
      res += '$seconds second${seconds > 1 ? 's' : ''} ';
    }
    return res.trim().isEmpty ? 'Just now' : res.trim();
  }

  void onIssuePressed(JiraIssue issue) {
    jiraService.openIssue(issue.key);
  }

  Widget buildBubbles(List<String> items) {
    // Calculate trimSize based on available space
    int trimSize = 10; // Default value
    final double maxWidth = MediaQuery.of(context).size.width;
    // Estimate: allow ~60px per chip, minus padding, for up to 8 chips per row
    if (items.isNotEmpty) {
      int maxChipsPerRow = (maxWidth / 60).floor();
      // Adjust trimSize so all chips fit in a row, min 3 chars
      trimSize = ((maxWidth / (items.length > maxChipsPerRow ? maxChipsPerRow : items.length)) / 8).floor();
      if (trimSize < 3) trimSize = 3;
      if (trimSize > 15) trimSize = 15;
    }
    return Tooltip(
      message: items.join(', '),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: items.map((item) {          
            return Chip(
            backgroundColor: colorForString(item),
            label: Text(
              item.length > trimSize ? item.substring(0, trimSize) : item,
              style: const TextStyle(fontSize: 10),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
            labelPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
            // You can also reduce the side and shape if needed:
            // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            );
        }).toList(),
      ),
    );
  }

  // Ensure generated colors are bright for black text visibility
  Color colorForString(String input) {
    final hash = input.codeUnits.fold(0, (prev, elem) => prev + elem);
    // Generate RGB values in the upper range for brightness
    final r = 180 + (hash * 123) % 75; // 180..254
    final g = 180 + (hash * 456) % 75;
    final b = 180 + (hash * 789) % 75;
    return Color.fromARGB(255, r, g, b);
  }
}
