import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/poll.dart';
import '_paged.dart';

/// 投票：详情 / 参与（每人一次，重复 409）。
class PollRepository {
  final ApiClient client;

  PollRepository(this.client);

  Future<Poll> detail(String pollId) async {
    final data = await client.get(Endpoints.poll(pollId));
    return Poll.fromJson(asDataMap(data));
  }

  /// 投票成功后返回刷新后的投票详情。
  Future<Poll> vote(String pollId, int optionId) async {
    final data = await client
        .post(Endpoints.pollVote(pollId), data: {'option_id': optionId});
    return Poll.fromJson(asDataMap(data));
  }
}
