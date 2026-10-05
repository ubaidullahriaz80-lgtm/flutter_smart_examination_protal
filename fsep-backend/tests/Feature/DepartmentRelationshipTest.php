<?php

namespace Tests\Feature;

use App\Models\Department;
use App\Models\Exam;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DepartmentRelationshipTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_belongs_to_department(): void
    {
        $dept = Department::create(['name' => 'Computer Science', 'code' => 'CS']);
        $user = User::factory()->create(['department_id' => $dept->id]);

        $this->assertEquals('Computer Science', $user->department->name);
        $this->assertTrue($dept->users->contains($user));
    }

    public function test_exam_belongs_to_department(): void
    {
        $dept = Department::create(['name' => 'Software Engineering', 'code' => 'SE']);
        $exam = Exam::factory()->create(['department_id' => $dept->id, 'created_by' => User::factory()->create()->id]);

        $this->assertEquals('Software Engineering', $exam->department->name);
        $this->assertTrue($dept->exams->contains($exam));
    }

    public function test_examiner_can_only_manage_exams_in_their_department(): void
    {
        $deptCS = Department::create(['name' => 'Computer Science', 'code' => 'CS']);
        $deptSE = Department::create(['name' => 'Software Engineering', 'code' => 'SE']);

        $examinerCS = User::factory()->create(['role' => 'examiner', 'department_id' => $deptCS->id]);
        $examCS = Exam::factory()->create(['department_id' => $deptCS->id, 'created_by' => $examinerCS->id]);
        $examSE = Exam::factory()->create(['department_id' => $deptSE->id, 'created_by' => User::factory()->create(['role' => 'examiner', 'department_id' => $deptSE->id])->id]);

        // List exams
        $response = $this->actingAs($examinerCS)->getJson('/api/exams');
        $response->assertStatus(200);
        $response->assertJsonCount(1, 'exams');
        $response->assertJsonFragment(['id' => $examCS->id]);
        $response->assertJsonMissing(['id' => $examSE->id]);

        // View another department's exam
        $response = $this->actingAs($examinerCS)->getJson("/api/exams/{$examSE->id}");
        $response->assertStatus(403);

        // Update another department's exam
        $response = $this->actingAs($examinerCS)->putJson("/api/exams/{$examSE->id}", ['title' => 'Hacked']);
        $response->assertStatus(403);

        // Delete another department's exam
        $response = $this->actingAs($examinerCS)->deleteJson("/api/exams/{$examSE->id}");
        $response->assertStatus(403);
    }

    public function test_system_admin_can_manage_all_departments(): void
    {
        $deptCS = Department::create(['name' => 'Computer Science', 'code' => 'CS']);
        $deptSE = Department::create(['name' => 'Software Engineering', 'code' => 'SE']);

        $admin = User::factory()->create(['role' => 'system_administrator']);
        $examCS = Exam::factory()->create(['department_id' => $deptCS->id, 'created_by' => $admin->id]);
        $examSE = Exam::factory()->create(['department_id' => $deptSE->id, 'created_by' => $admin->id]);

        $response = $this->actingAs($admin)->getJson('/api/exams');
        $response->assertStatus(200);
        $response->assertJsonCount(2, 'exams');
    }

    public function test_student_assignment_validation(): void
    {
        $admin = User::factory()->create(['role' => 'system_administrator']);
        $dept = Department::create(['name' => 'CS', 'code' => 'CS']);

        $response = $this->actingAs($admin)->postJson('/api/users', [
            'name' => 'Student',
            'email' => 'student@test.com',
            'password' => 'password123',
            'role' => 'candidate',
            'department_id' => $dept->id,
            'semester' => 3
        ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('users', [
            'email' => 'student@test.com',
            'department_id' => $dept->id,
            'semester' => 3
        ]);

        // Invalid semester
        $response = $this->actingAs($admin)->postJson('/api/users', [
            'name' => 'Student 2',
            'email' => 'student2@test.com',
            'password' => 'password123',
            'role' => 'candidate',
            'semester' => 9
        ]);
        $response->assertStatus(422);
    }
}
