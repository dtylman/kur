import 'package:flutter/material.dart';
import 'package:kur/config_service.dart';

class ProjectsList extends StatefulWidget {
  final List<Project> projects;
  final ValueChanged<Project> onProjectSelected;
  final ValueChanged<Project>? onProjectDeleted;

  const ProjectsList({
    super.key,
    required this.projects,
    required this.onProjectSelected,
    this.onProjectDeleted,
  });

  @override
  ProjectsListState createState() => ProjectsListState();
}

class ProjectsListState extends State<ProjectsList> {
  Project? _selectedProject;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.projects.length,
      itemBuilder: (context, index) {
        final project = widget.projects[index];
        final isSelected = _selectedProject?.id == project.id;
        return ListTile(
          title: Text(project.name),
          subtitle: Text(project.id),
          selected: isSelected,
          onTap: () {
            setState(() {
              _selectedProject = project;
            });
            widget.onProjectSelected(project);
          },
          trailing: IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              if (widget.onProjectDeleted != null) {
                widget.onProjectDeleted!(project);
              }              
            },
          ),
        );
      },
    );
  }
}