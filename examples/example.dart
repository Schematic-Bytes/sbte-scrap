import 'dart:convert';
import 'dart:io';

import 'package:sbte/sbte.dart';

Future<void> main(List<String> arguments) async {
  print('Hello world!');
  final username = input("Enter the username: ");
  final password = input("Enter the password: ");
  final sbte = SbteScrap();
  await sbte.initalize(username: username, password: password);
  final captchaImage = await sbte.getCaptcha();
  var file = File("captcha.jpeg");
  await file.writeAsBytes(captchaImage);
  final solvedCaptcha = input("Enter the solved captcha: ");
  await sbte.login(solvedCaptcha);
  JsonEncoder encoder = JsonEncoder.withIndent('  ');
  await for (final sem in sbte.getExamResult(solvedCaptcha)) {
    if (sem.gradePdf != null) {
      final file = File("${sem.semesterNo}.pdf");
      await file.writeAsBytes(sem.gradePdf!);
    }
    String prettyprint = encoder.convert(sem.toJson());
    print(prettyprint);
  }
  sbte.close();
}

String input(String string) {
  print(string);
  return stdin.readLineSync()!;
}
