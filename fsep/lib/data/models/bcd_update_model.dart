class BcdUpdateModel {
  const BcdUpdateModel({
    required this.sessionId,
    required this.candidateId,
    required this.candidateName,
    required this.riskScore,
    required this.riskBand,
    required this.computedAt,
    this.isAlert = false,
    this.eventBreakdown,
    this.latestEvents = const [],
  });

  final int sessionId;
  final int candidateId;
  final String candidateName;
  final int riskScore;
  final String riskBand;
  final DateTime computedAt;
  final bool isAlert;
  final Map<String, dynamic>? eventBreakdown;
  final List<Map<String, dynamic>> latestEvents;

  factory BcdUpdateModel.fromJson(Map<String, dynamic> json) {
    return BcdUpdateModel(
      sessionId: json['session_id'] as int,
      candidateId: json['candidate_id'] as int,
      candidateName: json['candidate_name'] as String,
      riskScore: json['risk_score'] as int,
      riskBand: json['risk_band'] as String,
      computedAt: DateTime.parse(json['computed_at'] as String),
      isAlert: json['is_alert'] == true,
      eventBreakdown: json['event_breakdown'] as Map<String, dynamic>?,
      latestEvents: (json['latest_events'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
    );
  }
}
