import 'dart:io';

import 'package:atlassian_apis/jira_platform.dart';
import 'package:flutter/material.dart';
import 'package:kur/config_service.dart';
import 'package:kur/jira_client.dart';
import 'package:kur/jira_issue.dart';
import 'package:kur/temp_files_cache.dart';

// JiraService is a service class to interact with Jira issues
class JiraService {
  final TempFilesCache issueBeanCache = TempFilesCache(maxAge: Duration(days: 7),name: "issueBeanCache");
  final TempFilesCache searchResultsCache = TempFilesCache(maxAge: Duration(days: 7),name: "searchResultsCache");

  // get an issue bean by its ID or key
  Future<IssueBean> getIssueBean(String issueIdOrKey) async {
    debugPrint('getting issue bean with id or key: $issueIdOrKey');
    var response = await issueBeanCache.get(issueIdOrKey);
    if (response != null) {
      debugPrint('Issue bean found in cache for: $issueIdOrKey');
      return IssueBean.fromJson(response);
    }

    JiraClient client = JiraClient();
    try {
      IssueBean response = await client.jira.issues.getIssue(
        issueIdOrKey: issueIdOrKey,
      );
      issueBeanCache.put(issueIdOrKey, response.toJson());
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
      return SearchResults.fromJson(response);
    }

    JiraClient client = JiraClient();
    try {
      SearchResults response = await client.jira.issueSearch
          .searchForIssuesUsingJql(jql: jql, maxResults: size, startAt: offset);                
      response.toJson();
      searchResultsCache.put(jql, response.toJson());
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

  Future<void> clearCachedItems(Iterable<JiraIssue> values) async {
    debugPrint('Clearing cached items for issues: ${values.map((e) => e.key).join(', ')}');
    for (var issue in values) {
      await issueBeanCache.remove(issue.key);
      debugPrint('Removed issue bean from cache: ${issue.key}');
    }
    // await searchResultsCache.clear();
    // debugPrint('Cleared search results cache');
  }
}

JiraService jiraService = JiraService();
