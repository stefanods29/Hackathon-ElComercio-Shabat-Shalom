import 'package:uuid/uuid.dart';

/// Header that makes retries of the same action safe (section 4.5 of the architecture).
const idempotencyKeyHeader = 'Idempotency-Key';

/// Header the API sends when it returned an already stored response.
const idempotentReplayedHeader = 'Idempotent-Replayed';

const _uuid = Uuid();

/// UUIDv7: key of every action the console sends. One key per attempt of the same change; a new
/// key when the change itself is different (for example after reloading a case).
String newLocalId() => _uuid.v7();

final _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Route parameters are untrusted: only well-formed ids reach the API.
bool isUuid(String value) => _uuidPattern.hasMatch(value);
