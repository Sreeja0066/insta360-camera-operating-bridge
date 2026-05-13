import 'dart:convert';

// ─────────────────────────────────────────────
// Enums
// ─────────────────────────────────────────────

enum ExportStatus { pending, exporting, done, failed }

enum DriveStatus { pending, uploading, done, failed, notStarted }

// ─────────────────────────────────────────────
// RecordingModel
// ─────────────────────────────────────────────

class RecordingModel {
  final String id;
  final String timestamp;
  final int duration;
  final String resolution;
  final String stabilization;
  final Map<String, dynamic>? startPoint;
  final Map<String, dynamic>? stopPoint;

  // Export fields
  final List<String> rawFilePaths;
  final ExportStatus exportStatus;
  final int exportProgress;
  final String? exportedPath4K;
  final String? exportedPath1080P;

  // Drive fields
  final DriveStatus driveStatus;
  final String? driveFileId;

  const RecordingModel({
    required this.id,
    required this.timestamp,
    required this.duration,
    this.resolution = 'Unknown',
    this.stabilization = 'FlowState',
    this.startPoint,
    this.stopPoint,
    this.rawFilePaths = const [],
    this.exportStatus = ExportStatus.pending,
    this.exportProgress = 0,
    this.exportedPath4K,
    this.exportedPath1080P,
    this.driveStatus = DriveStatus.notStarted,
    this.driveFileId,
  });

  // ─────────────────────────────────────────────
  // Derived helpers
  // ─────────────────────────────────────────────

  bool get canExport =>
      rawFilePaths.isNotEmpty &&
      exportStatus != ExportStatus.exporting &&
      exportStatus != ExportStatus.done;

  bool get canWatch =>
      exportStatus == ExportStatus.done &&
      (exportedPath1080P != null || exportedPath4K != null);

  String get watchPath => exportedPath1080P ?? exportedPath4K ?? '';

  bool get canUploadToDrive =>
      canWatch &&
      driveStatus != DriveStatus.done &&
      driveStatus != DriveStatus.uploading;

  String get exportStatusLabel {
    switch (exportStatus) {
      case ExportStatus.pending:
        return rawFilePaths.isEmpty ? 'No File' : 'Ready to Export';
      case ExportStatus.exporting:
        return 'Exporting $exportProgress%';
      case ExportStatus.done:
        return 'Exported ✓';
      case ExportStatus.failed:
        return 'Export Failed';
    }
  }

  String get driveStatusLabel {
    switch (driveStatus) {
      case DriveStatus.notStarted:
        return '';
      case DriveStatus.pending:
        return '☁️ Upload queued';
      case DriveStatus.uploading:
        return '☁️ Uploading...';
      case DriveStatus.done:
        return '☁️ Uploaded ✓';
      case DriveStatus.failed:
        return '☁️ Upload failed';
    }
  }

  // ─────────────────────────────────────────────
  // Serialization
  // ─────────────────────────────────────────────

  factory RecordingModel.fromJson(Map<String, dynamic> json) {
    return RecordingModel(
      id: json['id'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      duration: json['duration'] as int? ?? 0,
      resolution: json['resolution'] as String? ?? 'Unknown',
      stabilization: json['stabilization'] as String? ?? 'FlowState',
      startPoint: json['startPoint'] as Map<String, dynamic>?,
      stopPoint: json['stopPoint'] as Map<String, dynamic>?,
      rawFilePaths: (json['rawFilePaths'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      exportStatus: _parseExportStatus(json['exportStatus'] as String?),
      exportProgress: json['exportProgress'] as int? ?? 0,
      exportedPath4K: json['exportedPath4K'] as String?,
      exportedPath1080P: json['exportedPath1080P'] as String?,
      driveStatus: _parseDriveStatus(json['driveStatus'] as String?),
      driveFileId: json['driveFileId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp,
      'duration': duration,
      'resolution': resolution,
      'stabilization': stabilization,
      'startPoint': startPoint,
      'stopPoint': stopPoint,
      'rawFilePaths': rawFilePaths,
      'exportStatus': exportStatus.name,
      'exportProgress': exportProgress,
      'exportedPath4K': exportedPath4K,
      'exportedPath1080P': exportedPath1080P,
      'driveStatus': driveStatus.name,
      'driveFileId': driveFileId,
    };
  }

  // ─────────────────────────────────────────────
  // CopyWith — for updating individual fields
  // ─────────────────────────────────────────────

  RecordingModel copyWith({
    String? id,
    String? timestamp,
    int? duration,
    String? resolution,
    String? stabilization,
    Map<String, dynamic>? startPoint,
    Map<String, dynamic>? stopPoint,
    List<String>? rawFilePaths,
    ExportStatus? exportStatus,
    int? exportProgress,
    String? exportedPath4K,
    String? exportedPath1080P,
    DriveStatus? driveStatus,
    String? driveFileId,
  }) {
    return RecordingModel(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      duration: duration ?? this.duration,
      resolution: resolution ?? this.resolution,
      stabilization: stabilization ?? this.stabilization,
      startPoint: startPoint ?? this.startPoint,
      stopPoint: stopPoint ?? this.stopPoint,
      rawFilePaths: rawFilePaths ?? this.rawFilePaths,
      exportStatus: exportStatus ?? this.exportStatus,
      exportProgress: exportProgress ?? this.exportProgress,
      exportedPath4K: exportedPath4K ?? this.exportedPath4K,
      exportedPath1080P: exportedPath1080P ?? this.exportedPath1080P,
      driveStatus: driveStatus ?? this.driveStatus,
      driveFileId: driveFileId ?? this.driveFileId,
    );
  }

  // ─────────────────────────────────────────────
  // Private parsers
  // ─────────────────────────────────────────────

  static ExportStatus _parseExportStatus(String? value) {
    switch (value) {
      case 'exporting':
        return ExportStatus.exporting;
      case 'done':
        return ExportStatus.done;
      case 'failed':
        return ExportStatus.failed;
      default:
        return ExportStatus.pending;
    }
  }

  static DriveStatus _parseDriveStatus(String? value) {
    switch (value) {
      case 'pending':
        return DriveStatus.pending;
      case 'uploading':
        return DriveStatus.uploading;
      case 'done':
        return DriveStatus.done;
      case 'failed':
        return DriveStatus.failed;
      default:
        return DriveStatus.notStarted;
    }
  }
}

// ─────────────────────────────────────────────
// RecordingRepository
// Handles in-memory cache of recordings,
// synced with native JSON via Insta360Service
// ─────────────────────────────────────────────

class RecordingRepository {
  static final RecordingRepository instance = RecordingRepository._();
  RecordingRepository._();

  // In-memory cache — kept in sync with native JSON
  List<RecordingModel> _recordings = [];
  List<RecordingModel> get recordings => List.unmodifiable(_recordings);

  // ─────────────────────
  // Load from native
  // ─────────────────────

  Future<List<RecordingModel>> loadFromNative(
      Future<List<dynamic>> Function() nativeGetRecordings) async {
    try {
      final raw = await nativeGetRecordings();
      _recordings = raw
          .whereType<Map<String, dynamic>>()
          .map((j) => RecordingModel.fromJson(j))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return _recordings;
    } catch (e) {
      return [];
    }
  }

  // ─────────────────────
  // Update export status
  // (called from event handlers)
  // ─────────────────────

  void updateExportProgress(String id, int progress) {
    _updateById(id, (r) => r.copyWith(
          exportStatus: ExportStatus.exporting,
          exportProgress: progress,
        ));
  }

  void updateExportSuccess(String id, String path, String resolution) {
    _updateById(id, (r) {
      final is4K = resolution.toLowerCase().contains('4k');
      return r.copyWith(
        exportStatus: ExportStatus.done,
        exportProgress: 100,
        exportedPath4K: is4K ? path : r.exportedPath4K,
        exportedPath1080P: !is4K ? path : r.exportedPath1080P,
        driveStatus: DriveStatus.pending,
      );
    });
  }

  void updateExportFailed(String id) {
    _updateById(id, (r) => r.copyWith(
          exportStatus: ExportStatus.failed,
        ));
  }

  void updateDriveStatus(String id, DriveStatus status, {String? fileId}) {
    _updateById(id, (r) => r.copyWith(
          driveStatus: status,
          driveFileId: fileId ?? r.driveFileId,
        ));
  }

  void updateRawFilePaths(String id, List<String> paths) {
    _updateById(id, (r) => r.copyWith(
          rawFilePaths: paths,
        ));
  }

  RecordingModel? getById(String id) {
    try {
      return _recordings.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  RecordingModel? get lastRecording =>
      _recordings.isNotEmpty ? _recordings.first : null;

  void _updateById(
      String id, RecordingModel Function(RecordingModel) updater) {
    final idx = _recordings.indexWhere((r) => r.id == id);
    if (idx != -1) {
      _recordings[idx] = updater(_recordings[idx]);
    }
  }
}
