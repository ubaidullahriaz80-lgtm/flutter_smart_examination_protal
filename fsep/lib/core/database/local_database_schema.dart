/// Local SQLite database table schema definitions.
class LocalDatabaseSchema {
  LocalDatabaseSchema._();

  static const int version = 11;

  static const String tableExams = 'local_exams';
  static const String tableQuestions = 'local_questions';
  static const String tableExamSessions = 'local_exam_sessions';
  static const String tableAnswers = 'local_answers';
  static const String tableBehaviorEvents = 'local_behavior_events';

  static const String createExamsTable = '''
    CREATE TABLE IF NOT EXISTS $tableExams (
      id INTEGER PRIMARY KEY,
      created_by INTEGER NOT NULL DEFAULT 0,
      title TEXT NOT NULL,
      description TEXT,
      course_code TEXT,
      duration_minutes INTEGER NOT NULL,
      total_marks REAL NOT NULL,
      negative_marking_weight REAL NOT NULL,
      pass_percentage REAL NOT NULL DEFAULT 50.0,
      status TEXT NOT NULL,
      bcd_enabled INTEGER NOT NULL DEFAULT 1,
      randomize_questions INTEGER NOT NULL DEFAULT 0,
      shuffle_choices INTEGER NOT NULL DEFAULT 0,
      is_offline_ready INTEGER NOT NULL DEFAULT 0,
      question_count INTEGER NOT NULL DEFAULT 0,
      cached_at TEXT NOT NULL
    )
  ''';

  static const String createQuestionsTable = '''
    CREATE TABLE IF NOT EXISTS $tableQuestions (
      id INTEGER PRIMARY KEY,
      exam_id INTEGER NOT NULL,
      question_text TEXT NOT NULL,
      question_type TEXT NOT NULL,
      marks REAL NOT NULL,
      difficulty TEXT,
      bloom_taxonomy TEXT,
      topic_tag TEXT,
      options TEXT,
      review_status TEXT,
      is_ai_generated INTEGER NOT NULL DEFAULT 0,
      sort_order INTEGER NOT NULL DEFAULT 0,
      cached_at TEXT NOT NULL,
      FOREIGN KEY (exam_id) REFERENCES $tableExams (id) ON DELETE CASCADE
    )
  ''';

  static const String createExamSessionsTable = '''
    CREATE TABLE IF NOT EXISTS $tableExamSessions (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      server_session_id INTEGER,
      exam_id INTEGER NOT NULL,
      status TEXT NOT NULL,
      started_at TEXT NOT NULL,
      expires_at TEXT,
      submitted_at TEXT,
      current_question_index INTEGER NOT NULL DEFAULT 0,
      server_clock_offset_ms INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (exam_id) REFERENCES $tableExams (id) ON DELETE CASCADE
    )
  ''';

  static const String createAnswersTable = '''
    CREATE TABLE IF NOT EXISTS $tableAnswers (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      session_local_id INTEGER,
      session_id INTEGER NOT NULL DEFAULT 0,
      question_id INTEGER NOT NULL,
      selected_option TEXT NOT NULL,
      sync_status TEXT NOT NULL DEFAULT 'pending',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      last_synced_at TEXT,
      server_answer_id INTEGER,
      conflict_code TEXT,
      FOREIGN KEY (session_local_id) REFERENCES $tableExamSessions (local_id) ON DELETE CASCADE
    )
  ''';

  static const String createAnswersSessionQuestionIndex = '''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_local_answers_session_question
    ON $tableAnswers (session_id, question_id)
  ''';

  static const String createBehaviorEventsTable = '''
    CREATE TABLE IF NOT EXISTS $tableBehaviorEvents (
      local_id INTEGER PRIMARY KEY AUTOINCREMENT,
      client_uuid TEXT NOT NULL,
      session_id INTEGER NOT NULL,
      event_type TEXT NOT NULL,
      metadata TEXT,
      created_at TEXT NOT NULL
    )
  ''';

  static const List<String> createStatements = [
    createExamsTable,
    createQuestionsTable,
    createExamSessionsTable,
    createAnswersTable,
    createAnswersSessionQuestionIndex,
    createBehaviorEventsTable,
  ];

  static const List<String> upgradeToV2 = [
    'ALTER TABLE $tableExams ADD COLUMN created_by INTEGER NOT NULL DEFAULT 0',
    'ALTER TABLE $tableExams ADD COLUMN question_count INTEGER NOT NULL DEFAULT 0',
    'ALTER TABLE $tableQuestions ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
  ];

  static const List<String> upgradeToV3 = [
    'ALTER TABLE $tableAnswers ADD COLUMN session_id INTEGER NOT NULL DEFAULT 0',
    createAnswersSessionQuestionIndex,
  ];

  static const List<String> upgradeToV4 = [
    'ALTER TABLE $tableAnswers ADD COLUMN conflict_code TEXT',
  ];

  static const List<String> upgradeToV5 = [
    'ALTER TABLE $tableExamSessions ADD COLUMN current_question_index INTEGER NOT NULL DEFAULT 0',
    'ALTER TABLE $tableExamSessions ADD COLUMN server_clock_offset_ms INTEGER NOT NULL DEFAULT 0',
  ];

  static const List<String> upgradeToV6 = [
    createBehaviorEventsTable,
  ];

  static const List<String> upgradeToV7 = [
    'ALTER TABLE $tableBehaviorEvents ADD COLUMN client_uuid TEXT',
  ];

  static const List<String> upgradeToV8 = [
    'ALTER TABLE $tableExams ADD COLUMN bcd_enabled INTEGER NOT NULL DEFAULT 1',
  ];

  static const List<String> upgradeToV9 = [
    'ALTER TABLE $tableExams ADD COLUMN randomize_questions INTEGER NOT NULL DEFAULT 0',
    'ALTER TABLE $tableExams ADD COLUMN shuffle_choices INTEGER NOT NULL DEFAULT 0',
  ];

  static const List<String> upgradeToV10 = [
    'ALTER TABLE $tableExams ADD COLUMN is_offline_ready INTEGER NOT NULL DEFAULT 0',
  ];

  static const List<String> upgradeToV11 = [
    'ALTER TABLE $tableExams ADD COLUMN pass_percentage REAL NOT NULL DEFAULT 50.0',
  ];
}
