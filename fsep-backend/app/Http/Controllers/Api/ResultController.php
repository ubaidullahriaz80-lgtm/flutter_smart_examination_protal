<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ResultResource;
use App\Models\ExamSession;
use Illuminate\Http\Request;

/**
 * Grading + Results pipeline: read access to a session's persisted
 * result. Grading itself happens in GradingService, triggered from
 * ExamSessionController::submit().
 */
class ResultController extends Controller
{
    /**
     * GET /api/results/{session}
     *
     * Candidates may only view their own session's result; examiner/
     * system administrator may view any (same coarse RBAC already used
     * for behavior-events — no per-resource ownership system for staff).
     */
    public function show(Request $request, ExamSession $session)
    {
        $user = $request->user();
        $isOwner = $session->candidate_id === $user->id;
        $isStaff = in_array($user->role, ['examiner', 'system_administrator'], true);

        if (!$isOwner && !$isStaff) {
            return response()->json([
                'message' => 'This action is unauthorized.',
            ], 403);
        }

        $result = $session->result;

        if ($result === null) {
            return response()->json([
                'message' => 'No result is available yet for this session.',
            ], 404);
        }

        return response()->json([
            'result' => new ResultResource($result),
        ]);
    }
}
