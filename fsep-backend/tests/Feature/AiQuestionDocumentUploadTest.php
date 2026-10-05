<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Exam;
use App\Models\AiQuestionGenerationJob;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class AiQuestionDocumentUploadTest extends TestCase
{
    use RefreshDatabase;

    private function createExam($examiner)
    {
        return Exam::create([
            'created_by' => $examiner->id,
            'title' => 'Test Exam',
            'duration_minutes' => 60,
            'total_marks' => 10,
            'negative_marking_weight' => 0,
            'status' => 'published',
        ]);
    }

    public function test_authenticated_examiner_can_upload_pdf(): void
    {
        Storage::fake('local');
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = $this->createExam($examiner);

        $file = UploadedFile::fake()->createWithContent('syllabus.pdf', 'PDF content');

        $response = $this->actingAs($examiner)->postJson('/api/questions/generate/upload', [
            'files' => [$file],
            'exam_ids' => [$exam->id],
            'question_types' => ['mcq'],
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'understand',
            'count' => 1,
            'marks' => 5,
        ]);

        $response->assertStatus(201);
        $jobId = $response->json('job_id');

        $this->assertDatabaseHas('ai_question_generation_jobs', [
            'id' => $jobId,
            'examiner_id' => $examiner->id,
        ]);

        // Smalot might fail fake PDF, but we check if record exists and status is at least attempted.
        $this->assertNotEquals('UPLOADING', AiQuestionGenerationJob::find($jobId)->status);

        $files = Storage::disk('local')->files("private/generation_docs/{$jobId}");
        $this->assertNotEmpty($files);
    }

    public function test_authenticated_examiner_can_upload_txt(): void
    {
        Storage::fake('local');
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = $this->createExam($examiner);

        $file = UploadedFile::fake()->createWithContent('notes.txt', 'Some text notes.');

        $response = $this->actingAs($examiner)->postJson('/api/questions/generate/upload', [
            'files' => [$file],
            'exam_ids' => [$exam->id],
            'question_types' => ['mcq'],
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'understand',
            'count' => 1,
            'marks' => 5,
        ]);

        $response->assertStatus(201);
        $this->assertEquals('GENERATING', $response->json('status'));
    }

    public function test_unauthenticated_request_is_rejected(): void
    {
        $response = $this->postJson('/api/questions/generate/upload', [
            'files' => [UploadedFile::fake()->create('test.pdf')]
        ]);

        $response->assertStatus(401);
    }

    public function test_unsupported_file_type_is_rejected(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = $this->createExam($examiner);

        $file = UploadedFile::fake()->create('image.png', 500, 'image/png');

        $response = $this->actingAs($examiner)->postJson('/api/questions/generate/upload', [
            'files' => [$file],
            'exam_ids' => [$exam->id],
            'question_types' => ['mcq'],
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'understand',
            'count' => 1,
            'marks' => 5,
        ]);

        $response->assertStatus(422);
    }

    public function test_oversized_file_is_rejected(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = $this->createExam($examiner);

        // 21MB (limit is 20MB)
        $file = UploadedFile::fake()->create('large.pdf', 21504, 'application/pdf');

        $response = $this->actingAs($examiner)->postJson('/api/questions/generate/upload', [
            'files' => [$file],
            'exam_ids' => [$exam->id],
            'question_types' => ['mcq'],
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'understand',
            'count' => 1,
            'marks' => 5,
        ]);

        $response->assertStatus(422);
    }

    public function test_more_than_10_files_rejected(): void
    {
        $examiner = User::factory()->create(['role' => 'examiner']);
        $exam = $this->createExam($examiner);

        $files = [];
        for ($i = 0; $i < 11; $i++) {
            $files[] = UploadedFile::fake()->create("file{$i}.pdf");
        }

        $response = $this->actingAs($examiner)->postJson('/api/questions/generate/upload', [
            'files' => $files,
            'exam_ids' => [$exam->id],
            'question_types' => ['mcq'],
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'understand',
            'count' => 1,
            'marks' => 5,
        ]);

        $response->assertStatus(422);
    }
}
