<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Explicit, safe user representation for the System Administrator's User
 * Management module. password and remember_token are never included.
 */
class UserResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'email' => $this->email,
            'role' => $this->role,
            'department_id' => $this->department_id,
            'semester' => $this->semester,
            'department' => new DepartmentResource($this->whenLoaded('department')),
        ];
    }
}
