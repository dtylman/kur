import 'package:flutter/material.dart';
import 'package:kur/add_project_dialog.dart';
import 'package:kur/config_service.dart';
import 'package:kur/project_view.dart';
import 'package:kur/projects_list.dart';
import 'package:kur/user_name_textbox.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  List<Project>? _projects;
  Project? _selectedProject;

  @override
  void initState() {
    super.initState();
    loadProjects();
  }

  @override
  Widget build(BuildContext context) {
    if (_projects == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      body: Column(
        children: [
          // Top panel
          buildTopPanel(),
          // Main content
          Expanded(
            child: Row(
              children: [
                buildLeftPanel(),
                const VerticalDivider(width: 1),
                Expanded(child: buildMainPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void loadProjects() {
    _projects = config.file!.projects;
  }

  void onProjectSelected(Project value) {
    debugPrint('Selected project: ${value.name}');
    setState(() {
      _selectedProject = value;
    });
  }

  Widget buildLeftPanel() {
    return SizedBox(
      width: 250,
      child: Column(
        children: [
          Expanded(
            child: ProjectsList(
              projects: _projects!,
              onProjectSelected: onProjectSelected,
              onProjectDeleted: onDeleteProject,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: onAddProject,
              child: const Text('Add Project'),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMainPanel() {
    return Center(
      child: _selectedProject == null
          ? const Text('Select a project')
          : ProjectView(
              key: ValueKey(_selectedProject!.id),
              projectID: _selectedProject!.id,
            ),
    );
  }

  void onAddProject() {
    showDialog(
      context: context,
      builder: (context) {
        return AddProjectDialog(onProjectAdded: onProjectAdded);
      },
    );
  }

  Future<void> onProjectAdded(Project project) async {
    _projects = await config.addProject(project);
    setState(() {
      _selectedProject = project;
    });
    Navigator.of(context).pop();
  }

  void onDeleteProject(Project project) async {
    _projects = await config.deleteProject(project.id);
    setState(() {
      if (_selectedProject?.id == project.id) {
        _selectedProject = null;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Project "${project.name}" deleted')),
    );
  }

  Widget buildTopPanel() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Program name on the left
          const Text(
            'Kur',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          UserNameTextbox(),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),
        ],
      ),
    );
  }
}
