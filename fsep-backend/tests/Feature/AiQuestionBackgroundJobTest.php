<?php

namespace Tests\Feature;

use App\Jobs\ProcessAiGenerationJob;
use App\Models\AiQuestionGenerationJob;
use App\Models\Exam;
use App\Models\User;
use App\Services\AiQuestionGeneratorService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Mockery\MockInterface;
use Tests\TestCase;

class AiQuestionBackgroundJobTest extends TestCase
{
    use RefreshDatabase;

    public function test_upload_dispatches_background_job(): void
    {
        Queue::fake();
        Storage::fake('local');
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Test Exam',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0,
            'status' => 'published',
        ]);

        $file = UploadedFile::fake()->createWithContent('syllabus.txt', 'This is some syllabus content.');
        Storage::fake('local');

        $response = $this->actingAs($examiner)->postJson('/api/questions/generate/upload', [
            'files' => [$file],
            'exam_ids' => [$exam->id],
            'question_types' => ['mcq'],
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'understand',
            'count' => 3,
            'marks' => 5,
        ]);

        $response->assertStatus(201);

        // If status is FAILED, something went wrong with the fake upload/parse
        if ($response->json('status') === 'FAILED') {
            $this->fail("Upload failed: " . $response->json('error'));
        }

        $jobId = $response->json('job_id');

        Queue::assertPushed(ProcessAiGenerationJob::class, function ($job) use ($jobId) {
            // Use reflection to access protected jobId
            $reflection = new \ReflectionClass($job);
            $property = $reflection->getProperty('jobId');
            $property->setAccessible(true);
            return $property->getValue($job) == $jobId;
        });
    }

    public function test_background_job_generates_questions(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Test Exam',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0,
            'status' => 'draft',
        ]);

        $job = AiQuestionGenerationJob::create([
            'examiner_id' => $examiner->id,
            'status' => 'GENERATING',
            'chunks' => [['source' => 'doc.txt', 'content' => 'Sample content']],
            'exam_ids' => [$exam->id],
            'params' => [
                'question_types' => ['mcq'],
                'difficulty' => 'medium',
                'bloom_taxonomy' => 'understand',
                'count' => 1,
                'marks' => 5,
            ]
        ]);

        $this->mock(AiQuestionGeneratorService::class, function (MockInterface $mock) {
            $mock->shouldReceive('generate')->once()->andReturn([
                [
                    'question_text' => 'Generated Question',
                    'question_type' => 'mcq',
                    'marks' => 5,
                    'difficulty' => 'medium',
                    'bloom_taxonomy' => 'understand',
                    'topic_tag' => 'Topic',
                    'options' => ['A', 'B', 'C', 'D'],
                    'correct_answer' => 'A',
                ]
            ]);
        });

        $backgroundJob = new ProcessAiGenerationJob($job->id);
        $backgroundJob->handle(app(AiQuestionGeneratorService::class));

        $job->refresh();
        $this->assertEquals('REVIEW_PENDING', $job->status);
        $this->assertEquals(1, $job->questions_generated);
        $this->assertCount(1, $job->questions);
        $this->assertEquals('Generated Question', $job->questions->first()->question_text);
    }

    public function test_polling_endpoint_returns_status(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $job = AiQuestionGenerationJob::create([
            'examiner_id' => $examiner->id,
            'status' => 'GENERATING',
        ]);

        $response = $this->actingAs($examiner)->getJson("/api/questions/generate/job/{$job->id}");

        $response->assertStatus(200)->assertJson([
            'id' => $job->id,
            'status' => 'GENERATING',
        ]);
    }
}
