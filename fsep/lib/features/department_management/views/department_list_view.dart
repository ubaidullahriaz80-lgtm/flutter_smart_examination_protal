import 'package:flutter/material.dart';
import '../../../data/repositories/department_repository.dart';

class DepartmentListView extends StatefulWidget {
  const DepartmentListView({super.key});

  @override
  State<DepartmentListView> createState() => _DepartmentListViewState();
}

class _DepartmentListViewState extends State<DepartmentListView> {
  final DepartmentRepository _repository = DepartmentRepository();
  late Future<List<Map<String, dynamic>>> _departmentsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _departmentsFuture = _repository.getDepartments();
    });
  }

  Future<void> _showForm([Map<String, dynamic>? existing]) async {
    final nameController = TextEditingController(text: existing?['name'] ?? '');
    final codeController = TextEditingController(text: existing?['code'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Department' : 'Edit Department'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name (e.g. Computer Science)')),
            TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Code (e.g. CS)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (existing == null) {
                await _repository.createDepartment(name: nameController.text.trim(), code: codeController.text.trim());
              } else {
                await _repository.updateDepartment(id: existing['id'], name: nameController.text.trim(), code: codeController.text.trim());
              }
              if (mounted) Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Departments')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _departmentsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          final depts = snapshot.data ?? [];
          return ListView.builder(
            itemCount: depts.length,
            itemBuilder: (context, index) {
              final dept = depts[index];
              return ListTile(
                title: Text(dept['name']),
                subtitle: Text(dept['code']),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(dept)),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await _repository.deleteDepartment(dept['id']);
                        _refresh();
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
