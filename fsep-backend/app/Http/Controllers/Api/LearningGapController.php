<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Answer;
use App\Models\ExamSession;
use App\Models\LearningGapReport;
use App\Services\LearningAnalyticsService;
use Illuminate\Http\Request;

/**
 * Learning Gap Detection (FSEP novelty feature).
 */
class LearningGapController extends Controller
{
    private const HIGH_GAP_MAX_PERCENT = 50;
    private const MODERATE_GAP_MAX_PERCENT = 70;

    /**
     * GET /api/learning-gaps
     *
     * Global aggregate summary across all sessions.
     */
    public function index(Request $request, LearningAnalyticsService $analytics)
    {
        $candidateId = $request->user()->id;

        $answers = Answer::query()
            ->whereHas('examSession', function ($query) use ($candidateId) {
                $query->where('candidate_id', $candidateId)
                    ->whereIn('status', ['submitted', 'expired']);
            })
            ->with('question.exam')
            ->where('grading_status', 'graded')
            ->get();

        $topics = [];

        foreach ($answers as $answer) {
            $question = $answer->question;
            if ($question === null) continue;

            $topic = $question->topic_tag !== null ? trim($question->topic_tag) : '';
            if ($topic === '') continue;

            if (!isset($topics[$topic])) {
                $topics[$topic] = [
                    'topic' => $topic,
                    'course_code' => $question->exam?->course_code,
                    'questions_attempted' => 0,
                    'correct_answers' => 0,
                    'obtained_marks' => 0,
                    'total_marks' => 0,
                    'answers' => collect(),
                ];
            }

            $topics[$topic]['questions_attempted']++;
            $topics[$topic]['total_marks'] += $question->marks;
            $topics[$topic]['answers']->push($answer);

            if ($answer->is_correct === true) {
                $topics[$topic]['correct_answers']++;
                $topics[$topic]['obtained_marks'] += $question->marks;
            }
        }

        $allGaps = [];
        foreach ($topics as $topicData) {
            $percentage = $topicData['total_marks'] > 0
                ? round(($topicData['obtained_marks'] / $topicData['total_marks']) * 100, 1)
                : 0;

            $severity = match (true) {
                $percentage < self::HIGH_GAP_MAX_PERCENT => 'high',
                $percentage < self::MODERATE_GAP_MAX_PERCENT => 'moderate',
                default => 'none',
            };

            $allGaps[] = [
                'topic' => $topicData['topic'],
                'course_code' => $topicData['course_code'],
                'questions_attempted' => $topicData['questions_attempted'],
                'correct_answers' => $topicData['correct_answers'],
                'obtained_marks' => $topicData['obtained_marks'],
                'total_marks' => $topicData['total_marks'],
                'percentage' => $percentage,
                'severity' => $severity,
                'bloom_breakdown' => $analytics->computeBloomProfile($topicData['answers']),
                'explanation' => sprintf(
                    'Your performance in this topic (%s%%) is below the recommended threshold of %d%%.',
                    $percentage,
                    self::MODERATE_GAP_MAX_PERCENT,
                ),
            ];
        }

        $weakTopics = collect($allGaps)->filter(fn($g) => $g['severity'] !== 'none')
            ->sortBy('percentage')->values()->all();

        return response()->json([
            'learning_gaps' => $weakTopics,
            'all_topics' => array_values($allGaps),
            'bloom_profile' => $analytics->computeBloomProfile($answers),
            'difficulty_profile' => $analytics->computeDifficultyProfile($answers),
            'improvement_roadmap' => $analytics->generateRoadmap($allGaps),
            'topics_analyzed' => count($topics),
            'questions_attempted' => $answers->count(),
        ]);
    }

    /**
     * GET /api/learning/report/{session}
     *
     * Fetch the persisted report for a specific session.
     */
    public function show(Request $request, ExamSession $session, LearningAnalyticsService $analytics)
    {
        if ($session->candidate_id !== $request->user()->id) {
            return response()->json(['message' => 'Unauthorized.'], 403);
        }

        $report = LearningGapReport::where('exam_session_id', $session->id)->first();

        // If not persisted yet (e.g. legacy session), generate and save it now.
        if (!$report) {
            if ($session->status === 'submitted') {
                $report = $analytics->generateReport($session);
            } else {
                return response()->json(['message' => 'Report not available yet.'], 404);
            }
        }

        return response()->json($report);
    }

    /**
     * GET /api/learning/history
     *
     * Fetch all learning gap reports for the candidate.
     */
    public function history(Request $request)
    {
        $reports = LearningGapReport::with('exam:id,title,course_code')
            ->where('candidate_id', $request->user()->id)
            ->orderByDesc('generated_at')
            ->get();

        return response()->json([
            'reports' => $reports->map(fn($r) => [
                'id' => $r->id,
                'session_id' => $r->exam_session_id,
                'exam_id' => $r->exam_id,
                'exam_title' => $r->exam->title,
                'course_code' => $r->exam->course_code,
                'generated_at' => $r->generated_at,
                'summary' => [
                    'weak_topics' => count($r->learning_gaps),
                    'total_topics' => $r->topics_analyzed,
                    'questions_attempted' => $r->questions_attempted,
                ],
            ]),
        ]);
    }
}
