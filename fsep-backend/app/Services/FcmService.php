<?php

namespace App\Services;

use App\Models\User;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;
use Kreait\Laravel\Firebase\Facades\Firebase;
use Throwable;

class FcmService
{
    /**
     * Sends a push notification to all registered devices of a user.
     */
    public function sendToUser(User $user, string $title, string $body, array $data = []): void
    {
        $tokens = $user->deviceTokens()->pluck('token')->toArray();

        if (empty($tokens)) {
            return;
        }

        $notification = Notification::create($title, $body);
        $message = CloudMessage::new()
            ->withNotification($notification)
            ->withData($data);

        foreach ($tokens as $token) {
            try {
                Firebase::messaging()->send($message->withTarget('token', $token));
            } catch (Throwable $e) {
                // If a token is invalid/unregistered, we should probably delete it
                if (str_contains($e->getMessage(), 'unregistered') || str_contains($e->getMessage(), 'invalid')) {
                    $user->deviceTokens()->where('token', $token)->delete();
                }
                \Log::error("FCM sending failed for token: " . $token . " Error: " . $e->getMessage());
            }
        }
    }

    /**
     * Sends a push notification to multiple users.
     */
    public function sendToUsers($users, string $title, string $body, array $data = []): void
    {
        foreach ($users as $user) {
            $this->sendToUser($user, $title, $body, $data);
        }
    }
}
