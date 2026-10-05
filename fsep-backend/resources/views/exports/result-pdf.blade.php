<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body { font-family: Helvetica, Arial, sans-serif; font-size: 12px; color: #222; }
        h1 { font-size: 18px; margin-bottom: 0; }
        .subtitle { color: #666; margin-top: 2px; margin-bottom: 18px; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 16px; }
        th, td { border: 1px solid #ccc; padding: 6px 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .summary-table td:first-child { font-weight: bold; width: 35%; }
        .section-title { font-size: 14px; font-weight: bold; margin: 16px 0 6px; }
        .status-pending { color: #b45309; font-style: italic; }
        .footer { margin-top: 20px; font-size: 10px; color: #888; }
    </style>
</head>
<body>
    <h1>FSEP — Exam Result Report</h1>
    <div class="subtitle">Flutter Smart Examination Portal</div>

    <table class="summary-table">
        <tr><td>Candidate</td><td>{{ $data['candidate_name'] }} ({{ $data['candidate_email'] }})</td></tr>
        <tr><td>Exam</td><td>{{ $data['exam_title'] }}</td></tr>
        <tr><td>Course Code</td><td>{{ $data['course_code'] ?? 'N/A' }}</td></tr>
        <tr><td>Session ID</td><td>{{ $data['session_id'] }}</td></tr>
        <tr><td>Submission Status</td><td>{{ ucfirst($data['submission_status']) }}</td></tr>
        <tr><td>Total Marks</td><td>{{ number_format($data['total_score'], 2) }} / {{ number_format($data['max_score'], 2) }}</td></tr>
        <tr><td>Percentage</td><td>{{ $data['percentage'] }}%</td></tr>
        <tr>
            <td>Result Status</td>
            <td class="{{ $data['result_status'] === 'pending_manual_review' ? 'status-pending' : '' }}">
                {{ $data['result_status'] === 'pending_manual_review' ? 'Pending Manual Review' : 'Graded' }}
            </td>
        </tr>
        <tr><td>Graded At</td><td>{{ $data['graded_at'] }}</td></tr>
    </table>

    @if (!empty($data['learning_gaps']))
    <div class="section-title">Learning Gap Summary</div>
    <table>
        <thead>
            <tr>
                <th>Topic</th>
                <th>Score (%)</th>
                <th>Severity</th>
                <th>Remediation Suggestion</th>
            </tr>
        </thead>
        <tbody>
            @foreach ($data['learning_gaps'] as $gap)
                <tr>
                    <td>{{ $gap['topic'] }}</td>
                    <td>{{ $gap['mastery'] }}%</td>
                    <td>{{ ucfirst($gap['severity']) }}</td>
                    <td>{{ $gap['suggestion'] }}</td>
                </tr>
            @endforeach
        </tbody>
    </table>
    @endif

    <div class="section-title">Per-Question Breakdown</div>
    <table>
        <thead>
            <tr>
                <th>Question ID</th>
                <th>Type</th>
                <th>Max Marks</th>
                <th>Obtained Marks</th>
                <th>Correctness</th>
                <th>Review Status</th>
            </tr>
        </thead>
        <tbody>
            @foreach ($data['questions'] as $q)
                <tr>
                    <td>{{ $q['question_id'] }}</td>
                    <td>{{ $q['question_type'] }}</td>
                    <td>{{ number_format($q['max_marks'], 2) }}</td>
                    <td>{{ $q['obtained_marks'] !== null ? number_format($q['obtained_marks'], 2) : '—' }}</td>
                    <td>
                        @if ($q['is_correct'] === null)
                            —
                        @elseif ($q['is_correct'])
                            Correct
                        @else
                            Incorrect
                        @endif
                    </td>
                    <td>{{ $q['grading_status'] === 'pending_manual_review' ? 'Pending Manual Review' : 'Graded' }}</td>
                </tr>
            @endforeach
        </tbody>
    </table>

    <div class="footer">Generated {{ $data['generated_at'] }}</div>
</body>
</html>
