import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/features/emergencias/assigned_case_cache.dart';

/// Available once the app has an authenticated PowerSync session.
final assignedCaseCacheProvider = Provider<AssignedCaseCache?>((ref) => null);
