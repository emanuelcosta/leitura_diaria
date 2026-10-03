import 'database_platform_stub.dart'
    if (dart.library.io) 'database_platform_io.dart'
    if (dart.library.html) 'database_platform_web.dart' as platform;

Future<void> initializeDatabasePlatform() => platform.initializeDatabasePlatform();
