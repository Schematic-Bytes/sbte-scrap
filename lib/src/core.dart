// ignore_for_file: constant_identifier_names

import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

import 'errors.dart';
import 'model.dart';

class SbteScrap {
  late Dio _client;
  String username;
  String password;
  String? csrfToken;
  String? initalSalt;

  SbteScrap({
    required this.username,
    required this.password,
  }) {
    _client = Dio(BaseOptions(
      baseUrl: "https://www.sbte.kerala.gov.in",
      headers: {
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:100.0)"
            " Gecko/20100101 Firefox/100.0"
      },
    ));
    var cookieJar = CookieJar();
    _client.interceptors.add(CookieManager(cookieJar));
  }

  // Stream of `Semester` should be called after
  // getCaptcha.
  Stream<Semester> getExamResult(String solvedCaptcha) async* {
    await _login(solvedCaptcha);
    var semesters = await _crawl();
    for (var semester in semesters) {
      yield (await _getSemesterData(semester));
    }
  }

  // get the captcha image byte.
  Future<List<int>> getCaptcha() async {
    var res = await _client.get("/login");
    var scrapData = _scrapLogin(res.data.toString());
    var captchaImage = await _client.get<List<int>>(
      scrapData!,
      options: Options(responseType: ResponseType.bytes),
    );
    if (captchaImage.data == null) {
      throw SomethingWentWrong("Cannot get captcha image");
    }
    return captchaImage.data!;
  }

  Future<void> _login(String solvedCaptcha) async {
    if (initalSalt == null || csrfToken == null) {
      throw LoginNotReady();
    }
    var res = await _client.get("/loginprelogin/$username",
        options: Options(responseType: ResponseType.json));
    var finalSalt = res.data['uppu'];
    var formData = FormData.fromMap({
      "_peru": username,
      "_thakol": _saltPassword(password, finalSalt, initalSalt!),
      "user[captcha]": solvedCaptcha,
      "_submit": "",
      "_csrf_token": csrfToken!,
      "_uppu": finalSalt,
    });
    res = await _client.post(
      "/login",
      options: Options(
        headers: {
          "Sec-Fetch-Dest": "document",
          "Sec-Fetch-Mode": "navigate",
          "Sec-Fetch-Site": "same-origin",
          "Sec-Fetch-User": "?1",
          "Content-Type": "application/x-www-form-urlencoded",
        },
        validateStatus: (int? sc) => sc == 302 ? true : false,
      ),
      data: formData,
    );
  }

  Future<List<SemObj>> _crawl() async {
    var _viewPath = "/students/student_profile/viewDetails";
    var res = await _client.get("/dash/student");
    var soup = parse(res.data.toString());
    var dataGuid = soup
        .querySelector("a[data-view-path='$_viewPath'][data-guid]")
        ?.attributes['data-guid'];
    if (dataGuid == null) {
      var error = soup.querySelector("div.alert.alert-danger");
      var errorType = error?.nodes[4].text!.trim() ?? "";
      if (errorType.startsWith("Bad credentials")) {
        throw BadCredentials();
      } else if (errorType.startsWith("Captcha is invalid")) {
        throw InvalidCaptcha();
      } else if (errorType.startsWith("Invalid username or password")) {
        throw InvalidCredentials(errorType);
      } else {
        throw SomethingWentWrong(errorType);
      }
    }
    res = await _client.post(_viewPath,
        data: FormData.fromMap({"objId": dataGuid}));
    var form = res.data['form'];
    soup = parse(form);
    var name = soup.querySelector("div#sprofile-sd")!;
    var tags = name.querySelectorAll("div[data-blockid][data-blockno]");
    List<SemObj> semesters = [];
    for (var t in tags) {
      var sem = RegExp(r"\d").firstMatch(t.text)?.group(0) ??
          t.attributes['data-blockno']!;
      semesters.add(
        SemObj(
          sem: sem,
          objId: dataGuid,
          blockId: t.attributes['data-blockid']!,
          blockNo: t.attributes['data-blockno']!,
        ),
      );
    }
    return semesters;
  }

  Future<Semester> _getSemesterData(
    SemObj semester,
  ) async {
    String internalUrl = "/students/student_profile/internal";
    var res = await _client.post(
      internalUrl,
      data: FormData.fromMap(
        {
          "objid": semester.objId,
          "targetClass": "sprofile_mview",
          "targetClass2": "sprofile_gview",
          "blockno": semester.blockNo,
          "blockid": semester.blockId,
          "actionPath": internalUrl,
        },
      ),
    );
    var data = json.decode(res.data)["form"];
    return Semester(semesterNo: semester.sem, subjects: _scrapResult(data));
  }

  String? _scrapLogin(String string) {
    var soup = parse(string);
    initalSalt = soup.getElementById("_uppu")?.attributes["value"];
    csrfToken =
        soup.querySelector("input[name=_csrf_token]")?.attributes["value"];
    var captchaUrl =
        soup.querySelector("img[title=captcha]")?.attributes["src"];
    return captchaUrl;
  }

  List<Subject> _scrapResult(String htmlString) {
    var soup = parse(htmlString);
    var table = soup.getElementsByTagName("table")[0];
    List<Subject> subjects = [];
    for (var rows in table.getElementsByTagName("tr").skip(1)) {
      var list = Giwe(rows.getElementsByTagName("td").skip(1));
      var subject = Subject(
        course: list.giwe(0),
        registration: list.giwe(1),
        imark: list.giwe(2),
        grade: list.giwe(3),
        result: list.giwe(4),
        chance: list.giwe(5),
      );
      subjects.add(subject);
    }
    return subjects;
  }

  String _saltPassword(String pass, String salt1, String salt2) {
    List<int> enc(String s) => utf8.encode(s);
    var hexPass = sha256.convert(enc(pass));
    var initialSalt = sha256.convert(enc("$hexPass{$salt1}"));
    for (var i = 1; i <= 6; i++) {
      initialSalt = sha256.convert(enc("$initialSalt"));
    }
    var finalSalt = sha256.convert(enc("$initialSalt$salt2"));
    return finalSalt.toString();
  }

  void close() {
    _client.close();
  }
}

// get index without error
class Giwe {
  final Iterable<Element> itemList;
  const Giwe(this.itemList);
  String giwe(int index) {
    try {
      return itemList
          .elementAt(index)
          .text
          .trim()
          .replaceAll(RegExp(r"&amp;"), "");
    } on RangeError {
      return "";
    }
  }
}
