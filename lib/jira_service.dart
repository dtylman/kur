import 'dart:io';

import 'package:atlassian_apis/jira_platform.dart';
import 'package:flutter/material.dart';
import 'package:kur/config_service.dart';
import 'package:lru_cache/lru_cache.dart';

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

  Map<String, JiraIssueLink> inLink = {}; // key -> JiraIssueLink
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
    inLink[jiraIssueLink.key] = jiraIssueLink;
  }
}

/// JiraClient is a wrapper around the Atlassian Jira API client
class JiraClient {
  late ApiClient client;
  late JiraPlatformApi jira;

  JiraClient() {
    var user = config.file!.jiraUser;
    var apiToken = config.file!.apiKey;
    var jiraUrl = config.file!.jiraUrl;
    client = ApiClient.basicAuthentication(
      Uri.https(jiraUrl, ''),
      user: user,
      apiToken: apiToken,
    );

    jira = JiraPlatformApi(client);
    //   var currentUser = await jira!.myself.getCurrentUser();
    // print('Current User: ${currentUser.displayName}');
  }

  void close() {
    client.close();
  }
}

// JiraService is a service class to interact with Jira issues
class JiraService {
  final LruCache issueBeanCache = LruCache<String, IssueBean>(500);
  final LruCache searchResultsCache = LruCache<String, SearchResults>(500);

  // get an issue bean by its ID or key
  Future<IssueBean> getIssueBean(String issueIdOrKey) async {
    debugPrint('getting issue bean with id or key: $issueIdOrKey');
    var response = await issueBeanCache.get(issueIdOrKey);
    if (response != null) {
      debugPrint('Issue bean found in cache for: $issueIdOrKey');
      return response;
    }

    JiraClient client = JiraClient();
    try {
      IssueBean response = await client.jira.issues.getIssue(
        issueIdOrKey: issueIdOrKey,
      );
      issueBeanCache.put(issueIdOrKey, response);
      return response;
    } finally {
      client.close();
    }
  }

  // get search results using JQL
  Future<SearchResults> getSearchResults(
    String jql,
    int size,
    int offset,
  ) async {
    debugPrint('getting search results with JQL: $jql');

    var response = await searchResultsCache.get(jql);
    if (response != null) {
      debugPrint('Search results found in cache for: $jql');
      return response;
    }

    JiraClient client = JiraClient();
    try {
      SearchResults response = await client.jira.issueSearch
          .searchForIssuesUsingJql(jql: jql, maxResults: size, startAt: offset);
      searchResultsCache.put(jql, response);
      return response;
    } finally {
      client.close();
    }
  }

  // get an issue by its ID or key
  Future<JiraIssue> getIssue(
    String issueIdOrKey,
    bool searchForChildIssues,
  ) async {
    debugPrint('getting issue with id or key: $issueIdOrKey');
    IssueBean response = await getIssueBean(issueIdOrKey);
    JiraIssue issue = JiraIssue.fromBean(response);

    if (searchForChildIssues) {
      String jql =
          '"Parent Link" IN ($issueIdOrKey) OR parent IN ($issueIdOrKey)';
      List<JiraIssue> childIssues = await getIssues(jql);
      for (var childIssue in childIssues) {
        if (childIssue.key != issue.key) {
          issue.addOutLink(
            JiraIssueLink(
              id: childIssue.id,
              name: 'Child',
              key: childIssue.key,
            ),
          );
        }
      }
    }

    return issue;
  }

  // Fetch issues using JQL
  Future<List<JiraIssue>> getIssues(String jql) async {
    debugPrint('getting issues with JQL: $jql');

    List<JiraIssue> list = [];
    int size = 100;
    SearchResults response = await getSearchResults(jql, size, 0);

    do {
      for (var issue in response.issues) {
        list.add(JiraIssue.fromBean(issue));
      }
      if (response.startAt! + response.maxResults! >= response.total!) {
        break; // No more issues to fetch
      }
      int offset = response.startAt! + response.maxResults!;
      response = await getSearchResults(jql, offset, size);
    } while (response.startAt! + response.maxResults! < response.total!);

    return list;
  }

  void openIssue(String key) {
    debugPrint('Opening issue in browser: $key');
    String jiraUrl = config.file!.jiraUrl;
    String url = 'https://$jiraUrl/browse/$key';
    
    if (Platform.isMacOS) {
      Process.run('open', [url]);
    } else if (Platform.isWindows) {
      Process.run('start', [url], runInShell: true);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [url]);
    }
  }
}

JiraService jiraService = JiraService();
