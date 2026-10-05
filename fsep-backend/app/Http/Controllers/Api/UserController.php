<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;

/**
 * Controller for user management operations by System Administrators.
 */
class UserController extends Controller
{
    private const ALLOWED_ROLES = [
        'system_administrator',
        'institutional_administrator',
        'examiner',
        'live_invigilator',
        'candidate',
    ];

    public function index()
    {
        return response()->json([
            'users' => UserResource::collection(User::all()),
        ]);
    }

    public function store(Request $request)
    {
        $user = $request->user();

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8'],
            'role' => ['required', 'string', Rule::in(self::ALLOWED_ROLES)],
            'department_id' => ['nullable', 'exists:departments,id'],
            'semester' => ['nullable', 'integer', 'min:1', 'max:8'],
        ]);

        if ($user->role === 'institutional_administrator' &&
            in_array($validated['role'], ['system_administrator', 'institutional_administrator'])) {
            return response()->json(['message' => 'Unauthorized to create administrative roles.'], 403);
        }

        $user = User::create([
            'name' => $validated['name'],
            'email' => $validated['email'],
            'password' => Hash::make($validated['password']),
            'department_id' => $validated['department_id'] ?? null,
            'semester' => $validated['semester'] ?? null,
        ]);

        $user->role = $validated['role'];
        $user->save();

        return response()->json([
            'user' => new UserResource($user),
        ], 201);
    }

    public function update(Request $request, User $user)
    {
        $authenticatedUser = $request->user();

        if ($authenticatedUser->role === 'institutional_administrator' &&
            in_array($user->role, ['system_administrator', 'institutional_administrator'])) {
            return response()->json(['message' => 'Unauthorized to modify administrative roles.'], 403);
        }

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => [
                'required',
                'email',
                'max:255',
                Rule::unique('users', 'email')->ignore($user->id),
            ],
            'role' => ['required', 'string', Rule::in(self::ALLOWED_ROLES)],
            'department_id' => ['nullable', 'exists:departments,id'],
            'semester' => ['nullable', 'integer', 'min:1', 'max:8'],
        ]);

        $user->name = $validated['name'];
        $user->email = $validated['email'];
        $user->role = $validated['role'];
        $user->department_id = $validated['department_id'] ?? $user->department_id;
        $user->semester = $validated['semester'] ?? $user->semester;
        $user->save();

        return response()->json([
            'user' => new UserResource($user),
        ]);
    }

    public function destroy(Request $request, User $user)
    {
        $authenticatedUser = $request->user();

        if ($user->id === $authenticatedUser->id) {
            return response()->json([
                'message' => 'You cannot delete your own account.',
            ], 422);
        }

        if ($authenticatedUser->role === 'institutional_administrator' &&
            in_array($user->role, ['system_administrator', 'institutional_administrator'])) {
            return response()->json(['message' => 'Unauthorized to delete administrative roles.'], 403);
        }

        $hasDependentData = $user->createdExams()->exists()
            || $user->createdQuestions()->exists()
            || $user->examSessions()->exists();

        if ($hasDependentData) {
            return response()->json([
                'message' => 'This user cannot be deleted because associated exam/session data exists.',
            ], 422);
        }

        $user->delete();

        return response()->json(null, 204);
    }

    public function import(Request $request)
    {
        $request->validate([
            'file' => ['required', 'file', 'mimes:csv,txt'],
        ]);

        $handle = fopen($request->file('file')->getRealPath(), 'r');
        if ($handle === false) {
            return response()->json(['message' => 'Could not read the uploaded file.'], 422);
        }

        $header = fgetcsv($handle);
        if ($header === false) {
            fclose($handle);

            return response()->json(['message' => 'The CSV file is empty.'], 422);
        }

        $columns = array_map(fn ($h) => strtolower(trim((string) $h)), $header);
        $missingColumns = array_diff(['name', 'email', 'password', 'role'], $columns);
        if (!empty($missingColumns)) {
            fclose($handle);

            return response()->json([
                'message' => 'The CSV is missing required columns: '.implode(', ', $missingColumns).'.',
            ], 422);
        }

        $imported = [];
        $errors = [];
        $rowNumber = 1;

        $globalDepartmentId = $request->input('department_id');
        $globalSemester = $request->input('semester');

        $departmentCache = [];

        while (($row = fgetcsv($handle)) !== false) {
            $rowNumber++;

            $isBlank = count(array_filter($row, fn ($v) => trim((string) $v) !== '')) === 0;
            if ($isBlank) {
                continue;
            }

            $data = [];
            foreach ($columns as $index => $column) {
                $data[$column] = trim((string) ($row[$index] ?? ''));
            }

            if (isset($data['department_code']) && (!isset($data['department_id']) || $data['department_id'] === '')) {
                $code = strtoupper($data['department_code']);
                if (!isset($departmentCache[$code])) {
                    $dept = \App\Models\Department::where('code', $code)->first();
                    $departmentCache[$code] = $dept ? $dept->id : null;
                }
                $data['department_id'] = $departmentCache[$code];
            }

            $data['department_id'] = (isset($data['department_id']) && $data['department_id'] !== '')
                ? $data['department_id']
                : $globalDepartmentId;

            $data['semester'] = (isset($data['semester']) && $data['semester'] !== '')
                ? $data['semester']
                : $globalSemester;

            $validator = Validator::make($data, [
                'name' => ['required', 'string', 'max:255'],
                'email' => ['required', 'email', 'max:255', 'unique:users,email'],
                'password' => ['required', 'string', 'min:8'],
                'role' => ['required', 'string', Rule::in(self::ALLOWED_ROLES)],
                'department_id' => ['nullable', 'exists:departments,id'],
                'semester' => ['nullable', 'integer', 'min:1', 'max:8'],
            ]);

            if ($validator->fails()) {
                $errors[] = [
                    'row' => $rowNumber,
                    'message' => $validator->errors()->first(),
                ];
                continue;
            }

            $validated = $validator->validated();

            $user = User::create([
                'name' => $validated['name'],
                'email' => $validated['email'],
                'password' => Hash::make($validated['password']),
                'department_id' => $validated['department_id'] ?? null,
                'semester' => $validated['semester'] ?? null,
            ]);
            $user->role = $validated['role'];
            $user->save();

            $imported[] = new UserResource($user);
        }

        fclose($handle);

        return response()->json([
            'imported_count' => count($imported),
            'failed_count' => count($errors),
            'imported' => $imported,
            'errors' => $errors,
        ]);
    }
}
