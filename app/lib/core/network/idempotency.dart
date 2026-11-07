import 'package:uuid/uuid.dart';

/// Header that makes the offline-queue retries safe (section 4.5).
const idempotencyKeyHeader = 'Idempotency-Key';

/// Header the server sends when it returned an already stored response.
const idempotentReplayedHeader = 'Idempotent-Replayed';

const _uuid = Uuid();

/// UUIDv7 generated on the phone: id of every new resource and key of every action.
String newLocalId() => _uuid.v7();
