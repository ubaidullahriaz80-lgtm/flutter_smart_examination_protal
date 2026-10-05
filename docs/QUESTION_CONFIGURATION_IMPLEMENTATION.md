# FSEP — Multi-Question-Type Exam Configuration Implementation

## 1. Overview
The **Exam-Level Multi-Question-Type Configuration System** allows teachers to define a blueprint for their exams before authoring or generating specific questions. This blueprint serves as an optional template for the AI Question Generator and a summary guide for manual creation.

## 2. Database Changes
A new table `exam_question_configurations` was added to store the blueprints.
- `exam_id`: Foreign key to `exams`.
- `question_type`: Enum (`mcq`, `true_false`, `short_answer`, `essay`, `matching`, `code_snippet`).
- `question_count`: Number of questions of this type.
- `bloom_taxonomy`: Cognitive level (`remember`, `understand`, `apply`, `analyze`, `evaluate`, `create`).
- `marks`: Weight per question in this group.

## 3. API Endpoints
- `GET /api/exams/{exam}/question-configurations`: List blueprint groups.
- `POST /api/exams/{exam}/question-configurations/sync`: Bulk update all configurations (atomic sync).
- `POST /api/exams/{exam}/question-configurations`: Create a single group.
- `PUT /api/exams/{exam}/question-configurations/{id}`: Update a group.
- `DELETE /api/exams/{exam}/question-configurations/{id}`: Remove a group.

## 4. Flutter/BLoC Architecture
- **Model**: `ExamQuestionConfigurationModel`.
- **Bloc**: `ExamQuestionConfigurationBloc`.
- **UI**: Added `QuestionConfigurationBuilder` section to `ExamFormView`.
- **Validation**: Enforces numeric constraints and type-safe dropdown selections.

## 5. AI Generator Integration
The AI Question Generator now features "Configurations from Selected Exams".
- Selecting a configuration chip pre-fills the generator with the blueprint's metadata.
- Prompt Engineering: The system prompt now includes explicit cognitive instructions per Bloom level to ensure high-quality, targeted output.

## 6. Authorization
- **Examiner**: Restricted to their own department's exams.
- **Admin**: Full cross-departmental access.
- **Candidate**: Blocked from all configuration endpoints.

## 7. Manual Verification Steps
1. Login as a teacher.
2. Go to an exam's edit form.
3. Scroll to "Question Configuration".
4. Add an MCQ group (Count: 10, Bloom: Analyze, Marks: 2).
5. Add a True/False group (Count: 5, Bloom: Remember, Marks: 1).
6. Verify "Total Questions" (15) and "Total Marks" (25).
7. Save the configuration.
8. Go to "AI Question Generator".
9. Select the exam.
10. Click the MCQ chip under "Configurations from Selected Exams".
11. Verify form pre-fills correctly.
12. Click "Generate Questions".
