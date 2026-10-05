<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AnalyticsController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\ExamController;
use App\Http\Controllers\Api\ExamSessionController;
use App\Http\Controllers\Api\LearningGapController;
use App\Http\Controllers\Api\QuestionController;
use App\Http\Controllers\Api\ResultController;
use App\Http\Controllers\Api\ResultExportController;
use App\Http\Controllers\Api\UserController;

Route::post('/auth/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {

    Route::get('/user', function (Request $request) {
        return $request->user();
    });

    Route::post('/device-tokens', [App\Http\Controllers\Api\DeviceTokenController::class, 'store']);
    Route::delete('/device-tokens', [App\Http\Controllers\Api\DeviceTokenController::class, 'destroy']);

    Route::get('/exams', [ExamController::class, 'index']);
    Route::get('/exams/{exam}', [ExamController::class, 'show']);
    Route::get('/departments', [App\Http\Controllers\Api\DepartmentController::class, 'index']);
});

// Exam Administration (create/edit/delete)
Route::middleware(['auth:sanctum', 'role:examiner,institutional_administrator'])->group(function () {
    Route::post('/exams', [ExamController::class, 'store']);
    Route::put('/exams/{exam}', [ExamController::class, 'update']);
    Route::delete('/exams/{exam}', [ExamController::class, 'destroy']);
});

// System Administrator User Management
Route::middleware(['auth:sanctum', 'role:system_administrator,institutional_administrator'])->group(function () {
    Route::apiResource('users', UserController::class);
    Route::post('/users/import', [UserController::class, 'import']);
    Route::apiResource('departments', App\Http\Controllers\Api\DepartmentController::class);
});

// Candidate exam delivery & session routes
Route::middleware(['auth:sanctum', 'role:candidate'])->group(function () {
    Route::post('/exams/{exam}/session', [ExamSessionController::class, 'startOrResume']);
    Route::put('/exam-sessions/{session}/answers/{question}', [ExamSessionController::class, 'saveAnswer']);
    Route::post('/exam-sessions/{session}/answers/sync', [ExamSessionController::class, 'syncAnswers']);
    Route::post('/exam-sessions/{session}/submit', [ExamSessionController::class, 'submit']);

    Route::get('/learning-gaps', [LearningGapController::class, 'index']);
    Route::get('/learning/history', [LearningGapController::class, 'history']);
    Route::get('/learning/report/{session}', [LearningGapController::class, 'show']);

    Route::post('/exam-sessions/{session}/behavior-events', [ExamSessionController::class, 'recordBehaviorEvent']);
    Route::post('/exam-sessions/{session}/behavior-events/sync', [ExamSessionController::class, 'syncBehaviorEvents']);
});

// Live Invigilator monitoring overview
Route::middleware(['auth:sanctum', 'role:examiner,system_administrator,live_invigilator,institutional_administrator'])->group(function () {
    Route::get('/exam-sessions', [ExamSessionController::class, 'activeSessions']);
    Route::get('/exams/{exam}/behavioral-dashboard', [ExamSessionController::class, 'behavioralDashboard']);
    Route::get('/exams/{exam}/behavioral-alerts', [ExamSessionController::class, 'behavioralAlerts']);
    Route::post('/behavioral/review', [ExamSessionController::class, 'reviewBehavioralEvent']);
});

// Behavioral Cheating Detection event monitoring
Route::middleware(['auth:sanctum', 'role:candidate,examiner,system_administrator,live_invigilator'])->group(function () {
    Route::get('/exam-sessions/{session}/behavior-events', [ExamSessionController::class, 'behaviorEvents']);
});

Route::middleware(['auth:sanctum', 'role:candidate,examiner,system_administrator'])->group(function () {
    Route::get('/results/{session}', [ResultController::class, 'show']);
    Route::get('/results/{session}/pdf', [ResultExportController::class, 'pdf']);
    Route::get('/results/{session}/excel', [ResultExportController::class, 'excel']);
});

// Cohort and institutional analytics
Route::middleware(['auth:sanctum', 'role:examiner,system_administrator,institutional_administrator'])->group(function () {
    Route::get('/analytics/cohort', [AnalyticsController::class, 'cohort']);
    Route::get('/exams/{exam}/export/pdf', [ResultExportController::class, 'cohortPdf']);
    Route::get('/exams/{exam}/export/excel', [ResultExportController::class, 'cohortExcel']);
});

Route::middleware(['auth:sanctum', 'role:system_administrator,institutional_administrator'])->group(function () {
    Route::get('/analytics/institutional', [App\Http\Controllers\Api\InstitutionalAnalyticsController::class, 'overview']);
});

// Question Bank and AI Question Generator routes
Route::middleware(['auth:sanctum', 'role:examiner'])->group(function () {
    Route::post('/questions/generate', [QuestionController::class, 'generate']);
    Route::post('/questions/generate/upload', [QuestionController::class, 'upload']);
    Route::post('/questions/generate/approve', [QuestionController::class, 'bulkReview']);
    Route::get('/questions/generate/job/{job}', [QuestionController::class, 'showJob']);
    Route::get('/questions/generate/review/{job}', [QuestionController::class, 'reviewQueue']);
    Route::get('/questions', [QuestionController::class, 'index']);
    Route::post('/questions', [QuestionController::class, 'store']);
    Route::put('/questions/{question}', [QuestionController::class, 'update']);
    Route::delete('/questions/{question}', [QuestionController::class, 'destroy']);

    Route::post('/exams/{exam}/question-configurations/sync', [App\Http\Controllers\Api\ExamQuestionConfigurationController::class, 'sync']);
    Route::apiResource('exams.question-configurations', App\Http\Controllers\Api\ExamQuestionConfigurationController::class);

    Route::get('/exam-sessions/{session}/answers/{question}/manual-grade', [ExamSessionController::class, 'pendingAnswer']);
    Route::put('/exam-sessions/{session}/answers/{question}/manual-grade', [ExamSessionController::class, 'manualGrade']);
});
