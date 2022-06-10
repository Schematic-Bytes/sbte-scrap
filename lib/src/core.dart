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

// The core class used to fetch result
class SbteScrap {
  late Dio _client;
  String? username;
  String? password;
  String? csrfToken;
  String? captchaUrl;
  String? initalSalt;
  List<SemObj>? semObjs;

  SbteScrap() {
    _client = Dio(
      BaseOptions(
        baseUrl: "https://www.sbte.kerala.gov.in",
        headers: {
          "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:100.0)"
              " Gecko/20100101 Firefox/100.0"
        },
      ),
    );
    var cookieJar = CookieJar();
    _client.interceptors.add(CookieManager(cookieJar));
  }

  // Stream of `Semester` should be called after login
  // else it would throw LoginNotReady exception
  Stream<Semester> getExamResult(String solvedCaptcha) async* {
    if (semObjs == null) {
      throw LoginNotReady("login");
    }
    for (var semester in semObjs!) {
      yield (await _getSemesterData(semester));
    }
  }

  // Used to login the user into sbte
  // should be called after initalize else it would
  // throw LoginNotReady exception
  Future<void> login(String solvedCaptcha) async {
    await _login(solvedCaptcha);
    semObjs = await _crawlSemesters();
  }

  // Used to initalize the client
  // should be called before performing any other
  // operations.
  Future<void> initalize({
    required username,
    required password,
  }) async {
    this.username = username;
    this.password = password;
    var res = await _client.get("/login");
    _scrapLogin(res.data.toString());
  }

  // Returns the bytes of the current captcha image
  // should be called after initalize else it would
  // throw a LoginNotReady exception
  Future<List<int>> getCaptcha() async {
    if (captchaUrl == null) {
      throw LoginNotReady("initalize");
    }
    var captchaImage = await _client.get<List<int>>(
      captchaUrl!,
      options: Options(responseType: ResponseType.bytes),
    );
    if (captchaImage.data == null) {
      throw SomethingWentWrong("Cannot get captcha image");
    }
    return captchaImage.data!;
  }

  // interal function used to login user into sbte
  Future<void> _login(String solvedCaptcha) async {
    if (initalSalt == null || csrfToken == null || password == null) {
      throw LoginNotReady("initalize");
    }
    var res = await _client.get("/loginprelogin/$username", options: Options(responseType: ResponseType.json));
    var finalSalt = res.data['uppu'];
    var formData = FormData.fromMap({
      "_peru": username,
      "_thakol": _saltPassword(password!, finalSalt, initalSalt!),
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

  // internal function used to get id of each semester
  Future<List<SemObj>> _crawlSemesters() async {
    var _viewPath = "/students/student_profile/viewDetails";
    var res = await _client.get("/dash/student");
    var soup = parse(res.data.toString());
    var dataGuid = soup.querySelector("a[data-view-path='$_viewPath'][data-guid]")?.attributes['data-guid'];
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
    res = await _client.post(_viewPath, data: FormData.fromMap({"objId": dataGuid}));
    var form = res.data['form'];
    soup = parse(form);
    var name = soup.querySelector("div#sprofile-sd")!;
    var tags = name.querySelectorAll("div[data-blockid][data-blockno]");
    List<SemObj> semesters = [];
    for (var t in tags) {
      var sem = RegExp(r"\d").firstMatch(t.text)?.group(0) ?? t.attributes['data-blockno']!;
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

  // internal function used to fetch data of each semester
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
    final String data = json.decode(res.data)["form"];
    final soup = parse(data);
    final pdfLink = _scrapPdf(soup);
    final subject = _scrapResult(soup);
    return Semester(
      semesterNo: semester.sem,
      subjects: subject,
      gradePdf: (await pdfLink),
    );
  }

  // internal function used to parse information needed to login
  void _scrapLogin(String string) {
    var soup = parse(string);
    initalSalt = soup.getElementById("_uppu")?.attributes["value"];
    csrfToken = soup.querySelector("input[name=_csrf_token]")?.attributes["value"];
    captchaUrl = soup.querySelector("img[title=captcha]")?.attributes["src"];
  }

  // internal function used to parse fetched data into object
  List<Subject> _scrapResult(Document soup) {
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

  // internal function used to get the grade pdf of a semester
  Future<List<int>?> _scrapPdf(Document soup) async {
    final pdfLink = soup.getElementsByTagName("a");
    if (pdfLink.isNotEmpty) {
      final link = pdfLink.first.attributes["href"];
      if (link == null) {
        return null;
      }
      final pdf = await _client.get<List<int>>(link, options: Options(responseType: ResponseType.bytes));
      if (pdf.headers.value("Content-Type") == "application/pdf") {
        return pdf.data;
      }
    }
    return null;
  }

  // internal function to salt a given password
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

  // used to close the client after use
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
      return itemList.elementAt(index).text.trim().replaceAll(RegExp(r"&amp;"), "");
    } on RangeError {
      return "";
    }
  }
}
