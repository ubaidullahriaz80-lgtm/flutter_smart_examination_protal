<?php

namespace App\Services;

use Exception;
use Illuminate\Support\Facades\Log;
use Symfony\Component\Process\Process;

/**
 * Service for executing submitted candidate code in an isolated Docker sandbox.
 */
class CodeExecutionService
{
    private const SUPPORTED_LANGUAGES = ['python'];
    private const TIMEOUT = 10;
    private const MEMORY_LIMIT = '64m';
    private const CPU_LIMIT = '0.5';

    public function execute(string $code, string $language, array $testCases): array
    {
        if (!in_array(strtolower($language), self::SUPPORTED_LANGUAGES)) {
            throw new Exception("Language '$language' is not supported for automated grading.");
        }

        $results = [];

        foreach ($testCases as $index => $testCase) {
            $results[] = $this->runTestCase($code, $language, $testCase);
        }

        return $results;
    }

    public function isDockerAvailable(): bool
    {
        $process = new Process(['docker', '--version']);
        $process->run();
        return $process->isSuccessful();
    }

    private function runTestCase(string $code, string $language, array $testCase): array
    {
        $input = $testCase['input'] ?? '';
        $expected = trim($testCase['expected_output'] ?? '');

        if (config('app.env') === 'testing' && !$this->isDockerAvailable()) {
            return $this->mockLocalExecution($code, $input, $expected);
        }

        $image = 'python:3.9-slim';
        $encodedCode = base64_encode($code);
        $command = [
            'docker', 'run', '--rm', '-i',
            '--net=none',
            '--memory=' . self::MEMORY_LIMIT,
            '--cpus=' . self::CPU_LIMIT,
            $image,
            'python3', '-c', "import base64; exec(base64.b64decode('$encodedCode'))"
        ];

        $process = new Process($command);
        $process->setInput($input);
        $process->setTimeout(self::TIMEOUT);

        $start = microtime(true);
        try {
            $process->run();
            $duration = round(microtime(true) - $start, 3);

            $output = trim($process->getOutput());
            $error = trim($process->getErrorOutput());

            if (!$process->isSuccessful()) {
                return [
                    'passed' => false,
                    'error' => $error ?: 'Execution failed with code ' . $process->getExitCode(),
                    'stdout' => $output,
                    'stderr' => $error,
                    'exit_code' => $process->getExitCode(),
                    'duration' => $duration,
                ];
            }

            return [
                'passed' => $output === $expected,
                'stdout' => $output,
                'stderr' => $error,
                'expected' => $expected,
                'exit_code' => 0,
                'duration' => $duration,
            ];

        } catch (Exception $e) {
            return [
                'passed' => false,
                'error' => 'Execution timed out or failed: ' . $e->getMessage(),
            ];
        }
    }

    private function mockLocalExecution(string $code, string $input, string $expected): array
    {
        $passed = str_contains($code, $expected);
        return [
            'passed' => $passed,
            'stdout' => $passed ? $expected : 'Incorrect output',
            'stderr' => '',
            'expected' => $expected,
            'exit_code' => $passed ? 0 : 1,
            'duration' => 0.001,
            'is_mock' => true
        ];
    }
}
