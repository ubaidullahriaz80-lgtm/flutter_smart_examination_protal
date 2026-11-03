<?php

namespace App\Jobs;

use App\Models\AiQuestionGenerationJob;
use App\Services\AiQuestionGeneratorService;
use Exception;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use Throwable;

class ProcessAiTopicGenerationJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 1;
    public int $timeout = 300;

    public function __construct(private readonly int $jobId)
    {
    }

    public function handle(AiQuestionGeneratorService $generator): void
    {
        $job = AiQuestionGenerationJob::find($this->jobId);
        if (!$job || $job->status !== 'GENERATING') {
            return;
        }

        try {
            $params = $job->params;
            $questionTypes = $params['question_types'];
            $countsByType = $this->splitEvenly($params['count'], count($questionTypes));
            $questions = [];

            foreach ($questionTypes as $index => $type) {
                $typeCount = $countsByType[$index];
                if ($typeCount < 1) {
                    continue;
                }

                array_push($questions, ...$generator->generate([
                    'topic' => $params['topic'],
                    'question_type' => $type,
                    'difficulty' => $params['difficulty'],
                    'bloom_taxonomy' => $params['bloom_taxonomy'],
                    'count' => $typeCount,
                    'marks' => $params['marks'],
                ]));
            }

            if ($questions === []) {
                throw new Exception('The AI provider did not return any usable questions.');
            }

            $examIdsByQuestion = $this->distributeAcross(count($questions), $job->exam_ids);
            $questions = array_map(
                static fn (array $question, int $index): array => $question + [
                    'is_ai_generated' => true,
                    'exam_id' => $examIdsByQuestion[$index],
                ],
                $questions,
                array_keys($questions),
            );

            $job->update([
                'status' => 'COMPLETED',
                'questions_generated' => count($questions),
                'generated_questions' => $questions,
                'completed_at' => now(),
            ]);
        } catch (Throwable $exception) {
            Log::error('AI topic generation job failed', [
                'job_id' => $job->id,
                'error' => $exception->getMessage(),
            ]);

            $job->update([
                'status' => 'FAILED',
                'last_error' => $exception->getMessage(),
                'failed_at' => now(),
            ]);
        }
    }

    public function failed(?Throwable $exception): void
    {
        $job = AiQuestionGenerationJob::find($this->jobId);
        if (!$job || $job->status !== 'GENERATING') {
            return;
        }

        $job->update([
            'status' => 'FAILED',
            'last_error' => $exception?->getMessage() ?? 'Question generation worker failed.',
            'failed_at' => now(),
        ]);
    }

    /** @return array<int, int> */
    private function splitEvenly(int $total, int $groups): array
    {
        $base = intdiv($total, $groups);
        $remainder = $total % $groups;

        return array_map(
            static fn (int $index): int => $base + ($index < $remainder ? 1 : 0),
            range(0, $groups - 1),
        );
    }

    /** @param array<int, int> $values
     *  @return array<int, int>
     */
    private function distributeAcross(int $total, array $values): array
    {
        $counts = $this->splitEvenly($total, count($values));
        $assignment = [];

        foreach ($values as $index => $value) {
            for ($i = 0; $i < $counts[$index]; $i++) {
                $assignment[] = $value;
            }
        }

        return $assignment;
    }
}