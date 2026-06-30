class Turn {
  final String user;
  final String aura;
  final DateTime ts;
  const Turn({required this.user, required this.aura, required this.ts});

  factory Turn.fromJson(Map<String, dynamic> j) => Turn(
    user: j['user'] as String? ?? '',
    aura: j['aura'] as String? ?? '',
    ts: DateTime.fromMillisecondsSinceEpoch(
      ((j['ts'] as num?) ?? 0).toInt() * 1000,
    ),
  );
}

class Summary {
  final int id;
  final String sessionId;
  final DateTime createdAt;
  final String topicLabel;
  final String content;

  const Summary({
    required this.id,
    required this.sessionId,
    required this.createdAt,
    required this.topicLabel,
    required this.content,
  });

  factory Summary.fromJson(Map<String, dynamic> j) => Summary(
    id: (j['id'] as num?)?.toInt() ?? 0,
    sessionId: j['session_id'] as String? ?? '',
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      ((j['created_at'] as num?) ?? 0).toInt() * 1000,
    ),
    topicLabel: j['topic_label'] as String? ?? '',
    content: j['content'] as String? ?? '',
  );
}

class Fact {
  final String key;
  final String value;
  final DateTime updatedAt;

  const Fact({
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  factory Fact.fromJson(Map<String, dynamic> j) => Fact(
    key: j['key'] as String? ?? '',
    value: j['value'] as String? ?? '',
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      ((j['updated_at'] as num?) ?? 0).toInt() * 1000,
    ),
  );
}
