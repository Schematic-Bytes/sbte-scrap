class Semester {
  final String semesterNo;
  List<Subject> subjects = [];

  Semester({
    required this.semesterNo,
    required this.subjects,
  });

  Map<String, dynamic> toJson() {
    return {
      "semesterno": semesterNo,
      "subjects": subjects.map((e) => e.toJson()).toList(),
    };
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

  Map<String, String> toJson() {
    return {
      "course": course,
      "registration": registration,
      "imark": imark,
      "grade": grade,
      "result": result,
      "chance": chance,
    };
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
