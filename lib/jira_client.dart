import 'package:atlassian_apis/jira_platform.dart';
import 'package:kur/config_service.dart';

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
