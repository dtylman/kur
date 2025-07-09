import 'package:flutter/material.dart';
import 'package:kur/jira_service.dart';

class UserNameTextbox extends StatefulWidget {
  const UserNameTextbox({super.key});

  @override
  UserNameTextboxState createState() => UserNameTextboxState();
}

class UserNameTextboxState extends State<UserNameTextbox> {
  String userName = "Not Logged In";
  @override
  void initState() {
    super.initState();
    // Initialize any necessary state here
    loadUserName();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.person, color: Theme.of(context).colorScheme.onSurface),
        SizedBox(width: 8),
        Text(
          userName,
          style: TextStyle(
            fontSize: 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  void loadUserName() async {
    try {
      var user = await jiraService.getCurrentUser();
      setState(() {
        userName = user;
      });
    } catch (e) {
      debugPrint('Error loading user name: $e');
      setState(() {
        userName = "Error loading user";
      });
    }
  }
}
