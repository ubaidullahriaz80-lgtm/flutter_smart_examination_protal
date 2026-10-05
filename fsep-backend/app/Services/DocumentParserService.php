<?php

namespace App\Services;

use App\Models\AiQuestionGenerationJob;
use Exception;
use Illuminate\Support\Facades\Storage;
use Smalot\PdfParser\Parser;

/**
 * Service for parsing uploaded syllabus/course documents into text chunks.
 */
class DocumentParserService
{
    private const TARGET_CHUNK_CHARS = 4000;
    private const OVERLAP_CHARS = 400;

    public function parse(AiQuestionGenerationJob $job): void
    {
        $job->update(['status' => 'PARSING']);

        try {
            $allChunks = [];
            $directory = "private/generation_docs/{$job->id}";
            $files = Storage::files($directory);

            if (empty($files)) {
                throw new Exception("No files found for job {$job->id}.");
            }

            foreach ($files as $filePath) {
                $extension = pathinfo($filePath, PATHINFO_EXTENSION);
                $originalName = basename($filePath);

                $text = '';
                if (strtolower($extension) === 'pdf') {
                    $text = $this->extractPdfText($filePath);
                } elseif (strtolower($extension) === 'txt') {
                    $text = $this->extractTxtText($filePath);
                }

                $text = $this->cleanText($text);

                if (empty($text)) {
                    continue;
                }

                $chunks = $this->chunkText($text);
                foreach ($chunks as $chunkText) {
                    $allChunks[] = [
                        'source' => $originalName,
                        'content' => $chunkText,
                    ];
                }
            }

            if (empty($allChunks)) {
                throw new Exception("No usable text could be extracted from the uploaded documents.");
            }

            $job->update([
                'chunks' => $allChunks,
                'status' => 'GENERATING',
            ]);

        } catch (Exception $e) {
            $job->update([
                'status' => 'FAILED',
                'last_error' => $e->getMessage(),
                'failed_at' => now(),
            ]);
        }
    }

    private function extractPdfText(string $path): string
    {
        $parser = new Parser();
        $fullPath = Storage::path($path);
        $pdf = $parser->parseFile($fullPath);
        return $pdf->getText();
    }

    private function extractTxtText(string $path): string
    {
        return Storage::get($path) ?? '';
    }

    private function cleanText(string $text): string
    {
        $text = preg_replace('/\s+/', ' ', $text);
        return trim($text);
    }

    private function chunkText(string $text): array
    {
        if (strlen($text) <= self::TARGET_CHUNK_CHARS) {
            return [$text];
        }

        $chunks = [];
        $start = 0;
        $textLen = strlen($text);

        while ($start < $textLen) {
            $end = $start + self::TARGET_CHUNK_CHARS;

            if ($end >= $textLen) {
                $chunks[] = substr($text, $start);
                break;
            }

            $breakPoint = strrpos(substr($text, 0, $end), ' ');
            if ($breakPoint === false || $breakPoint <= $start) {
                $breakPoint = $end;
            }

            $chunks[] = substr($text, $start, $breakPoint - $start);

            $start = $breakPoint - self::OVERLAP_CHARS;
            if ($start < 0) $start = 0;

            if ($start >= $breakPoint) {
                $start = $breakPoint + 1;
            }
        }

        return $chunks;
    }
}
