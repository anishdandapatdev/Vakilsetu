enum PushProvider { fcm, apns, webpush }

abstract interface class PushRegistrationRepository {
  Future<String> register({required PushProvider provider, required String token});
  Future<void> remove(String registrationId);
}
