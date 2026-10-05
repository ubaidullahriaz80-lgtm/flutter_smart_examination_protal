<?php

namespace Database\Seeders;

use App\Models\Answer;
use App\Models\BehaviorEvent;
use App\Models\Exam;
use App\Models\ExamSession;
use App\Models\Question;
use App\Models\User;
use App\Services\GradingService;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

/**
 * FSEP demo data seeder. Safe to run repeatedly (`php artisan migrate --seed`
 * or `php artisan db:seed`) — every write here is keyed on a deterministic
 * identifying value via updateOrCreate/firstOrCreate, so re-running never
 * creates duplicates and never truncates/deletes anything.
 *
 * All demo passwords are "password123" — for local evaluation only, never
 * used for a real deployment.
 */
class DatabaseSeeder extends Seeder
{
    /** email => [name, role] for one account per RBAC role. */
    private const DEMO_USERS = [
        'admin@fsep.test' => ['name' => 'FSEP Admin', 'role' => 'system_administrator'],
        'testteacher@fsep.test' => ['name' => 'Test Teacher', 'role' => 'examiner'],
        'candidate@fsep.test' => ['name' => 'Demo Candidate', 'role' => 'candidate'],
        'testinst@fsep.test' => ['name' => 'Institutional Admin', 'role' => 'institutional_administrator'],
        'ali@fsep.test' => ['name' => 'Ali (Invigilator)', 'role' => 'live_invigilator'],
    ];

    public function run(): void
    {
        $users = $this->seedUsers();
        $exam = $this->seedExam($users['testteacher@fsep.test']);
        $questions = $this->seedQuestions($exam, $users['testteacher@fsep.test']);
        $this->seedCompletedSession($exam, $questions, $users['candidate@fsep.test']);
        // Deliberately seeded last, after grading — see method doc.
        $this->seedAdditionalQuestionTypes($exam, $users['testteacher@fsep.test']);
    }

    /**
     * @return array<string, User> email => User
     */
    private function seedUsers(): array
    {
        $users = [];

        foreach (self::DEMO_USERS as $email => $info) {
            $user = User::updateOrCreate(
                ['email' => $email],
                [
                    'name' => $info['name'],
                    'password' => Hash::make('password123'),
                ],
            );

            // role isn't mass-assignable (see UserController::store, which
            // uses this same pattern) — set it directly.
            $user->role = $info['role'];
            $user->save();

            $users[$email] = $user;
        }

        return $users;
    }

    private function seedExam(User $examiner): Exam
    {
        return Exam::updateOrCreate(
            [
                'title' => 'FSEP Demo Exam — Computer Fundamentals',
                'created_by' => $examiner->id,
            ],
            [
                'description' => 'Seeded demo exam for evaluation purposes.',
                'course_code' => 'CS101',
                'duration_minutes' => 60,
                'total_marks' => 20,
                'negative_marking_weight' => 0.25,
                'status' => 'published',
            ],
        );
    }

    /**
     * @return array<string, Question> a short key per question => Question
     */
    private function seedQuestions(Exam $exam, User $examiner): array
    {
        $definitions = [
            'mcq' => [
                'question_text' => 'What does CPU stand for?',
                'question_type' => 'mcq',
                'marks' => 5,
                'difficulty' => 'easy',
                'bloom_taxonomy' => 'remember',
                'topic_tag' => 'Computer Basics',
                'options' => [
                    'Central Processing Unit',
                    'Computer Personal Unit',
                    'Central Program Utility',
                    'Central Program Unit',
                ],
                'correct_answer' => 'Central Processing Unit',
            ],
            'true_false' => [
                'question_text' => 'RAM is a volatile form of memory.',
                'question_type' => 'true_false',
                'marks' => 5,
                'difficulty' => 'easy',
                'bloom_taxonomy' => 'remember',
                'topic_tag' => 'Computer Basics',
                'options' => null,
                'correct_answer' => 'True',
            ],
            'short_answer' => [
                'question_text' => 'What does GPU stand for?',
                'question_type' => 'short_answer',
                'marks' => 5,
                'difficulty' => 'medium',
                'bloom_taxonomy' => 'understand',
                'topic_tag' => 'Computer Basics',
                'options' => null,
                'correct_answer' => 'Graphics Processing Unit',
            ],
            'essay' => [
                'question_text' => 'Explain the difference between RAM and ROM.',
                'question_type' => 'essay',
                'marks' => 5,
                'difficulty' => 'medium',
                'bloom_taxonomy' => 'analyze',
                'topic_tag' => 'Computer Basics',
                'options' => null,
                'correct_answer' => null,
            ],
        ];

        $questions = [];

        foreach ($definitions as $key => $data) {
            $questions[$key] = Question::updateOrCreate(
                [
                    'exam_id' => $exam->id,
                    'question_text' => $data['question_text'],
                ],
                $data + [
                    'created_by' => $examiner->id,
                    'is_ai_generated' => false,
                    'review_status' => 'approved',
                ],
            );
        }

        return $questions;
    }

    /**
     * Adds the two remaining supported question types (matching,
     * code_snippet) to the existing demo exam, so a fresh install
     * demonstrates all 6 question types in the Question Bank / Exam
     * Delivery UI — not just the 4 seedQuestions() already covers.
     *
     * Deliberately called AFTER seedCompletedSession(), not before:
     * GradingService::gradeSession() sums question.marks across every
     * question currently on session->exam->questions (see
     * app/Services/GradingService.php), regardless of whether the
     * candidate answered it. Adding these two questions earlier would
     * inflate the seeded session's Result.max_score from 20 to 30 the
     * very first time this seeder runs on a fresh database — silently
     * changing the existing demo session's result. Grading only happens
     * once per session (seedCompletedSession's own
     * `if ($session->status !== 'in_progress') return;` guard), so
     * seeding these afterward leaves that already-graded Result exactly
     * as it was, on every run. Neither question is answered by the
     * seeded candidate.
     */
    private function seedAdditionalQuestionTypes(Exam $exam, User $examiner): void
    {
        $matchingPairs = [
            ['left' => 'CPU', 'right' => 'Executes instructions'],
            ['left' => 'RAM', 'right' => 'Temporary working memory'],
            ['left' => 'Hard Disk', 'right' => 'Permanent storage'],
        ];

        $definitions = [
            [
                'question_text' => 'Match each hardware component to its primary function.',
                'question_type' => 'matching',
                'marks' => 5,
                'difficulty' => 'medium',
                'bloom_taxonomy' => 'understand',
                'topic_tag' => 'Computer Basics',
                'options' => $matchingPairs,
                // Same canonical-JSON shape QuestionController::validatedQuestionData
                // computes for 'matching' — keyed by left item, pair order preserved.
                'correct_answer' => json_encode(
                    array_combine(array_column($matchingPairs, 'left'), array_column($matchingPairs, 'right')),
                    JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES,
                ),
            ],
            [
                'question_text' => 'Write a function that returns the sum of two integers.',
                'question_type' => 'code_snippet',
                'marks' => 5,
                'difficulty' => 'medium',
                'bloom_taxonomy' => 'apply',
                'topic_tag' => 'Computer Basics',
                // Single-element programming-language list — same shape
                // QuestionController::validatedQuestionData stores for
                // code_snippet's optional language.
                'options' => ['python'],
                // Always null — code_snippet has no correct_answer,
                // matching QuestionController/GradingService.
                'correct_answer' => null,
            ],
        ];

        foreach ($definitions as $data) {
            Question::updateOrCreate(
                [
                    'exam_id' => $exam->id,
                    'question_text' => $data['question_text'],
                ],
                $data + [
                    'created_by' => $examiner->id,
                    'is_ai_generated' => false,
                    'review_status' => 'approved',
                ],
            );
        }
    }

    /**
     * Creates one completed, graded candidate session so the Result
     * screen, per-question correctness, and Learning Gap Detection all
     * have real data to show immediately after a fresh seed. Uses the
     * project's actual GradingService (not hand-computed values) so this
     * is genuine output from the real grading pipeline, not fabricated.
     *
     * Only populates answers/grades/behavior events the first time this
     * session is created — an already-completed demo session from a
     * previous seed run is left untouched, never reverted or re-graded.
     *
     * @param array<string, Question> $questions
     */
    private function seedCompletedSession(Exam $exam, array $questions, User $candidate): void
    {
        $startedAt = now()->subMinutes(70);

        $session = ExamSession::firstOrCreate(
            ['exam_id' => $exam->id, 'candidate_id' => $candidate->id],
            [
                'status' => 'in_progress',
                'started_at' => $startedAt,
                'expires_at' => $startedAt->copy()->addMinutes($exam->duration_minutes),
            ],
        );

        if ($session->status !== 'in_progress') {
            return; // already completed by a previous seed run — leave as-is
        }

        DB::transaction(function () use ($session, $questions) {
            // One deliberately incorrect answer (true_false) so grading
            // demonstrates negative marking and Learning Gap Detection has
            // a real, non-empty weak topic to report — not just a perfect
            // score, which would make both features look untested.
            $answers = [
                'mcq' => 'Central Processing Unit', // correct
                'true_false' => 'False', // incorrect (correct answer is "True")
                'short_answer' => 'Graphics Processing Unit', // correct
                'essay' => 'RAM is temporary, volatile working memory; ROM is permanent, non-volatile storage that retains data without power.', // routes to pending_manual_review
            ];

            foreach ($answers as $key => $selectedOption) {
                Answer::updateOrCreate(
                    [
                        'exam_session_id' => $session->id,
                        'question_id' => $questions[$key]->id,
                    ],
                    ['selected_option' => $selectedOption],
                );
            }

            // A couple of legitimate Behavioral Cheating Detection events
            // for this session, so the feature has something real to
            // demonstrate rather than an empty "Normal" state. Points
            // mirror ExamSessionController::EVENT_POINTS exactly.
            BehaviorEvent::create([
                'exam_session_id' => $session->id,
                'event_type' => 'focus_lost',
                'suspicion_points' => 10,
            ]);
            BehaviorEvent::create([
                'exam_session_id' => $session->id,
                'event_type' => 'focus_regained',
                'suspicion_points' => 0,
            ]);
            BehaviorEvent::create([
                'exam_session_id' => $session->id,
                'event_type' => 'focus_lost',
                'suspicion_points' => 10,
            ]);

            $session->status = 'submitted';
            $session->submitted_at = now();
            $session->save();

            app(GradingService::class)->gradeSession($session);
        });
    }
}
