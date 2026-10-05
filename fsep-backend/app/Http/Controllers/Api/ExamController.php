<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ExamResource;
use App\Models\Exam;
use App\Models\User;
use App\Services\FcmService;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ExamController extends Controller
{
    private const STATUSES = ['draft', 'published', 'closed'];

    public function index(Request $request)
    {
        $query = Exam::query();
        $user = $request->user();

        if ($user->role === 'candidate') {
            $platform = $request->header('X-App-Platform');
            $query->where(function ($q) use ($platform) {
                $q->whereNull('allowed_platforms')
                  ->orWhereJsonContains('allowed_platforms', $platform);
            });

            $query->where('department_id', $user->department_id)
                  ->where('semester', $user->semester);
        }

        if ($user->role === 'examiner') {
            $query->where('department_id', $user->department_id);
        }

        $exams = $query->with(['questions' => fn ($query) => $this->scopeQuestionsToRole($query, $request)])->get();

        return response()->json([
            'exams' => ExamResource::collection($exams),
        ]);
    }

    public function show(Request $request, Exam $exam)
    {
        $user = $request->user();

        if ($user->role === 'candidate' && $exam->allowed_platforms !== null) {
            $platform = $request->header('X-App-Platform');
            if (!in_array($platform, $exam->allowed_platforms)) {
                return response()->json(['message' => 'This exam is not available on your platform.'], 403);
            }
        }

        if ($user->role === 'candidate') {
            if ($exam->department_id !== $user->department_id || $exam->semester !== $user->semester) {
                return response()->json(['message' => 'This exam is not available for your department or semester.'], 403);
            }
        }

        if ($user->role === 'examiner' && $exam->department_id !== $user->department_id) {
            return response()->json(['message' => 'This exam does not belong to your department.'], 403);
        }

        $exam->load(['questions' => fn ($query) => $this->scopeQuestionsToRole($query, $request)]);

        return response()->json([
            'exam' => new ExamResource($exam),
        ]);
    }

    private function scopeQuestionsToRole($query, Request $request)
    {
        $query->when(
            $request->user()->role === 'candidate',
            fn ($q) => $q->where('review_status', 'approved'),
        );
    }

    public function store(Request $request, FcmService $fcm)
    {
        $user = $request->user();
        $validated = $request->validate($this->rules(user: $user));

        $data = $validated + [
            'created_by' => $user->id,
            'status' => $validated['status'] ?? 'draft',
        ];

        if ($user->role === 'examiner') {
            $data['department_id'] = $user->department_id;
        }

        $exam = Exam::create($data);

        if ($exam->status === 'published') {
            $this->notifyCandidatesOfNewExam($exam, $fcm);
        }

        return response()->json([
            'exam' => new ExamResource($exam),
        ], 201);
    }

    public function update(Request $request, Exam $exam, FcmService $fcm)
    {
        $user = $request->user();

        if ($user->role === 'examiner' && $exam->department_id !== $user->department_id) {
            return response()->json(['message' => 'This action is unauthorized.'], 403);
        }

        $validated = $request->validate($this->rules(id: $exam->id, user: $user));

        $oldStatus = $exam->status;

        $data = $validated + [
            'status' => $validated['status'] ?? $exam->status,
        ];

        if ($user->role === 'examiner') {
            $data['department_id'] = $user->department_id;
        }

        $exam->update($data);

        if ($oldStatus !== 'published' && $exam->status === 'published') {
            $this->notifyCandidatesOfNewExam($exam, $fcm);
        }

        return response()->json([
            'exam' => new ExamResource($exam->fresh()),
        ]);
    }

    private function notifyCandidatesOfNewExam(Exam $exam, FcmService $fcm): void
    {
        $title = "New Exam Available";
        $body = "The exam '{$exam->title}' is now available for attempts.";

        $candidates = User::where('role', 'candidate')->get();
        $fcm->sendToUsers($candidates, $title, $body, [
            'type' => 'exam_available',
            'exam_id' => (string) $exam->id,
        ]);
    }

    public function destroy(Request $request, Exam $exam)
    {
        $user = $request->user();

        if ($user->role === 'examiner' && $exam->department_id !== $user->department_id) {
            return response()->json(['message' => 'This action is unauthorized.'], 403);
        }

        if ($exam->sessions()->exists()) {
            return response()->json([
                'message' => 'This exam cannot be deleted because candidates have already started or submitted sessions for it.',
            ], 422);
        }

        $exam->delete();

        return response()->json(null, 204);
    }

    private function rules(?int $id = null, ?User $user = null): array
    {
        $rules = [
            'title' => [
                'required',
                'string',
                'max:255',
                'regex:/^[a-zA-Z0-9\s\-_]+$/',
                Rule::unique('exams', 'title')->ignore($id),
            ],
            'description' => ['nullable', 'string'],
            'course_code' => ['nullable', 'string', 'max:50'],
            'duration_minutes' => ['required', 'integer', 'min:1'],
            'total_marks' => ['required', 'numeric', 'min:0'],
            'negative_marking_weight' => ['required', 'numeric', 'min:0', 'max:1'],
            'pass_percentage' => ['sometimes', 'numeric', 'min:0', 'max:100'],
            'status' => ['sometimes', 'string', Rule::in(self::STATUSES)],
            'allowed_platforms' => ['nullable', 'array'],
            'allowed_platforms.*' => ['string', Rule::in(['android', 'ios', 'windows', 'macos', 'linux', 'web'])],
            'bcd_enabled' => ['sometimes', 'boolean'],
            'randomize_questions' => ['sometimes', 'boolean'],
            'shuffle_choices' => ['sometimes', 'boolean'],
            'is_offline_ready' => ['sometimes', 'boolean'],
            'semester' => ['nullable', 'integer', 'min:1', 'max:8'],
            'starts_at' => ['nullable', 'date'],
            'ends_at' => ['nullable', 'date', 'after:starts_at'],
        ];

        if ($user && in_array($user->role, ['system_administrator', 'institutional_administrator'], true)) {
            $rules['department_id'] = ['nullable', 'exists:departments,id'];
        }

        return $rules;
    }
}
