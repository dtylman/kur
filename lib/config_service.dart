import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

class Project {
  final String name;
  final String id;
  final List<String> issues = [];
  Project({required this.name, required this.id});

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(name: json['name'] as String, id: json['id'] as String)
      ..issues.addAll(List<String>.from(json['issues'] ?? []));
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'id': id, 'issues': issues};
  }

  static String getID(String name) {
    return name.toLowerCase().replaceAll(' ', '_');
  }
}

class ConfigFile {
  final String jiraUrl;
  final String jiraUser;
  final String apiKey;
  final List<Project> projects;

  Map<String, List<String>> validLinks;

  ConfigFile({
    required this.jiraUrl,
    required this.jiraUser,
    required this.apiKey,
    required this.projects,
    this.validLinks = const {
      "blocks": ["in", "out"],
    },
  });

  static String get configFilePath {
    final homeDir =
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '.';
    return '$homeDir/.kur_config.json';
  }

  static Future<ConfigFile> load() async {
    debugPrint('Loading config from $configFilePath');

    final file = File(configFilePath);
    if (!await file.exists()) {
      throw Exception('Configuration file not found at $configFilePath');
    }
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return ConfigFile.fromJson(json);
  }

  Future<void> save() async {
    debugPrint('Saving config to $configFilePath');
    final file = File(configFilePath);
    await file.create(recursive: true);
    final content = jsonEncode(toJson());
    await file.writeAsString(content);
  }

  factory ConfigFile.fromJson(Map<String, dynamic> json) {
    return ConfigFile(
      jiraUrl: json['jiraUrl'] as String,
      jiraUser: json['jiraUser'] as String? ?? '',
      apiKey: json['apiKey'] as String,
      projects: (json['projects'] as List<dynamic>)
          .map((project) => Project.fromJson(project as Map<String, dynamic>))
          .toList(),
      validLinks:
          (json['validLinks'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<String>.from(value as List)),
          ) ??
          {
            "blocks": ["in", "out"],
          },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'jiraUrl': jiraUrl,
      'jiraUser': jiraUser,
      'apiKey': apiKey,
      'projects': projects.map((p) => p.toJson()).toList(),
      'validLinks': validLinks,
    };
  }
}

class ConfigService {
  ConfigFile? file;

  Future<void> initialize() async {
    try {
      file = await ConfigFile.load();
      debugPrint('Config loaded successfully');
    } catch (e) {
      debugPrint('Error loading config: $e');
      file = ConfigFile(jiraUrl: '', jiraUser: '', apiKey: '', projects: []);
    }
  }

  Future<List<Project>> addProject(Project project) async {
    file!.projects.add(project);
    await file!.save();
    return file!.projects;
  }

  Future<List<Project>> deleteProject(String id) async {
    file!.projects.removeWhere((project) => project.id == id);
    await file!.save();
    return file!.projects;
  }

  Project? getProject(String projectID) {
    return file!.projects.firstWhere((project) => project.id == projectID);
  }

  Future<void> saveProject(Project project) async {
    debugPrint('Saving project: ${project.name} (${project.id})');
    final index = file!.projects.indexWhere((p) => p.id == project.id);
    if (index != -1) {
      file!.projects[index] = project;
    } else {
      file!.projects.add(project);
    }
    await file!.save();
  }
}

ConfigService config = ConfigService();
