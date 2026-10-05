import 'managed_user_model.dart';

/// One row that failed CSV import validation.
class CsvImportError {
  const CsvImportError({required this.row, required this.message});

  final int row;
  final String message;

  factory CsvImportError.fromJson(Map<String, dynamic> json) {
    return CsvImportError(
      row: json['row'] as int,
      message: json['message'] as String,
    );
  }
}

/// Result of POST /users/import — the CSV bulk user import.
class CsvImportResult {
  const CsvImportResult({
    required this.importedCount,
    required this.failedCount,
    required this.imported,
    required this.errors,
  });

  final int importedCount;
  final int failedCount;
  final List<ManagedUserModel> imported;
  final List<CsvImportError> errors;

  factory CsvImportResult.fromJson(Map<String, dynamic> json) {
    return CsvImportResult(
      importedCount: json['imported_count'] as int,
      failedCount: json['failed_count'] as int,
      imported: (json['imported'] as List<dynamic>)
          .map((e) => ManagedUserModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      errors: (json['errors'] as List<dynamic>)
          .map((e) => CsvImportError.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
