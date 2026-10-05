<?php

namespace Tests\Feature;

use App\Models\AiQuestionGenerationJob;
use App\Models\Exam;
use App\Models\User;
use App\Services\DocumentParserService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class AiQuestionDocumentParsingTest extends TestCase
{
    use RefreshDatabase;

    public function test_txt_extraction_and_chunking(): void
    {
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

        // Create a long text to force chunking
        // Target is 4000 chars, overlap 400.
        $text = str_repeat("This is a test sentence for chunking. ", 400); // ~15000 chars
        $file = UploadedFile::fake()->create('notes.txt', 100, 'text/plain');

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
        $jobId = $response->json('job_id');

        // Manually overwrite the fake file content with our long text because
        // fake()->create() just makes a file of specific size but we need specific content.
        $job = AiQuestionGenerationJob::find($jobId);
        $files = Storage::files("private/generation_docs/{$job->id}");
        Storage::put($files[0], $text);

        // Run parser again
        $service = new DocumentParserService();
        $service->parse($job);

        $job->refresh();
        $this->assertEquals('GENERATING', $job->status);
        $this->assertNotEmpty($job->chunks);
        $this->assertGreaterThan(1, count($job->chunks));

        // Verify overlap
        $chunk1 = $job->chunks[0]['content'];
        $chunk2 = $job->chunks[1]['content'];

        $overlap = substr($chunk1, -100);
        $this->assertStringContainsString($overlap, $chunk2);
    }

    public function test_empty_file_fails_job(): void
    {
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

        $file = UploadedFile::fake()->create('empty.txt', 0, 'text/plain');

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
        $this->assertEquals('FAILED', $response->json('status'));
        $this->assertStringContainsString('No usable text', $response->json('error'));
    }

    public function test_multiple_files_retains_source_identity(): void
    {
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

        $file1 = UploadedFile::fake()->create('doc1.txt', 1, 'text/plain');
        $file2 = UploadedFile::fake()->create('doc2.txt', 1, 'text/plain');

        $response = $this->actingAs($examiner)->postJson('/api/questions/generate/upload', [
            'files' => [$file1, $file2],
            'exam_ids' => [$exam->id],
            'question_types' => ['mcq'],
            'difficulty' => 'medium',
            'bloom_taxonomy' => 'understand',
            'count' => 2,
            'marks' => 5,
        ]);

        $response->assertStatus(201);
        $job = AiQuestionGenerationJob::find($response->json('job_id'));

        // Manually fix fake files
        $files = Storage::files("private/generation_docs/{$job->id}");
        Storage::put($files[0], "Content of doc 1");
        Storage::put($files[1], "Content of doc 2");

        (new DocumentParserService())->parse($job);
        $job->refresh();

        $this->assertCount(2, $job->chunks);
        $this->assertEquals('Content of doc 1', $job->chunks[0]['content']);
        $this->assertEquals('Content of doc 2', $job->chunks[1]['content']);

        // Check source identity
        $this->assertStringContainsString('doc', $job->chunks[0]['source']);
    }
}
