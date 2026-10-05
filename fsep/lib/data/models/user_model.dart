enum UserRole {
  systemAdministrator,
  institutionalAdministrator,
  examiner,
  liveInvigilator,
  candidate;

  static UserRole fromApiValue(String value) {
    switch (value) {
      case 'system_administrator':
        return UserRole.systemAdministrator;
      case 'institutional_administrator':
        return UserRole.institutionalAdministrator;
      case 'examiner':
        return UserRole.examiner;
      case 'live_invigilator':
        return UserRole.liveInvigilator;
      case 'candidate':
        return UserRole.candidate;
      default:
        throw ArgumentError('Unknown role from API: $value');
    }
  }

  String get apiValue => switch (this) {
        UserRole.systemAdministrator => 'system_administrator',
        UserRole.institutionalAdministrator => 'institutional_administrator',
        UserRole.examiner => 'examiner',
        UserRole.liveInvigilator => 'live_invigilator',
        UserRole.candidate => 'candidate',
      };

  String get displayName => switch (this) {
        UserRole.systemAdministrator => 'System Administrator',
        UserRole.institutionalAdministrator => 'Institutional Administrator',
        UserRole.examiner => 'Examiner',
        UserRole.liveInvigilator => 'Live Invigilator',
        UserRole.candidate => 'Candidate',
      };
}

class UserModel {
  const UserModel({required this.id, required this.role});

  final String id;
  final UserRole role;
}
