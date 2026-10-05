<?php

namespace App\Services;

use App\Exceptions\AiProviderException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Service for generating exam questions using Google Gemini API.
 */
class AiQuestionGeneratorService
{
    private const ALLOWED_DIFFICULTIES = ['easy', 'medium', 'hard'];

    private const ALLOWED_BLOOM_LEVELS = [
        'remember', 'understand', 'apply', 'analyze', 'evaluate', 'create',
    ];

    private const ALLOWED_TYPES = ['mcq', 'true_false', 'short_answer', 'essay'];

    public function generate(array $params): array
    {
        $apiKey = config('services.gemini.key');

        if (empty($apiKey)) {
            throw new AiProviderException(
                'The AI provider is not configured. Set GEMINI_API_KEY in the backend .env file.',
            );
        }

        $response = $this->callGemini($apiKey, $params);
        $rawQuestions = $this->extractQuestions($response);

        $validated = [];
        foreach ($rawQuestions as $raw) {
            $question = $this->validateAndNormalize($raw, $params['question_type']);
            if ($question !== null) {
                $validated[] = $question;
            }
        }

        if (empty($validated)) {
            throw new AiProviderException(
                'The AI provider did not return any usable questions. Please try again.',
            );
        }

        return $validated;
    }

    private function callGemini(string $apiKey, array $params): array
    {
        $schema = [
            'type' => 'OBJECT',
            'properties' => [
                'questions' => [
                    'type' => 'ARRAY',
                    'items' => [
                        'type' => 'OBJECT',
                        'properties' => [
                            'question_text' => ['type' => 'STRING'],
                            'marks' => ['type' => 'INTEGER'],
                            'difficulty' => [
                                'type' => 'STRING',
                                'enum' => self::ALLOWED_DIFFICULTIES,
                            ],
                            'bloom_taxonomy' => [
                                'type' => 'STRING',
                                'enum' => self::ALLOWED_BLOOM_LEVELS,
                            ],
                            'topic_tag' => ['type' => 'STRING'],
                            'options' => [
                                'type' => 'ARRAY',
                                'items' => ['type' => 'STRING'],
                                'nullable' => true,
                            ],
                            'correct_answer' => ['type' => 'STRING', 'nullable' => true],
                        ],
                        'required' => [
                            'question_text', 'marks', 'difficulty',
                            'bloom_taxonomy', 'topic_tag', 'options', 'correct_answer',
                        ],
                    ],
                ],
            ],
            'required' => ['questions'],
        ];

        $typeInstructions = match ($params['question_type']) {
            'mcq' => 'Each question must have "options": an array of exactly 4 distinct plausible answer strings, '
                . 'and "correct_answer": the exact text of one of those options.',
            'true_false' => 'Each question must have "options": null, and "correct_answer": exactly "True" or "False".',
            'short_answer' => 'Each question must have "options": null, and "correct_answer": a concise correct model answer.',
            'essay' => 'Each question must have "options": null and "correct_answer": null.',
            default => '',
        };

        $bloomInstructions = match ($params['bloom_taxonomy']) {
            'remember' => 'Focus on recall of facts, definitions, or basic concepts.',
            'understand' => 'Focus on explaining ideas or concepts, summarizing, or classifying.',
            'apply' => 'Focus on using information in new situations or solving problems.',
            'analyze' => 'Focus on drawing connections among ideas, breaking down information, or identifying patterns.',
            'evaluate' => 'Focus on justifying a stand or decision, critiquing, or appraising.',
            'create' => 'Focus on producing new or original work, designing, or assembling.',
            default => '',
        };

        $isContentBased = isset($params['content']);
        $sourceType = $isContentBased ? 'course content excerpt' : 'course/topic';
        $sourceValue = $isContentBased ? $params['content'] : $params['topic'];

        $prompt = sprintf(
            "You are an academic question author. Generate %d exam question(s) for a Computer/IT course exam.\n"
                . "%s: %s\n"
                . "Question type: %s\n"
                . "Difficulty: %s\n"
                . "Bloom's Taxonomy level: %s (%s)\n"
                . "Marks per question: %d\n\n"
                . "%s\n"
                . "\"topic_tag\" should be a short tag summarizing the specific sub-topic covered.\n"
                . "Return only the JSON object described by the response schema.",
            $params['count'],
            $sourceType,
            $sourceValue,
            $params['question_type'],
            $params['difficulty'],
            $params['bloom_taxonomy'],
            $bloomInstructions,
            $params['marks'],
            $typeInstructions,
        );

        $model = config('services.gemini.model');

        try {
            $response = Http::withHeaders([
                'x-goog-api-key' => $apiKey,
                'content-type' => 'application/json',
            ])
                ->timeout(60)
                ->retry(2, 2000)
                ->post("https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent", [
                    'contents' => [
                        ['role' => 'user', 'parts' => [['text' => $prompt]]],
                    ],
                    'generationConfig' => [
                        'responseMimeType' => 'application/json',
                        'responseSchema' => $schema,
                    ],
                ]);
        } catch (Throwable $e) {
            Log::warning('AI question generation request failed', ['error' => $e->getMessage()]);
            throw new AiProviderException('Could not reach the AI provider. Please try again.');
        }

        if ($response->failed()) {
            Log::warning('AI question generation returned an error', [
                'status' => $response->status(),
                'body' => $response->body(),
            ]);
            throw new AiProviderException('The AI provider returned an error. Please try again.');
        }

        return $response->json() ?? [];
    }

    private function extractQuestions(array $response): array
    {
        $text = $response['candidates'][0]['content']['parts'][0]['text'] ?? null;

        if (is_string($text)) {
            $decoded = json_decode($text, true);
            if (is_array($decoded) && isset($decoded['questions']) && is_array($decoded['questions'])) {
                return $decoded['questions'];
            }
        }

        throw new AiProviderException('The AI provider response did not contain any questions.');
    }

    private function validateAndNormalize(mixed $raw, string $expectedType): ?array
    {
        if (!is_array($raw)) {
            return null;
        }

        $text = trim((string) ($raw['question_text'] ?? ''));
        if ($text === '') {
            return null;
        }

        $marks = $raw['marks'] ?? null;
        if (!is_int($marks) || $marks < 1 || $marks > 100) {
            return null;
        }

        $difficulty = $raw['difficulty'] ?? null;
        if (!in_array($difficulty, self::ALLOWED_DIFFICULTIES, true)) {
            return null;
        }

        $bloom = $raw['bloom_taxonomy'] ?? null;
        if (!in_array($bloom, self::ALLOWED_BLOOM_LEVELS, true)) {
            return null;
        }

        if (!in_array($expectedType, self::ALLOWED_TYPES, true)) {
            return null;
        }

        $topicTag = trim((string) ($raw['topic_tag'] ?? '')) ?: null;
        $options = $raw['options'] ?? null;
        $correctAnswer = $raw['correct_answer'] ?? null;
        $correctAnswer = is_string($correctAnswer) ? trim($correctAnswer) : null;

        if ($expectedType === 'mcq') {
            if (!is_array($options) || count($options) < 2) {
                return null;
            }
            $options = array_values(array_map(static fn ($o) => trim((string) $o), $options));
            $normalized = array_map('mb_strtolower', $options);
            if (count($normalized) !== count(array_unique($normalized))) {
                return null;
            }
            if ($correctAnswer === null || !in_array($correctAnswer, $options, true)) {
                return null;
            }
        } elseif ($expectedType === 'true_false') {
            $options = null;
            if (!in_array($correctAnswer, ['True', 'False'], true)) {
                return null;
            }
        } elseif ($expectedType === 'short_answer') {
            $options = null;
            if ($correctAnswer === null || $correctAnswer === '') {
                return null;
            }
        } else {
            $options = null;
            $correctAnswer = null;
        }

        return [
            'question_text' => $text,
            'question_type' => $expectedType,
            'marks' => $marks,
            'difficulty' => $difficulty,
            'bloom_taxonomy' => $bloom,
            'topic_tag' => $topicTag,
            'options' => $options,
            'correct_answer' => $correctAnswer,
            'is_ai_generated' => true,
        ];
    }
}
