<?php

namespace Tests\Feature;

use App\Models\Department;
use App\Models\Exam;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ExamVisibilityTest extends TestCase
{
    use RefreshDatabase;

    protected Department $deptCS;
    protected Department $deptSE;

    protected function setUp(): void
    {
        parent::setUp();
        $this->deptCS = Department::create(['name' => 'Computer Science', 'code' => 'CS']);
        $this->deptSE = Department::create(['name' => 'Software Engineering', 'code' => 'SE']);
    }

    public function test_candidate_can_only_see_exams_matching_department_and_semester(): void
    {
        $candidate = User::factory()->create([
            'role' => 'candidate',
            'department_id' => $this->deptCS->id,
            'semester' => 3
        ]);

        $examCorrect = Exam::factory()->create([
            'department_id' => $this->deptCS->id,
            'semester' => 3,
            'title' => 'CS Sem 3 Exam',
            'created_by' => User::factory()->create()->id
        ]);

        $examWrongDept = Exam::factory()->create([
            'department_id' => $this->deptSE->id,
            'semester' => 3,
            'title' => 'SE Sem 3 Exam',
            'created_by' => User::factory()->create()->id
        ]);

        $examWrongSem = Exam::factory()->create([
            'department_id' => $this->deptCS->id,
            'semester' => 4,
            'title' => 'CS Sem 4 Exam',
            'created_by' => User::factory()->create()->id
        ]);

        $response = $this->actingAs($candidate)->getJson('/api/exams');
        $response->assertStatus(200);
        $response->assertJsonCount(1, 'exams');
        $response->assertJsonFragment(['id' => $examCorrect->id]);
        $response->assertJsonMissing(['id' => $examWrongDept->id]);
        $response->assertJsonMissing(['id' => $examWrongSem->id]);
    }

    public function test_candidate_unauthorized_direct_access(): void
    {
        $candidate = User::factory()->create([
            'role' => 'candidate',
            'department_id' => $this->deptCS->id,
            'semester' => 3
        ]);

        $examSE = Exam::factory()->create([
            'department_id' => $this->deptSE->id,
            'semester' => 3,
            'created_by' => User::factory()->create()->id
        ]);

        // GET detail
        $response = $this->actingAs($candidate)->getJson("/api/exams/{$examSE->id}");
        $response->assertStatus(403);

        // POST session
        $response = $this->actingAs($candidate)->postJson("/api/exams/{$examSE->id}/session");
        $response->assertStatus(403);
    }

    public function test_legacy_null_department_exams_are_hidden_from_candidates(): void
    {
        $candidate = User::factory()->create([
            'role' => 'candidate',
            'department_id' => $this->deptCS->id,
            'semester' => 1
        ]);

        $examNull = Exam::factory()->create([
            'department_id' => null,
            'semester' => null,
            'title' => 'Untargeted Exam',
            'created_by' => User::factory()->create()->id
        ]);

        $response = $this->actingAs($candidate)->getJson('/api/exams');
        $response->assertJsonCount(0, 'exams');

        $response = $this->actingAs($candidate)->getJson("/api/exams/{$examNull->id}");
        $response->assertStatus(403);
    }

    public function test_examiner_exam_list_filtered_by_department(): void
    {
        $examinerCS = User::factory()->create([
            'role' => 'examiner',
            'department_id' => $this->deptCS->id
        ]);

        $examCS = Exam::factory()->create([
            'department_id' => $this->deptCS->id,
            'created_by' => $examinerCS->id
        ]);

        $examSE = Exam::factory()->create([
            'department_id' => $this->deptSE->id,
            'created_by' => User::factory()->create()->id
        ]);

        $response = $this->actingAs($examinerCS)->getJson('/api/exams');
        $response->assertStatus(200);
        $response->assertJsonCount(1, 'exams');
        $response->assertJsonFragment(['id' => $examCS->id]);
        $response->assertJsonMissing(['id' => $examSE->id]);
    }
}
