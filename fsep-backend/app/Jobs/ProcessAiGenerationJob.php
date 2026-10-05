<?php

namespace App\Jobs;

use App\Models\AiQuestionGenerationJob;
use App\Models\Question;
use App\Services\AiQuestionGeneratorService;
use Exception;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class ProcessAiGenerationJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /**
     * The number of times the job may be attempted.
     */
    public $tries = 1;

    /**
     * The number of seconds the job can run before timing out.
     */
    public $timeout = 300;

    protected $jobId;

    /**
     * Create a new job instance.
     */
    public function __construct($jobId)
    {
        $this->jobId = $jobId;
    }

    /**
     * Execute the job.
     */
    public function handle(AiQuestionGeneratorService $generator): void
    {
        $job = AiQuestionGenerationJob::find($this->jobId);

        if (!$job) {
            return;
        }

        if ($job->status !== 'GENERATING') {
            return;
        }

        try {
            $chunks = $job->chunks;
            $params = $job->params;
            $examIds = $job->exam_ids;

            if (empty($chunks)) {
                throw new Exception("No chunks found for generation.");
            }

            $totalRequested = $params['count'];
            $questionTypes = $params['question_types'];

            $generatedCount = 0;
            $allGenerated = [];

            // Simple distribution: loop through chunks and types until totalRequested is reached.
            $chunkIndex = 0;
            $chunkCount = count($chunks);

            while ($generatedCount < $totalRequested) {
                foreach ($questionTypes as $type) {
                    if ($generatedCount >= $totalRequested) break;

                    $currentChunk = $chunks[$chunkIndex % $chunkCount];

                    try {
                        $generated = $generator->generate([
                            'content' => $currentChunk['content'],
                            'question_type' => $type,
                            'difficulty' => $params['difficulty'],
                            'bloom_taxonomy' => $params['bloom_taxonomy'],
                            'count' => 1, // Generate one by one to avoid large payloads/errors
                            'marks' => $params['marks'],
                        ]);

                        if (!empty($generated)) {
                            $allGenerated[] = $generated[0];
                            $generatedCount++;
                        }
                    } catch (Exception $e) {
                        Log::warning("AI generation failed for chunk {$chunkIndex} type {$type}: " . $e->getMessage());
                        // Continue to next attempt
                    }

                    $chunkIndex++;
                }

                // If we've cycled through all chunks and haven't made progress, stop to avoid infinite loop.
                if ($chunkIndex > $chunkCount * count($questionTypes) * 2 && $generatedCount == 0) {
                    throw new Exception("AI provider failed to generate any questions after multiple attempts.");
                }

                // Safety break
                if ($chunkIndex > 100) break;
            }

            if (empty($allGenerated)) {
                throw new Exception("AI provider did not return any usable questions.");
            }

            // Distribute across exams
            $examCount = count($examIds);
            foreach ($allGenerated as $index => $qData) {
                $examId = $examIds[$index % $examCount];

                Question::create([
                    'exam_id' => $examId,
                    'created_by' => $job->examiner_id,
                    'generation_job_id' => $job->id,
                    'question_text' => $qData['question_text'],
                    'question_type' => $qData['question_type'],
                    'marks' => $qData['marks'],
                    'difficulty' => $qData['difficulty'],
                    'bloom_taxonomy' => $qData['bloom_taxonomy'],
                    'topic_tag' => $qData['topic_tag'],
                    'options' => $qData['options'],
                    'correct_answer' => $qData['correct_answer'],
                    'is_ai_generated' => true,
                    'review_status' => 'pending',
                ]);
            }

            $job->update([
                'status' => 'REVIEW_PENDING',
                'questions_generated' => count($allGenerated),
                'review_pending_at' => now(),
            ]);

        } catch (Exception $e) {
            Log::error("AI Generation Job Failed: " . $e->getMessage());
            $job->update([
                'status' => 'FAILED',
                'last_error' => $e->getMessage(),
                'failed_at' => now(),
            ]);
        }
    }
}
