<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Department;
use App\Models\Exam;
use App\Models\ExamSession;
use App\Models\Result;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class InstitutionalAnalyticsController extends Controller
{
    public function overview()
    {
        $totalDepartments = Department::count();
        $totalFaculty = User::where('role', 'examiner')->count();
        $totalStudents = User::where('role', 'candidate')->count();
        $activeExams = Exam::where('status', 'published')->count();

        // Performance by Department
        $departmentPerformance = Department::with(['exams.sessions' => function ($query) {
            $query->where('status', 'submitted')->whereHas('result');
        }, 'exams.sessions.result'])->get()->map(function ($dept) {
            $sessions = $dept->exams->flatMap->sessions;
            $results = $sessions->pluck('result');

            $averagePercentage = $results->isEmpty() ? 0 : round($results->map(function ($r) {
                return $r->max_score > 0 ? ($r->total_score / $r->max_score) * 100 : 0;
            })->avg(), 1);

            return [
                'department_id' => $dept->id,
                'name' => $dept->name,
                'code' => $dept->code,
                'student_count' => $dept->users()->where('role', 'candidate')->count(),
                'exam_count' => $dept->exams()->count(),
                'average_percentage' => $averagePercentage,
            ];
        });

        return response()->json([
            'overview' => [
                'total_departments' => $totalDepartments,
                'total_faculty' => $totalFaculty,
                'total_students' => $totalStudents,
                'active_exams' => $activeExams,
            ],
            'department_performance' => $departmentPerformance,
        ]);
    }
}
