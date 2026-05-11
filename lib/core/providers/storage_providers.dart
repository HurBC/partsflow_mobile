import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:partsflow_mobile/core/storage/local_storage.dart';
import 'package:partsflow_mobile/core/storage/local_storage_impl.dart';
import 'package:partsflow_mobile/core/storage/secure_storage.dart';
import 'package:partsflow_mobile/core/storage/secure_storage_impl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'storage_providers.g.dart';

// Keep alive allows this storages live during all app life time
@Riverpod(keepAlive: true)
SecureStorage secureStorage(Ref ref) {
  return SecureStorageImpl(const FlutterSecureStorage());
}

@Riverpod(keepAlive: true)
Future<LocalStorage> localStorage(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();

  return LocalStorageImpl(prefs);
}
