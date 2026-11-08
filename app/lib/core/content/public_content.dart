import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Public information only. This cache never stores cases, account details or commands.
abstract interface class PublicContentSource {
  Future<String> asset(String path);
  Future<String?> cached(String key);
  Future<String?> download(Uri? uri);
  Future<void> save(String key, String json);
}

class CachedPublicContentSource implements PublicContentSource {
  @override
  Future<String> asset(String path) => rootBundle.loadString(path);
  @override
  Future<String?> cached(String key) async =>
      (await SharedPreferences.getInstance()).getString('publicContent.$key');
  @override
  Future<void> save(String key, String json) async {
    await (await SharedPreferences.getInstance()).setString('publicContent.$key', json);
  }

  @override
  Future<String?> download(Uri? uri) async {
    if (uri == null || uri.scheme != 'https') return null;
    final client = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
        responseType: ResponseType.plain,
      ),
    );
    try {
      final response = await client.getUri<String>(uri);
      final data = response.data;
      if (data == null || data.length > 262144) return null;
      return data;
    } finally {
      client.close(force: true);
    }
  }
}

final publicContentSourceProvider = Provider<PublicContentSource>(
  (ref) => CachedPublicContentSource(),
);

/// Yield a valid bundled copy first. Invalid CDN/cache data can never replace it.
Stream<T> watchPublicContent<T>({
  required PublicContentSource source,
  required String key,
  required String asset,
  required Uri? uri,
  required T Function(Object?) parse,
}) async* {
  var current = parse(jsonDecode(await source.asset(asset)));
  yield current;
  try {
    final cached = await source.cached(key);
    if (cached != null) {
      current = parse(jsonDecode(cached));
      yield current;
    }
  } catch (_) {
    /* Keep the bundled copy. */
  }
  try {
    final downloaded = await source.download(uri);
    if (downloaded != null) {
      final validated = parse(jsonDecode(downloaded));
      yield validated;
      await source.save(key, downloaded);
    }
  } catch (_) {
    /* Keep the last valid public copy offline. */
  }
}
