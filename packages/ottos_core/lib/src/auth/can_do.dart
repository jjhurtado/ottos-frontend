import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc/auth_bloc.dart';

extension CanDo on BuildContext {
  /// Whether the user has [permission], rebuilding when it changes. False
  /// with no user: on logout the pages stay a moment before the redirect.
  bool canDo(String permission) => select((AuthBloc bloc) => bloc.state.user?.can(permission) ?? false);
}
