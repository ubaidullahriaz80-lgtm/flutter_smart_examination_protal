<?php

namespace App\Services;

use App\Models\Answer;
use App\Models\ExamSession;
use App\Models\LearningGapReport;
use Illuminate\Support\Collection;

/**
 * Service for computing candidate learning gap profiles and topic analytics.
 */
class LearningAnalyticsService
{
    private const BLOOM_LEVELS = ['remember', 'understand', 'apply', 'analyze', 'evaluate', 'create'];
    private const DIFFICULTIES = ['easy', 'medium', 'hard'];
    private const HIGH_GAP_MAX_PERCENT = 50;
    private const MODERATE_GAP_MAX_PERCENT = 70;

    /**
     * Generates and persists a Learning Gap Report for the given session.
     */
    public function generateReport(ExamSession $session): LearningGapReport
    {
        $answers = $session->answers()
            ->where('grading_status', 'graded')
            ->with('question.exam')
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
                'bloom_breakdown' => $this->computeBloomProfile($topicData['answers']),
                'explanation' => sprintf(
                    'Your performance in this topic (%s%%) is below the recommended threshold of %d%%.',
                    $percentage,
                    self::MODERATE_GAP_MAX_PERCENT,
                ),
            ];
        }

        $learningGaps = collect($allGaps)->filter(fn($g) => $g['severity'] !== 'none')
            ->sortBy('percentage')->values()->all();

        return LearningGapReport::updateOrCreate(
            ['exam_session_id' => $session->id],
            [
                'candidate_id' => $session->candidate_id,
                'exam_id' => $session->exam_id,
                'learning_gaps' => $learningGaps,
                'all_topics' => $allGaps,
                'bloom_profile' => $this->computeBloomProfile($answers),
                'difficulty_profile' => $this->computeDifficultyProfile($answers),
                'improvement_roadmap' => $this->generateRoadmap($allGaps),
                'topics_analyzed' => count($topics),
                'questions_attempted' => $answers->count(),
                'generated_at' => now(),
            ]
        );
    }

    public function computeBloomProfile(Collection $answers): array
    {
        $profile = [];
        foreach (self::BLOOM_LEVELS as $level) {
            $relevant = $answers->filter(fn($a) => $a->question->bloom_taxonomy === $level);
            if ($relevant->isEmpty()) {
                $profile[ucfirst($level)] = null;
                continue;
            }

            $correct = $relevant->where('is_correct', true)->count();
            $profile[ucfirst($level)] = round(($correct / $relevant->count()) * 100, 1);
        }
        return $profile;
    }

    public function computeDifficultyProfile(Collection $answers): array
    {
        $profile = [];
        foreach (self::DIFFICULTIES as $level) {
            $relevant = $answers->filter(fn($a) => $a->question->difficulty === $level);
            if ($relevant->isEmpty()) {
                $profile[ucfirst($level)] = null;
                continue;
            }

            $correct = $relevant->where('is_correct', true)->count();
            $profile[ucfirst($level)] = round(($correct / $relevant->count()) * 100, 1);
        }
        return $profile;
    }

    public function generateRoadmap(array $topics): array
    {
        usort($topics, fn($a, $b) => $a['percentage'] <=> $b['percentage']);

        $weakest = array_slice($topics, 0, 5);
        $roadmap = [];

        foreach ($weakest as $index => $topicData) {
            $roadmap[] = [
                'rank' => $index + 1,
                'topic' => $topicData['topic'],
                'mastery' => $topicData['percentage'],
                'severity' => $topicData['severity'],
                'bloom_breakdown' => $topicData['bloom_breakdown'],
                'suggestion' => $this->getRemediationSuggestion($topicData),
            ];
        }

        return $roadmap;
    }

    private function getRemediationSuggestion(array $topicData): string
    {
        $weakestLevel = 'Remember';
        $lowestVal = 101;

        foreach ($topicData['bloom_breakdown'] as $level => $val) {
            if ($val !== null && $val < $lowestVal) {
                $lowestVal = $val;
                $weakestLevel = $level;
            }
        }

        $topic = $topicData['topic'];

        if ($topicData['percentage'] < 50) {
            return "Fundamental concepts of '$topic' are not yet clear. Re-watch foundational lectures and focus on the '$weakestLevel' level basics.";
        }

        if ($weakestLevel === 'Analyze' || $weakestLevel === 'Evaluate' || $weakestLevel === 'Create') {
            return "You understand the basics of '$topic', but struggle with high-order thinking. Practice more complex, scenario-based problems at the '$weakestLevel' level.";
        }

        return "Continue reviewing '$topic' with a focus on improving your '$weakestLevel' skills to move toward mastery.";
    }
}
