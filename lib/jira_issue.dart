import 'package:atlassian_apis/jira_platform.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kur/config_service.dart';

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
  DateTime? created;

  List<String> labels = [];

  Map<String, JiraIssueLink> inLinks = {}; // key -> JiraIssueLink
  Map<String, JiraIssueLink> outLinks = {}; // key -> JiraIssueLink

  JiraIssue({required this.id, required this.key});

  Duration? get age => getAge();

  static JiraIssue fromBean(IssueBean issue) {
    var jiraIssue = JiraIssue(id: issue.id ?? '', key: issue.key ?? '');
    jiraIssue.summary = issue.fields?['summary'] as String?;
    jiraIssue.assignee = issue.fields?['assignee']?['displayName'] as String?;
    jiraIssue.parent = issue.fields?['parent']?['key'] as String?;
    jiraIssue.type = issue.fields?['issuetype']?['name'] as String?;
    jiraIssue.status = issue.fields?['status']?['name'] as String?;
    jiraIssue.reporter = issue.fields?['reporter']?['displayName'] as String?;
    jiraIssue.labels = List<String>.from(issue.fields?['labels'] ?? []);

    //Jira time format is 2024-02-14T13:44:14.603+0200
    var createdStr = issue.fields?['created'];
    if (createdStr != null) {
      // Use DateFormat to parse Jira's date format
      var jiraDateFormat = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSZ");
      jiraIssue.created = jiraDateFormat.parse(createdStr);
    }

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
    if (!validLink(jiraIssueLink,'out')) { 
      return;
    }
    outLinks[jiraIssueLink.key] = jiraIssueLink;
  }

  void addInLink(JiraIssueLink jiraIssueLink) {
      if (!validLink(jiraIssueLink,'in')) { 
      return;
    }
    inLinks[jiraIssueLink.key] = jiraIssueLink;
  }

  Duration? getAge() {
    if (created == null) return null;
    return DateTime.now().difference(created!);
  }
  
  bool validLink(JiraIssueLink jiraIssueLink, String category) {
   
    
    String name = jiraIssueLink.name.toLowerCase();    
    List<String>? items = config.file!.validLinks[name];
    if (items!=null && items.contains(category)) {
      return true;      
    }    
    debugPrint('**** link ignored : "$name" for category: $category');
    return false;
  }
}
