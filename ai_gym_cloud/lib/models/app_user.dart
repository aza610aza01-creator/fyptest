/// Represents the current authentication state and user identity.
enum AuthFlowStage {
  unauthenticated,
  awaitingEmailOtp,
  authenticated,
  guest,
}

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.stage,
    required this.isAdmin,
  });

  final String id;
  final String email;
  final String displayName;
  final AuthFlowStage stage;
  final bool isAdmin;

  bool get isGuest => stage == AuthFlowStage.guest;
  bool get isFullyAuthenticated => stage == AuthFlowStage.authenticated;
  bool get isAwaitingOtp => stage == AuthFlowStage.awaitingEmailOtp;

  factory AppUser.unauthenticated() {
    return const AppUser(
      id: '',
      email: '',
      displayName: '',
      stage: AuthFlowStage.unauthenticated,
      isAdmin: false,
    );
  }

  factory AppUser.guest() {
    return const AppUser(
      id: 'local_guest_user',
      email: 'guest@local.offline',
      displayName: 'Guest Athlete',
      stage: AuthFlowStage.guest,
      isAdmin: false,
    );
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    AuthFlowStage? stage,
    bool? isAdmin,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      stage: stage ?? this.stage,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
