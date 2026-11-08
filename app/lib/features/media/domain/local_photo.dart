enum LocalPhotoStage { queued, uploading, processing, ready, failed, removing }

class LocalPhoto {
  const LocalPhoto({
    required this.id,
    required this.ownerId,
    required this.bytes,
    required this.sha256,
    required this.createdAt,
    required this.reserveKey,
    required this.confirmKey,
    required this.removeKey,
    this.stage = LocalPhotoStage.queued,
    this.uploaded = false,
    this.failure,
    this.progress,
  });
  final String id;
  final String ownerId;
  final int bytes;
  final String sha256;
  final DateTime createdAt;
  final String reserveKey;
  final String confirmKey;
  final String removeKey;
  final LocalPhotoStage stage;
  final bool uploaded;
  final String? failure;
  final double? progress;

  LocalPhoto copyWith({
    LocalPhotoStage? stage,
    bool? uploaded,
    String? failure,
    double? progress,
  }) => LocalPhoto(
    id: id,
    ownerId: ownerId,
    bytes: bytes,
    sha256: sha256,
    createdAt: createdAt,
    reserveKey: reserveKey,
    confirmKey: confirmKey,
    removeKey: removeKey,
    stage: stage ?? this.stage,
    uploaded: uploaded ?? this.uploaded,
    failure: failure,
    progress: progress,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ownerId': ownerId,
    'bytes': bytes,
    'sha256': sha256,
    'createdAt': createdAt.toIso8601String(),
    'reserveKey': reserveKey,
    'confirmKey': confirmKey,
    'removeKey': removeKey,
    'stage': stage.name,
    'uploaded': uploaded,
    'failure': failure,
  };
  factory LocalPhoto.fromJson(Map<String, dynamic> json) => LocalPhoto(
    id: json['id'] as String,
    ownerId: json['ownerId'] as String,
    bytes: json['bytes'] as int,
    sha256: json['sha256'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    reserveKey: json['reserveKey'] as String,
    confirmKey: json['confirmKey'] as String,
    removeKey: json['removeKey'] as String,
    stage: LocalPhotoStage.values.byName(json['stage'] as String),
    uploaded: json['uploaded'] as bool,
    failure: json['failure'] as String?,
  );
}

class MediaCredentials {
  const MediaCredentials({required this.userId, required this.accessToken});
  final String userId;
  final String accessToken;
}

class PhotoUploadPermission {
  const PhotoUploadPermission({required this.url, required this.headers, required this.expiresAt});
  final Uri url;
  final Map<String, String> headers;
  final DateTime expiresAt;
}
