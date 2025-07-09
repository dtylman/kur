import 'package:flutter/material.dart';
import 'config_service.dart';

class ConfigDialog extends StatefulWidget {
  const ConfigDialog({super.key});

  @override
  State<ConfigDialog> createState() => ConfigDialogState();
}

class ConfigDialogState extends State<ConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController urlController;
  late TextEditingController userController;
  late TextEditingController apiKeyController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    urlController = TextEditingController(text: config.file?.jiraUrl ?? '');
    userController = TextEditingController(text: config.file?.jiraUser ?? '');
    apiKeyController = TextEditingController(text: config.file?.apiKey ?? '');
  }

  @override
  void dispose() {
    urlController.dispose();
    userController.dispose();
    apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    config.file = ConfigFile(
      jiraUrl: urlController.text.trim(),
      jiraUser: userController.text.trim(),
      apiKey: apiKeyController.text.trim(),
      projects: config.file?.projects ?? [],
    );
    await config.file!.save();
    setState(() => _saving = false);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configure Jira Connection'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'Jira URL'),
                validator: (v) => v == null || v.isEmpty ? 'Enter Jira URL' : null,
              ),
              TextFormField(
                controller: userController,
                decoration: const InputDecoration(labelText: 'User Name'),
                validator: (v) => v == null || v.isEmpty ? 'Enter user name' : null,
              ),
              TextFormField(
                controller: apiKeyController,
                decoration: const InputDecoration(labelText: 'API Key'),
                obscureText: true,
                validator: (v) => v == null || v.isEmpty ? 'Enter API key' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}
