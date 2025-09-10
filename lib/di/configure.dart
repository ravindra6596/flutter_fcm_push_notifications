import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'configure.config.dart';

final getIt = GetIt.instance;

/// dependency initialization
@InjectableInit()
void configureDependencies() => getIt.init();

