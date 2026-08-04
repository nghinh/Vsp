// Payment domain models — VSP Domain Package
//
// Per Story 12.3: Payment and Transaction Services.
// These models represent the platform's understanding of payment state
// and are mirrored across the mobile app, API, and contracts package.
//
// Platform stores NO prohibited card data (PAN, CVV, expiry).
// Only opaque paymentMethodRef tokens from the provider are stored.

/// Payment lifecycle state.
enum PaymentState {
  pending,
  succeeded,
  failed,
  refunded,
  partially_refunded,
}

/// Machine-readable failure reason when state is 'failed'.
enum PaymentFailureReason {
  provider_declined,
  insufficient_funds,
  network_error,
  cancelled,
  expired,
  unknown,
}

/// Reason for a refund request.
enum RefundReason {
  duplicate,
  fraudulent,
  requested_by_customer,
  course_cancellation,
  other,
}

/// Refund processing status.
enum RefundStatus {
  pending,
  succeeded,
  failed,
}

/// Payment transaction — core domain entity.
///
/// Represents a single payment intent through its complete lifecycle.
/// No card data is stored — only opaque provider tokens.
class PaymentTransaction {
  final String id;
  final String idempotencyKey;
  final String? providerReference;
  final String? paymentMethodRef;
  final int amount;
  final String currency;
  final PaymentState state;
  final PaymentFailureReason? failureReason;
  final String? failureMessage;
  final Map<String, String> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentTransaction({
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

  /// True if this transaction is in a terminal state.
  bool get isTerminal =>
      state == PaymentState.succeeded ||
      state == PaymentState.failed ||
      state == PaymentState.refunded;

  /// True if this transaction can be refunded.
  bool get isRefundable =>
      state == PaymentState.succeeded ||
      state == PaymentState.partially_refunded;

  /// Create a copy with updated fields.
  PaymentTransaction copyWith({
    String? id,
    String? idempotencyKey,
    String? providerReference,
    String? paymentMethodRef,
    int? amount,
    String? currency,
    PaymentState? state,
    PaymentFailureReason? failureReason,
    String? failureMessage,
    Map<String, String>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentTransaction(
      id: id ?? this.id,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      providerReference: providerReference ?? this.providerReference,
      paymentMethodRef: paymentMethodRef ?? this.paymentMethodRef,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      state: state ?? this.state,
      failureReason: failureReason ?? this.failureReason,
      failureMessage: failureMessage ?? this.failureMessage,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentTransaction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Refund request — tracks a refund against a payment transaction.
class RefundRequest {
  final String id;
  final String transactionId;
  final int amount;
  final RefundReason reason;
  final String? reasonDetail;
  final String? providerRefundRef;
  final RefundStatus status;
  final DateTime requestedAt;
  final DateTime? processedAt;

  const RefundRequest({
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

  RefundRequest copyWith({
    String? id,
    String? transactionId,
    int? amount,
    RefundReason? reason,
    String? reasonDetail,
    String? providerRefundRef,
    RefundStatus? status,
    DateTime? requestedAt,
    DateTime? processedAt,
  }) {
    return RefundRequest(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      reasonDetail: reasonDetail ?? this.reasonDetail,
      providerRefundRef: providerRefundRef ?? this.providerRefundRef,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      processedAt: processedAt ?? this.processedAt,
    );
  }
}

/// Audit log entry for payment state transitions.
class PaymentAuditEntry {
  final String id;
  final String transactionId;
  final PaymentAuditAction action;
  final String actor;
  final PaymentState? previousState;
  final PaymentState? newState;
  final String? metadataJson;
  final DateTime timestamp;

  const PaymentAuditEntry({
    required this.id,
    required this.transactionId,
    required this.action,
    required this.actor,
    this.previousState,
    this.newState,
    this.metadataJson,
    required this.timestamp,
  });
}

/// Types of auditable payment actions.
enum PaymentAuditAction {
  INTENT_CREATED,
  CONFIRMATION_SUCCEEDED,
  CONFIRMATION_FAILED,
  REFUND_REQUESTED,
  REFUND_SUCCEEDED,
  REFUND_FAILED,
  RECONCILIATION_DISCREPANCY,
}
