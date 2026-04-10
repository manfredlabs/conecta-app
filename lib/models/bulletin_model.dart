import 'package:cloud_firestore/cloud_firestore.dart';

class Bulletin {
  final String id;
  final String title;
  final String fileName;
  final String fileUrl;
  final String storagePath;
  final String fileType; // pdf, docx, doc
  final String? churchId;
  final String uploadedBy;
  final DateTime weekStart; // segunda-feira da semana
  final DateTime createdAt;

  Bulletin({
    required this.id,
    required this.title,
    required this.fileName,
    required this.fileUrl,
    required this.storagePath,
    required this.fileType,
    this.churchId,
    required this.uploadedBy,
    required this.weekStart,
    required this.createdAt,
  });

  factory Bulletin.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Bulletin(
      id: doc.id,
      title: data['title'] ?? '',
      fileName: data['fileName'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      storagePath: data['storagePath'] ?? '',
      fileType: data['fileType'] ?? 'pdf',
      churchId: data['churchId'],
      uploadedBy: data['uploadedBy'] ?? '',
      weekStart: (data['weekStart'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'storagePath': storagePath,
      'fileType': fileType,
      'churchId': churchId,
      'uploadedBy': uploadedBy,
      'weekStart': Timestamp.fromDate(weekStart),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Retorna a segunda-feira da semana atual (00:00)
  static DateTime currentWeekStart() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateTime(monday.year, monday.month, monday.day);
  }

  /// Verifica se este boletim é da semana atual
  bool get isCurrentWeek {
    final mondayNow = currentWeekStart();
    return weekStart.year == mondayNow.year &&
        weekStart.month == mondayNow.month &&
        weekStart.day == mondayNow.day;
  }

  /// Formato legível da semana: "07/04 - 13/04"
  String get weekLabel {
    final end = weekStart.add(const Duration(days: 6));
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(weekStart.day)}/${pad(weekStart.month)} - ${pad(end.day)}/${pad(end.month)}';
  }
}
