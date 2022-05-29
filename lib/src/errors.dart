class InvalidCaptcha implements Exception {
  @override
  String toString() => 'The solved captcha is invalid';
}

class BadCredentials implements Exception {
  @override
  String toString() => 'Bad credentials';
}

class InvalidCredentials implements Exception {
  int retries = 0;

  InvalidCredentials(String error) {
    var retries = RegExp(r"\d").firstMatch(error);
    if (retries != null) {
      this.retries = int.parse(retries.group(0) ?? '0');
    }
  }
  @override
  String toString() =>
      'Invalid username or password.You have $retries attempts remaining';
}

class SomethingWentWrong implements Exception {
  final String error;
  const SomethingWentWrong(this.error);
  @override
  String toString() => error;
}

class LoginNotReady implements Exception {
  final String method;
  const LoginNotReady(this.method);
  @override
  String toString() => 'Login not ready call $method() first';
}
