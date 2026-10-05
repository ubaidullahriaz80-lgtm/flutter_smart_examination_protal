import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/csv_import_result.dart';
import '../../../data/repositories/user_management_repository.dart';
import '../../../core/utils/responsive.dart';

class CsvImportView extends StatefulWidget {
  const CsvImportView({super.key});

  @override
  State<CsvImportView> createState() => _CsvImportViewState();
}

class _CsvImportViewState extends State<CsvImportView> {
  final UserManagementRepository _repository = UserManagementRepository();

  Uint8List? _selectedBytes;
  String? _selectedFileName;
  int? _selectedDepartmentId;
  int? _selectedSemester;
  bool _importing = false;
  String? _pickError;
  String? _importError;
  CsvImportResult? _result;

  late Future<List<Map<String, dynamic>>> _departmentsFuture;

  @override
  void initState() {
    super.initState();
    _departmentsFuture = _fetchDepartments();
  }

  Future<List<Map<String, dynamic>>> _fetchDepartments() async {
    final response = await ApiClient.instance.get<Map<String, dynamic>>('/departments');
    if (response.data != null && response.data!['departments'] is List) {
      return List<Map<String, dynamic>>.from(response.data!['departments']);
    }
    return [];
  }

  Future<void> _pickFile() async {
    setState(() => _pickError = null);

    final List<PlatformFile> picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (picked.isEmpty) return;

    final PlatformFile file = picked.first;
    
    try {
      final Uint8List bytes = await file.readAsBytes();
      setState(() {
        _selectedBytes = bytes;
        _selectedFileName = file.name;
        _result = null;
        _importError = null;
      });
    } catch (e) {
      setState(() => _pickError = 'Could not read file content. Please try again.');
    }
  }

  Future<void> _import() async {
    final bytes = _selectedBytes;
    final fileName = _selectedFileName;
    if (bytes == null || fileName == null || _importing) return;

    setState(() {
      _importing = true;
      _importError = null;
    });

    try {
      final result = await _repository.importUsersCsv(
        bytes: bytes,
        fileName: fileName,
        departmentId: _selectedDepartmentId,
        semester: _selectedSemester,
      );
      if (!mounted) return;
      setState(() => _result = result);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _importError = error.message);
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Users (CSV)'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.isMobile ? double.infinity : context.screenWidth * 0.5,
                minWidth: context.isMobile ? double.infinity : 480,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CSV columns required: name, email, password, role',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Optional columns: department_code (e.g. CS), semester (1-8)',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                          ),
                          const Divider(height: 32),
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: _departmentsFuture,
                            builder: (context, snapshot) {
                              final depts = snapshot.data ?? [];
                              return DropdownButtonFormField<int>(
                                initialValue: _selectedDepartmentId,
                                decoration: const InputDecoration(
                                  labelText: 'Default Department',
                                  helperText: 'Applies to all users in CSV if department_code column is missing.',
                                ),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('No Department')),
                                  for (final dept in depts)
                                    DropdownMenuItem(
                                      value: dept['id'] as int,
                                      child: Text(dept['name'] as String),
                                    ),
                                ],
                                onChanged: (val) => setState(() => _selectedDepartmentId = val),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedSemester,
                            decoration: const InputDecoration(
                              labelText: 'Default Semester',
                              helperText: 'Applies to all users in CSV if semester column is missing.',
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('N/A')),
                              for (var i = 1; i <= 8; i++)
                                DropdownMenuItem(value: i, child: Text('Semester $i')),
                            ],
                            onChanged: (val) => setState(() => _selectedSemester = val),
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: _importing ? null : _pickFile,
                            icon: const Icon(Icons.upload_file_outlined),
                            label: Text(
                              _selectedFileName ?? 'Select CSV File',
                            ),
                          ),
                          if (_pickError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _pickError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: (_selectedBytes == null || _importing)
                                ? null
                                : _import,
                            icon: _importing
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.group_add_outlined),
                            label: Text(_importing ? 'Importing...' : 'Import'),
                          ),
                          if (_importError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _importError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (result != null) ...[
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Successfully imported: ${result.importedCount}',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: result.failedCount > 0
                                      ? Theme.of(context).colorScheme.error
                                      : null,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Failed: ${result.failedCount}',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ],
                            ),
                            if (result.errors.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Errors',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 4),
                              for (final error in result.errors)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Row ${error.row}: ${error.message}',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                            ],
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () =>
                                  Navigator.of(context).pop(result.importedCount > 0),
                              child: const Text('Done'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
