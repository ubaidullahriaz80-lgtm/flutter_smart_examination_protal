<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ExamSession;
use Barryvdh\DomPDF\Facade\Pdf;
use Illuminate\Http\Exceptions\HttpResponseException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Response;
use App\Models\LearningGapReport;
use App\Models\Exam;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;
use Illuminate\Support\Collection;

/**
 * Controller for PDF/Excel export of exam results and cohort summaries.
 */
class ResultExportController extends Controller
{
    public function pdf(Request $request, ExamSession $session)
    {
        $data = $this->buildExportData($request, $session);

        $pdf = Pdf::loadView('exports.result-pdf', ['data' => $data]);

        return $pdf->download("fsep-result-{$session->id}.pdf");
    }

    public function excel(Request $request, ExamSession $session)
    {
        $data = $this->buildExportData($request, $session);

        $spreadsheet = new Spreadsheet();

        $summary = $spreadsheet->getActiveSheet();
        $summary->setTitle('Summary');
        $summary->fromArray([
            ['Field', 'Value'],
            ['Candidate', $data['candidate_name']],
            ['Candidate Email', $data['candidate_email']],
            ['Exam', $data['exam_title']],
            ['Course Code', $data['course_code'] ?? 'N/A'],
            ['Session ID', $data['session_id']],
            ['Submission Status', ucfirst($data['submission_status'])],
            ['Total Marks', $data['total_score']],
            ['Max Marks', $data['max_score']],
            ['Percentage', $data['percentage']],
            ['Result Status', $data['result_status'] === 'pending_manual_review' ? 'Pending Manual Review' : 'Graded'],
            ['Graded At', $data['graded_at']],
        ], null, 'A1');
        foreach (range('A', 'B') as $col) {
            $summary->getColumnDimension($col)->setAutoSize(true);
        }

        if (!empty($data['learning_gaps'])) {
            $gapSheet = $spreadsheet->createSheet();
            $gapSheet->setTitle('Learning Gaps');
            $gapSheet->fromArray([
                ['Topic', 'Score (%)', 'Severity', 'Remediation Suggestion'],
            ], null, 'A1');
            $row = 2;
            foreach ($data['learning_gaps'] as $gap) {
                $gapSheet->fromArray([
                    $gap['topic'],
                    $gap['mastery'],
                    ucfirst($gap['severity']),
                    $gap['suggestion']
                ], null, "A{$row}");
                $row++;
            }
            foreach (range('A', 'D') as $col) {
                $gapSheet->getColumnDimension($col)->setAutoSize(true);
            }
        }

        $details = $spreadsheet->createSheet();
        $details->setTitle('Question Details');
        $details->fromArray([
            ['Question ID', 'Question Type', 'Max Marks', 'Obtained Marks', 'Correctness', 'Review Status'],
        ], null, 'A1');
        $row = 2;
        foreach ($data['questions'] as $q) {
            $correctness = $q['is_correct'] === null
                ? 'N/A'
                : ($q['is_correct'] ? 'Correct' : 'Incorrect');
            $details->fromArray([
                $q['question_id'],
                $q['question_type'],
                $q['max_marks'],
                $q['obtained_marks'],
                $correctness,
                $q['grading_status'] === 'pending_manual_review' ? 'Pending Manual Review' : 'Graded',
            ], null, "A{$row}");
            $row++;
        }
        foreach (range('A', 'F') as $col) {
            $details->getColumnDimension($col)->setAutoSize(true);
        }

        $spreadsheet->setActiveSheetIndex(0);

        $writer = new Xlsx($spreadsheet);
        $fileName = "fsep-result-{$session->id}.xlsx";

        return Response::streamDownload(function () use ($writer) {
            $writer->save('php://output');
        }, $fileName, [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ]);
    }

    public function cohortExcel(Request $request, Exam $exam)
    {
        $this->authorizeStaff($request);

        $sessions = $exam->sessions()
            ->where('status', 'submitted')
            ->with(['candidate', 'result', 'learningGapReport'])
            ->get();

        $spreadsheet = new Spreadsheet();
        $sheet = $spreadsheet->getActiveSheet();
        $sheet->setTitle('Cohort Results');

        $headers = ['Candidate Name', 'Email', 'Score', 'Max', '%', 'Status', 'Pass/Fail', 'Percentile', 'Weak Topics'];
        $sheet->fromArray([$headers], null, 'A1');

        $row = 2;
        foreach ($sessions as $session) {
            $result = $session->result;
            if (!$result) continue;

            $percentage = $result->max_score > 0 ? round(($result->total_score / $result->max_score) * 100, 1) : 0;
            $passFail = ($percentage >= $exam->pass_percentage) ? 'Pass' : 'Fail';

            $cohortScores = \App\Models\Result::whereHas('examSession', function($q) use ($exam) {
                $q->where('exam_id', $exam->id);
            })->where('status', 'graded')->pluck('total_score');

            $atOrBelow = $cohortScores->filter(fn($s) => $s <= $result->total_score)->count();
            $percentile = $cohortScores->count() > 0 ? round(($atOrBelow / $cohortScores->count()) * 100, 1) : 100;

            $weakTopics = collect($session->learningGapReport?->learning_gaps ?? [])
                ->pluck('topic')
                ->implode(', ');

            $sheet->fromArray([
                $session->candidate->name,
                $session->candidate->email,
                $result->total_score,
                $result->max_score,
                $percentage,
                $result->status,
                $passFail,
                $percentile,
                $weakTopics
            ], null, "A{$row}");
            $row++;
        }

        foreach (range('A', 'I') as $col) {
            $sheet->getColumnDimension($col)->setAutoSize(true);
        }

        $writer = new Xlsx($spreadsheet);
        $fileName = "fsep-cohort-{$exam->id}.xlsx";

        return Response::streamDownload(function () use ($writer) {
            $writer->save('php://output');
        }, $fileName, [
            'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ]);
    }

    public function cohortPdf(Request $request, Exam $exam)
    {
        $this->authorizeStaff($request);

        $sessions = $exam->sessions()
            ->where('status', 'submitted')
            ->with(['candidate', 'result', 'learningGapReport'])
            ->get();

        $data = [
            'exam_title' => $exam->title,
            'course_code' => $exam->course_code,
            'generated_at' => now()->format('Y-m-d H:i:s'),
            'results' => $sessions->map(function($s) use ($exam) {
                $percentage = $s->result->max_score > 0 ? round(($s->result->total_score / $s->result->max_score) * 100, 1) : 0;
                return [
                    'name' => $s->candidate->name,
                    'email' => $s->candidate->email,
                    'score' => $s->result->total_score,
                    'percentage' => $percentage,
                    'pass_fail' => ($percentage >= $exam->pass_percentage) ? 'Pass' : 'Fail',
                    'weak_topics' => collect($s->learningGapReport?->learning_gaps ?? [])->pluck('topic')->take(3)->implode(', ')
                ];
            })
        ];

        $pdf = Pdf::loadView('exports.cohort-pdf', $data);
        return $pdf->download("fsep-cohort-{$exam->id}.pdf");
    }

    private function authorizeStaff(Request $request)
    {
        if (!in_array($request->user()->role, ['examiner', 'system_administrator'], true)) {
            throw new HttpResponseException(response()->json([
                'message' => 'This action is unauthorized.',
            ], 403));
        }
    }

    private function buildExportData(Request $request, ExamSession $session): array
    {
        $user = $request->user();
        $isOwner = $session->candidate_id === $user->id;
        $isStaff = in_array($user->role, ['examiner', 'system_administrator'], true);

        if (!$isOwner && !$isStaff) {
            throw new HttpResponseException(response()->json([
                'message' => 'This action is unauthorized.',
            ], 403));
        }

        $result = $session->result;
        if ($result === null) {
            throw new HttpResponseException(response()->json([
                'message' => 'No result is available yet for this session.',
            ], 404));
        }

        $session->loadMissing(['exam', 'candidate', 'answers.question', 'learningGapReport']);

        $percentage = $result->max_score > 0
            ? round(($result->total_score / $result->max_score) * 100, 1)
            : 0;

        return [
            'session_id' => $session->id,
            'candidate_name' => $session->candidate->name,
            'candidate_email' => $session->candidate->email,
            'exam_title' => $session->exam->title,
            'course_code' => $session->exam->course_code,
            'submission_status' => $session->status,
            'total_score' => $result->total_score,
            'max_score' => $result->max_score,
            'percentage' => $percentage,
            'result_status' => $result->status,
            'graded_at' => optional($result->graded_at)->format('Y-m-d H:i:s') ?? 'N/A',
            'generated_at' => now()->format('Y-m-d H:i:s'),
            'learning_gaps' => $session->learningGapReport?->improvement_roadmap ?? [],
            'questions' => $session->answers->map(fn ($answer) => [
                'question_id' => $answer->question_id,
                'question_type' => $answer->question?->question_type ?? 'unknown',
                'max_marks' => $answer->question?->marks ?? 0,
                'obtained_marks' => $answer->obtained_marks,
                'is_correct' => $answer->is_correct,
                'grading_status' => $answer->grading_status,
            ])->values()->all(),
        ];
    }
}
