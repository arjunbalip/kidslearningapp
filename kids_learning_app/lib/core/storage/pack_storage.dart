// Picks the right storage for the platform at build time:
// phones use files (dart:io), the web uses IndexedDB.
import 'pack_storage_base.dart';
import 'pack_storage_stub.dart'
    if (dart.library.io) 'pack_storage_io.dart'
    if (dart.library.js_interop) 'pack_storage_web.dart';

export 'pack_storage_base.dart';

PackStorage createPackStorage() => createPlatformPackStorage();
