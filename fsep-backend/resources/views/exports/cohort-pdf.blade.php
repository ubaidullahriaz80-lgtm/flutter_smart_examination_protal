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
        .section-title { font-size: 14px; font-weight: bold; margin: 16px 0 6px; }
        .footer { margin-top: 20px; font-size: 10px; color: #888; }
    </style>
</head>
<body>
    <h1>FSEP — Cohort Assessment Report</h1>
    <div class="subtitle">Exam: {{ $exam_title }} {{ $course_code ? "($course_code)" : "" }}</div>

    <div class="section-title">Candidate Performance & Learning Gaps</div>
    <table>
        <thead>
            <tr>
                <th>Candidate Name</th>
                <th>Email</th>
                <th>Score</th>
                <th>%</th>
                <th>Result</th>
                <th>Top Weak Topics</th>
            </tr>
        </thead>
        <tbody>
            @foreach ($results as $r)
                <tr>
                    <td>{{ $r['name'] }}</td>
                    <td>{{ $r['email'] }}</td>
                    <td>{{ number_format($r['score'], 2) }}</td>
                    <td>{{ $r['percentage'] }}%</td>
                    <td>{{ $r['pass_fail'] }}</td>
                    <td>{{ $r['weak_topics'] ?: 'None' }}</td>
                </tr>
            @endforeach
        </tbody>
    </table>

    <div class="footer">Generated {{ $generated_at }}</div>
</body>
</html>
