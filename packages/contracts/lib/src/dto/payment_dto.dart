// PaymentDto — VSP Contracts Package
//
// API serialization models for payment entities.
// Mirrors PaymentTransaction and related domain models.
//
// Per Story 12.3: Payment and Transaction Services.
// Platform stores NO prohibited card data (PAN, CVV, expiry).

/// Payment state enum — mirrors PaymentState in domain model.
enum PaymentStateDto {
  pending,
  succeeded,
  failed,
  refunded,
  partially_refunded;

  static PaymentStateDto fromString(String value) {
    return PaymentStateDto.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => PaymentStateDto.pending,
    );
  }
}

/// Payment failure reason — mirrors PaymentFailureReason in domain model.
enum PaymentFailureReasonDto {
  provider_declined,
  insufficient_funds,
  network_error,
  cancelled,
  expired,
  unknown;

  static PaymentFailureReasonDto fromString(String value) {
    return PaymentFailureReasonDto.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => PaymentFailureReasonDto.unknown,
    );
  }
}

/// Refund reason — mirrors RefundReason in domain model.
enum RefundReasonDto {
  duplicate,
  fraudulent,
  requested_by_customer,
  course_cancellation,
  other;

  static RefundReasonDto fromString(String value) {
    return RefundReasonDto.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => RefundReasonDto.other,
    );
  }
}

/// Refund status — mirrors RefundStatus in domain model.
enum RefundStatusDto {
  pending,
  succeeded,
  failed;

  static RefundStatusDto fromString(String value) {
    return RefundStatusDto.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => RefundStatusDto.pending,
    );
  }
}

/// Payment transaction DTO for API request/response serialization.
class PaymentTransactionDto {
  final String id;
  final String idempotencyKey;
  final String? providerReference;
  final String? paymentMethodRef;
  final int amount;
  final String currency;
  final PaymentStateDto state;
  final PaymentFailureReasonDto? failureReason;
  final String? failureMessage;
  final Map<String, String> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentTransactionDto({
    required this.id,
    required this.idempotencyKey,
    this.providerReference,
    this.paymentMethodRef,
    required this.amount,
    required this.currency,
    required this.state,
    this.failureReason,
    this.failureMessage,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentTransactionDto.fromJson(Map<String, dynamic> json) {
    return PaymentTransactionDto(
      id: json['id'] as String,
      idempotencyKey: json['idempotencyKey'] as String,
      providerReference: json['providerReference'] as String?,
      paymentMethodRef: json['paymentMethodRef'] as String?,
      amount: json['amount'] as int,
      currency: json['currency'] as String,
      state: PaymentStateDto.fromString(json['state'] as String),
      failureReason: json['failureReason'] != null
          ? PaymentFailureReasonDto.fromString(json['failureReason'] as String)
          : null,
      failureMessage: json['failureMessage'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as String),
          ) ??
          {},
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'idempotencyKey': idempotencyKey,
        'providerReference': providerReference,
        'paymentMethodRef': paymentMethodRef,
        'amount': amount,
        'currency': currency,
        'state': state.name,
        'failureReason': failureReason?.name,
        'failureMessage': failureMessage,
        'metadata': metadata,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
}

/// Refund request DTO.
class RefundRequestDto {
  final String id;
  final String transactionId;
  final int amount;
  final RefundReasonDto reason;
  final String? reasonDetail;
  final String? providerRefundRef;
  final RefundStatusDto status;
  final DateTime requestedAt;
  final DateTime? processedAt;

  const RefundRequestDto({
    required this.id,
    required this.transactionId,
    required this.amount,
    required this.reason,
    this.reasonDetail,
    this.providerRefundRef,
    required this.status,
    required this.requestedAt,
    this.processedAt,
  });

  factory RefundRequestDto.fromJson(Map<String, dynamic> json) {
    return RefundRequestDto(
      id: json['id'] as String,
      transactionId: json['transactionId'] as String,
      amount: json['amount'] as int,
      reason: RefundReasonDto.fromString(json['reason'] as String),
      reasonDetail: json['reasonDetail'] as String?,
      providerRefundRef: json['providerRefundRef'] as String?,
      status: RefundStatusDto.fromString(json['status'] as String),
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      processedAt: json['processedAt'] != null
          ? DateTime.parse(json['processedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'transactionId': transactionId,
        'amount': amount,
        'reason': reason.name,
        'reasonDetail': reasonDetail,
        'providerRefundRef': providerRefundRef,
        'status': status.name,
        'requestedAt': requestedAt.toUtc().toIso8601String(),
        'processedAt': processedAt?.toUtc().toIso8601String(),
      };
}

/// Audit log entry DTO.
class PaymentAuditEntryDto {
  final String id;
  final String transactionId;
  final String action;
  final String actor;
  final PaymentStateDto? previousState;
  final PaymentStateDto? newState;
  final String? metadataJson;
  final DateTime timestamp;

  const PaymentAuditEntryDto({
    required this.id,
    required this.transactionId,
    required this.action,
    required this.actor,
    this.previousState,
    this.newState,
    this.metadataJson,
    required this.timestamp,
  });

  factory PaymentAuditEntryDto.fromJson(Map<String, dynamic> json) {
    return PaymentAuditEntryDto(
      id: json['id'] as String,
      transactionId: json['transactionId'] as String,
      action: json['action'] as String,
      actor: json['actor'] as String,
      previousState: json['previousState'] != null
          ? PaymentStateDto.fromString(json['previousState'] as String)
          : null,
      newState: json['newState'] != null
          ? PaymentStateDto.fromString(json['newState'] as String)
          : null,
      metadataJson: json['metadataJson'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'transactionId': transactionId,
        'action': action,
        'actor': actor,
        'previousState': previousState?.name,
        'newState': newState?.name,
        'metadataJson': metadataJson,
        'timestamp': timestamp.toUtc().toIso8601String(),
      };
}

/// Create payment intent request DTO.
class CreatePaymentIntentRequestDto {
  final int amount;
  final String currency;
  final String idempotencyKey;
  final List<String>? paymentMethodTypes;
  final Map<String, String>? metadata;
  final String? returnUrl;

  const CreatePaymentIntentRequestDto({
    required this.amount,
    required this.currency,
    required this.idempotencyKey,
    this.paymentMethodTypes,
    this.metadata,
    this.returnUrl,
  });

  factory CreatePaymentIntentRequestDto.fromJson(Map<String, dynamic> json) {
    return CreatePaymentIntentRequestDto(
      amount: json['amount'] as int,
      currency: json['currency'] as String,
      idempotencyKey: json['idempotencyKey'] as String,
      paymentMethodTypes: (json['paymentMethodTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      metadata: (json['metadata'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as String),
          ),
      returnUrl: json['returnUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'currency': currency,
        'idempotencyKey': idempotencyKey,
        'paymentMethodTypes': paymentMethodTypes,
        'metadata': metadata,
        'returnUrl': returnUrl,
      };
}

/// Create payment intent response DTO.
class CreatePaymentIntentResponseDto {
  final String transactionId;
  final String? providerReference;
  final PaymentStateDto state;
  final int amount;
  final String currency;
  final String? clientSecret;
  final String? returnUrl;
  final DateTime createdAt;

  const CreatePaymentIntentResponseDto({
    required this.transactionId,
    this.providerReference,
    required this.state,
    required this.amount,
    required this.currency,
    this.clientSecret,
    this.returnUrl,
    required this.createdAt,
  });

  factory CreatePaymentIntentResponseDto.fromJson(Map<String, dynamic> json) {
    return CreatePaymentIntentResponseDto(
      transactionId: json['transactionId'] as String,
      providerReference: json['providerReference'] as String?,
      state: PaymentStateDto.fromString(json['state'] as String),
      amount: json['amount'] as int,
      currency: json['currency'] as String,
      clientSecret: json['clientSecret'] as String?,
      returnUrl: json['returnUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'transactionId': transactionId,
        'providerReference': providerReference,
        'state': state.name,
        'amount': amount,
        'currency': currency,
        'clientSecret': clientSecret,
        'returnUrl': returnUrl,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };
}

/// Payment status response DTO.
class PaymentStatusResponseDto {
  final String id;
  final String? providerReference;
  final String? paymentMethodRef;
  final PaymentStateDto state;
  final PaymentFailureReasonDto? failureReason;
  final String? failureMessage;
  final int amount;
  final String currency;
  final Map<String, String>? metadata;
  final int refundedAmount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentStatusResponseDto({
    required this.id,
    this.providerReference,
    this.paymentMethodRef,
    required this.state,
    this.failureReason,
    this.failureMessage,
    required this.amount,
    required this.currency,
    this.metadata,
    this.refundedAmount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentStatusResponseDto.fromJson(Map<String, dynamic> json) {
    return PaymentStatusResponseDto(
      id: json['id'] as String,
      providerReference: json['providerReference'] as String?,
      paymentMethodRef: json['paymentMethodRef'] as String?,
      state: PaymentStateDto.fromString(json['state'] as String),
      failureReason: json['failureReason'] != null
          ? PaymentFailureReasonDto.fromString(json['failureReason'] as String)
          : null,
      failureMessage: json['failureMessage'] as String?,
      amount: json['amount'] as int,
      currency: json['currency'] as String,
      metadata: (json['metadata'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as String),
          ),
      refundedAmount: json['refundedAmount'] as int? ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'providerReference': providerReference,
        'paymentMethodRef': paymentMethodRef,
        'state': state.name,
        'failureReason': failureReason?.name,
        'failureMessage': failureMessage,
        'amount': amount,
        'currency': currency,
        'metadata': metadata,
        'refundedAmount': refundedAmount,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
}

/// Refund payment request DTO.
class RefundPaymentRequestDto {
  final int? amount;
  final RefundReasonDto reason;
  final String? reasonDetail;

  const RefundPaymentRequestDto({
    this.amount,
    required this.reason,
    this.reasonDetail,
  });

  factory RefundPaymentRequestDto.fromJson(Map<String, dynamic> json) {
    return RefundPaymentRequestDto(
      amount: json['amount'] as int?,
      reason: RefundReasonDto.fromString(json['reason'] as String),
      reasonDetail: json['reasonDetail'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'reason': reason.name,
        'reasonDetail': reasonDetail,
      };
}

/// Refund response DTO.
class RefundResponseDto {
  final String refundRequestId;
  final String transactionId;
  final RefundStatusDto status;
  final int amount;
  final RefundReasonDto reason;
  final String? providerRefundRef;
  final DateTime requestedAt;
  final DateTime? processedAt;

  const RefundResponseDto({
    required this.refundRequestId,
    required this.transactionId,
    required this.status,
    required this.amount,
    required this.reason,
    this.providerRefundRef,
    required this.requestedAt,
    this.processedAt,
  });

  factory RefundResponseDto.fromJson(Map<String, dynamic> json) {
    return RefundResponseDto(
      refundRequestId: json['refundRequestId'] as String,
      transactionId: json['transactionId'] as String,
      status: RefundStatusDto.fromString(json['status'] as String),
      amount: json['amount'] as int,
      reason: RefundReasonDto.fromString(json['reason'] as String),
      providerRefundRef: json['providerRefundRef'] as String?,
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      processedAt: json['processedAt'] != null
          ? DateTime.parse(json['processedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'refundRequestId': refundRequestId,
        'transactionId': transactionId,
        'status': status.name,
        'amount': amount,
        'reason': reason.name,
        'providerRefundRef': providerRefundRef,
        'requestedAt': requestedAt.toUtc().toIso8601String(),
        'processedAt': processedAt?.toUtc().toIso8601String(),
      };
}
