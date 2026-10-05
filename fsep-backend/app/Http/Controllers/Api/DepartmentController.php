<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\DepartmentResource;
use App\Models\Department;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class DepartmentController extends Controller
{
    /**
     * GET /api/departments
     */
    public function index()
    {
        return response()->json([
            'departments' => DepartmentResource::collection(Department::all()),
        ]);
    }

    /**
     * POST /api/departments
     */
    public function store(Request $request)
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255', 'unique:departments,name'],
            'code' => ['required', 'string', 'max:50', 'unique:departments,code'],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $department = Department::create($validated);

        return response()->json([
            'department' => new DepartmentResource($department),
        ], 201);
    }

    /**
     * PUT /api/departments/{department}
     */
    public function update(Request $request, Department $department)
    {
        $validated = $request->validate([
            'name' => [
                'required',
                'string',
                'max:255',
                Rule::unique('departments', 'name')->ignore($department->id),
            ],
            'code' => [
                'required',
                'string',
                'max:50',
                Rule::unique('departments', 'code')->ignore($department->id),
            ],
            'is_active' => ['sometimes', 'boolean'],
        ]);

        $department->update($validated);

        return response()->json([
            'department' => new DepartmentResource($department),
        ]);
    }

    /**
     * DELETE /api/departments/{department}
     */
    public function destroy(Department $department)
    {
        // Safety: check if users or exams belong to this department
        if ($department->users()->exists() || $department->exams()->exists()) {
            return response()->json([
                'message' => 'Cannot delete department with associated users or exams.',
            ], 422);
        }

        $department->delete();

        return response()->json(null, 204);
    }
}
