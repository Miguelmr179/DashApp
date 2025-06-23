class ExamModel {
  final String category;
  final List<QuestionModel> questions;

  ExamModel({required this.category, required this.questions});

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    return ExamModel(
      category: json['category'],
      questions: (json['questions'] as List)
          .map((q) => QuestionModel.fromJson(q))
          .toList(),
    );
  }
}

class QuestionModel {
  final String question;
  final List<String> options;
  final int answer;

  QuestionModel({
    required this.question,
    required this.options,
    required this.answer,
  });

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'answer': answer,
    };
  }

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      question: json['question'],
      options: List<String>.from(json['options']),
      answer: json['answer'],
    );
  }
}
