<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\ExamQuestionConfigurationResource;
use App\Models\Exam;
use App\Models\ExamQuestionConfiguration;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class ExamQuestionConfigurationController extends Controller
{
    private const TYPES = ['mcq', 'true_false', 'short_answer', 'essay', 'matching', 'code_snippet'];
    private const BLOOM_LEVELS = ['remember', 'understand', 'apply', 'analyze', 'evaluate', 'create'];

    public function index(Exam $exam)
    {
        $this->authorizeManage($exam);

        return response()->json([
            'question_configurations' => ExamQuestionConfigurationResource::collection($exam->questionConfigurations),
        ]);
    }

    public function sync(Request $request, Exam $exam)
    {
        $this->authorizeManage($exam);

        $validated = $request->validate([
            'configurations' => ['required', 'array'],
            'configurations.*.question_type' => ['required', 'string', Rule::in(self::TYPES)],
            'configurations.*.question_count' => ['required', 'integer', 'min:1'],
            'configurations.*.bloom_taxonomy' => ['required', 'string', Rule::in(self::BLOOM_LEVELS)],
            'configurations.*.marks' => ['required', 'numeric', 'min:0'],
        ]);

        $exam->questionConfigurations()->delete();

        foreach ($validated['configurations'] as $config) {
            $exam->questionConfigurations()->create($config);
        }

        return response()->json([
            'question_configurations' => ExamQuestionConfigurationResource::collection($exam->fresh()->questionConfigurations),
        ]);
    }

    public function store(Request $request, Exam $exam)
    {
        $this->authorizeManage($exam);

        $validated = $request->validate([
            'question_type' => ['required', 'string', Rule::in(self::TYPES)],
            'question_count' => ['required', 'integer', 'min:1'],
            'bloom_taxonomy' => ['required', 'string', Rule::in(self::BLOOM_LEVELS)],
            'marks' => ['required', 'numeric', 'min:0'],
        ]);

        $config = $exam->questionConfigurations()->create($validated);

        return response()->json([
            'question_configuration' => new ExamQuestionConfigurationResource($config),
        ], 201);
    }

    public function update(Request $request, Exam $exam, ExamQuestionConfiguration $configuration)
    {
        $this->authorizeManage($exam);

        if ($configuration->exam_id !== $exam->id) {
            return response()->json(['message' => 'Configuration does not belong to this exam.'], 422);
        }

        $validated = $request->validate([
            'question_type' => ['sometimes', 'required', 'string', Rule::in(self::TYPES)],
            'question_count' => ['sometimes', 'required', 'integer', 'min:1'],
            'bloom_taxonomy' => ['sometimes', 'required', 'string', Rule::in(self::BLOOM_LEVELS)],
            'marks' => ['sometimes', 'required', 'numeric', 'min:0'],
        ]);

        $configuration->update($validated);

        return response()->json([
            'question_configuration' => new ExamQuestionConfigurationResource($configuration),
        ]);
    }

    public function destroy(Exam $exam, ExamQuestionConfiguration $configuration)
    {
        $this->authorizeManage($exam);

        if ($configuration->exam_id !== $exam->id) {
            return response()->json(['message' => 'Configuration does not belong to this exam.'], 422);
        }

        $configuration->delete();

        return response()->json(null, 204);
    }

    private function authorizeManage(Exam $exam)
    {
        $user = auth()->user();
        if ($user->role === 'examiner' && $exam->department_id !== $user->department_id) {
            abort(403, 'This exam does not belong to your department.');
        }
        // Admin access is handled by middleware 'role:examiner' being shared or just existing sanctum check here?
        // Actually, the route will be wrapped in 'role:examiner' which usually includes examiners only.
        // I should check if administrators can access examiner routes.
    }
}
