import 'package:atlassian_apis/jira_platform.dart';

class JiraIssueLink {
  final String id;
  final String name;
  final String key;
  JiraIssueLink({required this.id, required this.name, required this.key});
}

class JiraIssue {
  final String id;
  final String key;

  String? summary;
  String? assignee;
  String? parent;
  String? type;
  String? status;
  String? reporter;

  List<String> labels = [];

  Map<String, JiraIssueLink> inLinks = {}; // key -> JiraIssueLink
  Map<String, JiraIssueLink> outLinks = {}; // key -> JiraIssueLink

  JiraIssue({required this.id, required this.key});

  static JiraIssue fromBean(IssueBean issue) {
    var jiraIssue = JiraIssue(id: issue.id ?? '', key: issue.key ?? '');
    jiraIssue.summary = issue.fields?['summary'] as String?;
    jiraIssue.assignee = issue.fields?['assignee']?['displayName'] as String?;
    jiraIssue.parent = issue.fields?['parent']?['key'] as String?;
    jiraIssue.type = issue.fields?['issuetype']?['name'] as String?;
    jiraIssue.status = issue.fields?['status']?['name'] as String?;
    jiraIssue.reporter = issue.fields?['reporter']?['displayName'] as String?;
    jiraIssue.labels = List<String>.from(issue.fields?['labels'] ?? []);

    var issueLinks = issue.fields?['issuelinks'] as List<dynamic>?;
    if (issueLinks != null) {
      for (var link in issueLinks) {
        var type = link['type']?['name'] as String?;
        var outward = link['outwardIssue'];
        var inward = link['inwardIssue'];

        if (outward != null) {
          jiraIssue.addOutLink(
            JiraIssueLink(
              id: outward['id'] ?? '',
              name: type ?? '',
              key: outward['key'] ?? '',
            ),
          );
        }
        if (inward != null) {
          jiraIssue.addInLink(
            JiraIssueLink(
              id: inward['id'] ?? '',
              name: type ?? '',
              key: inward['key'] ?? '',
            ),
          );
        }
      }
    }

    var subtasks = issue.fields?['subtasks'] as List<dynamic>?;
    if (subtasks != null) {
      for (var subtask in subtasks) {
        jiraIssue.addOutLink(
          JiraIssueLink(
            id: subtask['id'] ?? '',
            name: 'Subtask',
            key: subtask['key'] ?? '',
          ),
        );
      }
    }

    return jiraIssue;
  }

  void addOutLink(JiraIssueLink jiraIssueLink) {
    outLinks[jiraIssueLink.key] = jiraIssueLink;
  }

  void addInLink(JiraIssueLink jiraIssueLink) {
    inLinks[jiraIssueLink.key] = jiraIssueLink;
  }
}
