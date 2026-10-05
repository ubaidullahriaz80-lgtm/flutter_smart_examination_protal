import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/models/managed_user_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/user_management_repository.dart';
import '../../../core/utils/responsive.dart';

/// Create/edit form for the System Administrator's User Management module.
///
/// `existingUser == null` means create mode; otherwise edit mode.
class UserFormView extends StatefulWidget {
  const UserFormView({super.key, this.existingUser});

  final ManagedUserModel? existingUser;

  bool get isEditing => existingUser != null;

  @override
  State<UserFormView> createState() => _UserFormViewState();
}

class _UserFormViewState extends State<UserFormView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();

  final UserManagementRepository _repository = UserManagementRepository();

  late UserRole _selectedRole;
  int? _selectedDepartmentId;
  int? _selectedSemester;
  bool _submitting = false;

  late Future<List<Map<String, dynamic>>> _departmentsFuture;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingUser;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _emailController = TextEditingController(text: existing?.email ?? '');
    _selectedRole = existing?.role ?? UserRole.candidate;
    _selectedDepartmentId = existing?.departmentId;
    _selectedSemester = existing?.semester;

    _departmentsFuture = _fetchDepartments();
  }

  Future<List<Map<String, dynamic>>> _fetchDepartments() async {
    final response = await ApiClient.instance.get<Map<String, dynamic>>('/departments');
    if (response.data != null && response.data!['departments'] is List) {
      return List<Map<String, dynamic>>.from(response.data!['departments']);
    }
    return [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);

    try {
      if (widget.isEditing) {
        await _repository.updateUser(
          id: widget.existingUser!.id,
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          role: _selectedRole,
          departmentId: _selectedDepartmentId,
          semester: _selectedSemester,
        );
      } else {
        await _repository.createUser(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          role: _selectedRole,
          departmentId: _selectedDepartmentId,
          semester: _selectedSemester,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_describeError(error))));
    }
  }

  String _describeError(ApiException error) {
    final fieldErrors = error.errors;
    if (fieldErrors != null && fieldErrors.isNotEmpty) {
      return fieldErrors.values.expand((messages) => messages).join('\n');
    }
    return error.message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit User' : 'Add User'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: context.isMobile ? double.infinity : context.screenWidth * 0.5,
                minWidth: context.isMobile ? double.infinity : 400,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!value.contains('@')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    if (!widget.isEditing) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration:
                            const InputDecoration(labelText: 'Password'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          if (value.length < 8) {
                            return 'Password must be at least 8 characters';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    DropdownButtonFormField<UserRole>(
                      initialValue: _selectedRole,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: [
                        for (final role in UserRole.values)
                          DropdownMenuItem(
                            value: role,
                            child: Text(
                              role.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedRole = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _departmentsFuture,
                      builder: (context, snapshot) {
                        final depts = snapshot.data ?? [];
                        return DropdownButtonFormField<int>(
                          initialValue: _selectedDepartmentId,
                          decoration: const InputDecoration(labelText: 'Department'),
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
                    if (_selectedRole == UserRole.candidate) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedSemester,
                        decoration: const InputDecoration(labelText: 'Semester'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('N/A')),
                          for (var i = 1; i <= 8; i++)
                            DropdownMenuItem(value: i, child: Text('Semester $i')),
                        ],
                        onChanged: (val) => setState(() => _selectedSemester = val),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              widget.isEditing ? 'Save Changes' : 'Create User',
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
