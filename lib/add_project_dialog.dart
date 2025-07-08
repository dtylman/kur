import 'package:flutter/material.dart';
import 'package:kur/config_service.dart';

class AddProjectDialog extends StatelessWidget {
  final Function(Project) onProjectAdded;

  const AddProjectDialog({super.key, required this.onProjectAdded});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Project'),
      content: buildAddProjectForm(context),      
    );
  }
  
  Widget buildAddProjectForm(BuildContext context) {
    final TextEditingController nameController = TextEditingController();    

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Project Name'),
        ),        
        ElevatedButton(
          onPressed: () {
            final projectID = Project.getID(nameController.text);
            final project = Project(name: nameController.text, id: projectID);
            onProjectAdded(project);
          },
          child: const Text('Add Project'),
        ),
      ],
    );
  }
}