import 'package:flutter/foundation.dart';

/// Categorized failure kinds across Auth, Database, Network, Storage, Camera, and Validation.
enum AppFailureKind {
  networkOffline,
  timeout,
  unauthorized,
  forbiddenRls,
  validationFailed,
  storageUnavailable,
  cameraPermissionDenied,
  cameraPermissionPermanentlyDenied,
  modelLoadFailed,
  conflictDetected,
  unknown,
}

/// Structured, immutable failure model with localized English and Traditional Chinese messages.
@immutable
class AppFailure {
  const AppFailure({
    required this.kind,
    required this.code,
    required this.messageEn,
    required this.messageZh,
    this.isRetryable = true,
    this.technicalDetail,
  });

  final AppFailureKind kind;
  final String code;
  final String messageEn;
  final String messageZh;
  final bool isRetryable;
  final String? technicalDetail;

  String localizedMessage(bool isZh) => isZh ? messageZh : messageEn;

  factory AppFailure.fromException(Object error, {String fallbackCode = 'ERR_UNKNOWN'}) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('network') ||
        raw.contains('xmlhttprequest error')) {
      return const AppFailure(
        kind: AppFailureKind.networkOffline,
        code: 'NET_OFFLINE',
        messageEn: 'Network unavailable. Working in offline-first mode.',
        messageZh: '目前網路無法連線，已自動切換為離線優先模式。',
        isRetryable: true,
      );
    }
    if (raw.contains('timeout')) {
      return const AppFailure(
        kind: AppFailureKind.timeout,
        code: 'NET_TIMEOUT',
        messageEn: 'Request timed out. Please tap Retry.',
        messageZh: '連線逾時，請點擊重試。',
        isRetryable: true,
      );
    }
    if (raw.contains('42501') || raw.contains('row-level security')) {
      return const AppFailure(
        kind: AppFailureKind.forbiddenRls,
        code: 'RLS_DENIED',
        messageEn: 'Access denied by cloud security policy (RLS).',
        messageZh: '雲端列級安全政策 (RLS) 拒絕存取此資料。',
        isRetryable: false,
      );
    }
    return AppFailure(
      kind: AppFailureKind.unknown,
      code: fallbackCode,
      messageEn: 'Unable to complete operation. Please try again.',
      messageZh: '無法完成操作，請稍後再試。',
      isRetryable: true,
      technicalDetail: error.runtimeType.toString(),
    );
  }
}

/// Typed result wrapper replacing untyped Future.wait index casts.
@immutable
class AppResult<T> {
  const AppResult._({this.data, this.failure});

  factory AppResult.success(T data) => AppResult._(data: data);
  factory AppResult.failure(AppFailure failure) => AppResult._(failure: failure);

  final T? data;
  final AppFailure? failure;

  bool get isSuccess => failure == null && data != null;
  bool get isFailure => failure != null;
}
