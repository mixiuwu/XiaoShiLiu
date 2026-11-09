import '_json.dart';

/// 投票选项。
class PollOption {
  final int id;
  final String content;
  final int voteCount;
  final double percentage;
  final bool selected;

  const PollOption({
    required this.id,
    required this.content,
    required this.voteCount,
    required this.percentage,
    required this.selected,
  });

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: asInt(json['id']),
      content: asString(json['content']),
      voteCount: asInt(json['vote_count']),
      percentage: asDouble(json['percentage']),
      selected: asBool(json['selected']),
    );
  }
}

/// 投票详情（polls，后端 buildPollDetail 组装）。
class Poll {
  final int id;
  final int postId;
  final String question;
  final String? endsAt;
  final bool expired;
  final int? remainingSeconds;
  final int totalVotes;
  final bool voted;
  final int? myChoice;
  final List<PollOption> options;

  const Poll({
    required this.id,
    required this.postId,
    required this.question,
    this.endsAt,
    required this.expired,
    this.remainingSeconds,
    required this.totalVotes,
    required this.voted,
    this.myChoice,
    required this.options,
  });

  factory Poll.fromJson(Map<String, dynamic> json) {
    return Poll(
      id: asInt(json['id']),
      postId: asInt(json['post_id']),
      question: asString(json['question']),
      endsAt: asStringOrNull(json['ends_at']),
      expired: asBool(json['expired']),
      remainingSeconds: json['remaining_seconds'] == null
          ? null
          : asInt(json['remaining_seconds']),
      totalVotes: asInt(json['total_votes']),
      voted: asBool(json['voted']),
      myChoice: json['my_choice'] == null ? null : asInt(json['my_choice']),
      options: asMapList(json['options']).map(PollOption.fromJson).toList(),
    );
  }
}
