class Semester {
  final String semesterNo;
  final List<int>? gradePdf;
  List<Subject> subjects = [];

  Semester({
    required this.semesterNo,
    required this.subjects,
    this.gradePdf,
  });

  Map<String, dynamic> toJson() {
    return {
      "semesterno": semesterNo,
      "subjects": subjects.map((e) => e.toJson()).toList(),
    };
  }

  static Semester fromMap(Map<String, dynamic> map) {
    return Semester(
      semesterNo: map["semesterno"],
      subjects: List.from(
        List.from(map["subjects"]).map((e) => Subject.fromMap(e)),
      ),
    );
  }
}

class Subject {
  final String course;
  final String registration;
  final String imark;
  final String grade;
  final String result;
  final String chance;

  const Subject({
    required this.course,
    required this.registration,
    required this.imark,
    required this.grade,
    required this.result,
    required this.chance,
  });

  Map<String, dynamic> toJson() {
    return {
      "course": course,
      "registration": registration,
      "imark": imark,
      "grade": grade,
      "result": result,
      "chance": chance,
    };
  }

  static Subject fromMap(Map<String, dynamic> map) {
    return Subject(
      course: map["course"],
      registration: map["registration"],
      imark: map["imark"],
      grade: map["grade"],
      result: map["result"],
      chance: map["chance"],
    );
  }
}

class SemObj {
  final String blockId;
  final String blockNo;
  final String objId;
  final String sem;

  const SemObj({
    required this.sem,
    required this.objId,
    required this.blockId,
    required this.blockNo,
  });
}
