# SBTE-Scrap

SBTE-Scrap is a Dart library that scrapes exam results from the [SBTE][sbtelink] (State Board of Technical Education) website. The project uses web scraping techniques to automate the process of fetching exam results.

## How it works

SBTE-Scrap works by mimicking the actions of a web browser to access the SBTE website and extract the exam results. The program uses the [_dio package_][dl] to send HTTP requests to the SBTE website, and the [_html package_][hl] to parse the HTML content of the response.

The program navigates through the SBTE website by sending HTTP requests to the appropriate URLs, and extracting the relevant exam result data from the HTML content of the response. The program then processes this data to extract the relevant information, such as the student's name and exam scores.

## Is it legal?

Yes, SBTE-Scrap is legal. The project does not violate any laws or regulations, as it does not involve hacking, breaking into secured systems, or stealing information. The project simply automates the process of accessing publicly available information on the SBTE website, using web scraping techniques that mimic the actions of a web browser.

Furthermore, web scraping is a widely accepted practice in the industry, used by many companies and organizations to extract data from websites for various purposes, such as market research, data analysis, and product development.
## How to use it

To use SBTE-Scrap, simply add the package to pubspec.yaml

```yaml
dependencies:
    sbte:
        git: 
            url: https://github.com/Schematic-Bytes/sbte-scrap
            ref: master
```


#### Example usage:

```dart
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
  await for (final sem in sbte.getExamResult()) {
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
```

### Made with ❤️️ in Kerala
### Copyright & License 

* Copyright (C) 2023 by [Team Schematic-Bytes](https://github.com/Schematic-Bytes)
* Licensed under the terms of the [MIT](https://github.com/Schematic-Bytes/sbte-scrap/blob/master/LICENSE)



[sbtelink]: https://www.sbte.kerala.gov.in/
[dl]: https://github.com/cfug/dio/tree/main/dio
[hl]: https://github.com/dart-lang/html

