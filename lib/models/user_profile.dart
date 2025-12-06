class UserProfile {
  final String uid;
  final String name;
  final int age;
  final String sex;
  final List<String> medicalProblems;
  final double? lastHeartRate;
  final String? lastDiagnosis;
  final DateTime? lastDiagnosisDate;
  final List<DiagnosisRecord> diagnosisHistory;

  UserProfile({
    required this.uid,
    required this.name,
    required this.age,
    required this.sex,
    required this.medicalProblems,
    this.lastHeartRate,
    this.lastDiagnosis,
    this.lastDiagnosisDate,
    this.diagnosisHistory = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'age': age,
      'sex': sex,
      'medicalProblems': medicalProblems,
      'lastHeartRate': lastHeartRate,
      'lastDiagnosis': lastDiagnosis,
      'lastDiagnosisDate': lastDiagnosisDate?.toIso8601String(),
      'diagnosisHistory': diagnosisHistory.map((d) => d.toJson()).toList(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      name: json['name'] as String,
      age: json['age'] as int,
      sex: json['sex'] as String,
      medicalProblems: List<String>.from(json['medicalProblems'] ?? []),
      lastHeartRate: json['lastHeartRate'] as double?,
      lastDiagnosis: json['lastDiagnosis'] as String?,
      lastDiagnosisDate: json['lastDiagnosisDate'] != null
          ? DateTime.parse(json['lastDiagnosisDate'] as String)
          : null,
      diagnosisHistory: (json['diagnosisHistory'] as List?)
              ?.map((d) => DiagnosisRecord.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DiagnosisRecord {
  final String diagnosis;
  final double heartRate;
  final DateTime timestamp;
  final String? notes;

  DiagnosisRecord({
    required this.diagnosis,
    required this.heartRate,
    required this.timestamp,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'diagnosis': diagnosis,
      'heartRate': heartRate,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
    };
  }

  factory DiagnosisRecord.fromJson(Map<String, dynamic> json) {
    return DiagnosisRecord(
      diagnosis: json['diagnosis'] as String,
      heartRate: (json['heartRate'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      notes: json['notes'] as String?,
    );
  }
}
