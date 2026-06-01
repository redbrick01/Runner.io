import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_colors.dart';
import '../design/app_design.dart';
import '../services/crew_service.dart';
import '../services/social_service.dart';

typedef LoadFriendCode = Future<String> Function();
typedef LookupFriendCode = Future<FriendProfile> Function(String code);
typedef SendFriendRequest = Future<FriendRequestResult> Function(String code);
typedef LoadIncomingRequests = Future<List<IncomingFriendRequest>> Function();
typedef RespondToFriendRequest =
    Future<FriendResponseResult> Function(
      String friendshipId,
      FriendResponse response,
    );
typedef LoadFriends = Future<List<FriendProfile>> Function();
typedef LoadFriendRanking =
    Future<FriendRanking> Function({
      required String rangeType,
      DateTime? anchorDate,
    });
typedef LoadMyCrews = Future<List<CrewSummary>> Function();
typedef SearchCrews =
    Future<List<CrewSummary>> Function({
      String? query,
      String? region,
      CrewSort sort,
      int limit,
    });
typedef LoadCrewRanking =
    Future<CrewRanking> Function({
      required String seasonType,
      DateTime? anchorDate,
      int limit,
    });
typedef LoadCrewDetail =
    Future<CrewDetail> Function(
      String crewId, {
      String seasonType,
      DateTime? anchorDate,
      int memberLimit,
    });
typedef MutateCrew = Future<CrewMutationResult> Function(String crewId);

enum _SocialTab { friends, crews }

enum _SocialRange { week, month, all }

class SocialPage extends StatefulWidget {
  const SocialPage({
    super.key,
    this.loadFriendCode,
    this.lookupFriendCode,
    this.sendFriendRequest,
    this.loadIncomingRequests,
    this.respondToFriendRequest,
    this.loadFriends,
    this.loadFriendRanking,
    this.loadMyCrews,
    this.searchCrews,
    this.loadCrewRanking,
    this.loadCrewDetail,
    this.joinCrew,
    this.leaveCrew,
    this.setDefaultCrew,
  });

  final LoadFriendCode? loadFriendCode;
  final LookupFriendCode? lookupFriendCode;
  final SendFriendRequest? sendFriendRequest;
  final LoadIncomingRequests? loadIncomingRequests;
  final RespondToFriendRequest? respondToFriendRequest;
  final LoadFriends? loadFriends;
  final LoadFriendRanking? loadFriendRanking;
  final LoadMyCrews? loadMyCrews;
  final SearchCrews? searchCrews;
  final LoadCrewRanking? loadCrewRanking;
  final LoadCrewDetail? loadCrewDetail;
  final MutateCrew? joinCrew;
  final MutateCrew? leaveCrew;
  final MutateCrew? setDefaultCrew;

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  final _friendCodeController = TextEditingController();
  final _crewSearchController = TextEditingController();

  _SocialTab _tab = _SocialTab.friends;
  _SocialRange _friendRange = _SocialRange.week;
  _SocialRange _crewRange = _SocialRange.week;
  CrewSort _crewSort = CrewSort.score;

  bool _friendsLoading = true;
  bool _friendActionLoading = false;
  String? _friendsError;
  String? _friendCode;
  String? _friendSearchMessage;
  FriendProfile? _friendLookup;
  List<IncomingFriendRequest> _incomingRequests = const [];
  List<FriendProfile> _friends = const [];
  FriendRanking? _friendRanking;

  bool _crewsLoading = true;
  bool _crewActionLoading = false;
  bool _crewDetailLoading = false;
  String? _crewsError;
  String? _crewMessage;
  List<CrewSummary> _myCrews = const [];
  List<CrewSummary> _publicCrews = const [];
  CrewRanking? _crewRanking;
  CrewDetail? _crewDetail;
  String? _selectedCrewId;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _loadCrews();
  }

  @override
  void dispose() {
    _friendCodeController.dispose();
    _crewSearchController.dispose();
    super.dispose();
  }

  LoadFriendCode get _loadFriendCode =>
      widget.loadFriendCode ?? SocialService.instance.fetchMyFriendCode;
  LookupFriendCode get _lookupFriendCode =>
      widget.lookupFriendCode ?? SocialService.instance.lookupFriendCode;
  SendFriendRequest get _sendFriendRequest =>
      widget.sendFriendRequest ?? SocialService.instance.sendFriendRequest;
  LoadIncomingRequests get _loadIncomingRequests =>
      widget.loadIncomingRequests ??
      SocialService.instance.fetchIncomingRequests;
  RespondToFriendRequest get _respondToFriendRequest =>
      widget.respondToFriendRequest ??
      SocialService.instance.respondToFriendRequest;
  LoadFriends get _loadFriendList =>
      widget.loadFriends ?? SocialService.instance.fetchFriends;
  LoadFriendRanking get _loadFriendRanking =>
      widget.loadFriendRanking ?? SocialService.instance.fetchFriendRanking;
  LoadMyCrews get _loadMyCrews =>
      widget.loadMyCrews ?? CrewService.instance.fetchMyCrews;
  SearchCrews get _searchCrews =>
      widget.searchCrews ?? CrewService.instance.searchCrews;
  LoadCrewRanking get _loadCrewRanking =>
      widget.loadCrewRanking ?? CrewService.instance.fetchCrewRanking;
  LoadCrewDetail get _loadCrewDetail =>
      widget.loadCrewDetail ?? CrewService.instance.fetchCrewDetail;
  MutateCrew get _joinCrew => widget.joinCrew ?? CrewService.instance.joinCrew;
  MutateCrew get _leaveCrew =>
      widget.leaveCrew ?? CrewService.instance.leaveCrew;
  MutateCrew get _setDefaultCrew =>
      widget.setDefaultCrew ?? CrewService.instance.setDefaultCrew;

  String get _friendRangeType => _rangeApiValue(_friendRange);
  String get _crewSeasonType => _rangeApiValue(_crewRange);

  DateTime? _anchorDateFor(_SocialRange range) {
    if (range == _SocialRange.all) return null;
    final now = DateTime.now();
    if (range == _SocialRange.month) {
      return DateTime(now.year, now.month, 1);
    }
    final day = DateTime(now.year, now.month, now.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  String _rangeApiValue(_SocialRange range) {
    switch (range) {
      case _SocialRange.week:
        return 'week';
      case _SocialRange.month:
        return 'month';
      case _SocialRange.all:
        return 'all';
    }
  }

  Future<void> _loadFriends({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _friendsLoading = true;
        _friendsError = null;
      });
    }
    try {
      final code = await _loadFriendCode();
      final requests = await _loadIncomingRequests();
      final friends = await _loadFriendList();
      final ranking = await _loadFriendRanking(
        rangeType: _friendRangeType,
        anchorDate: _anchorDateFor(_friendRange),
      );
      if (!mounted) return;
      setState(() {
        _friendCode = code;
        _incomingRequests = requests;
        _friends = friends;
        _friendRanking = ranking;
        _friendsError = null;
        _friendsLoading = false;
      });
    } catch (e) {
      debugPrint('소셜 친구 정보 로드 실패: $e');
      if (!mounted) return;
      setState(() {
        _friendsError = '친구 정보를 불러오지 못했습니다.';
        _friendsLoading = false;
      });
    }
  }

  Future<void> _loadFriendRankingOnly() async {
    setState(() => _friendsLoading = true);
    try {
      final ranking = await _loadFriendRanking(
        rangeType: _friendRangeType,
        anchorDate: _anchorDateFor(_friendRange),
      );
      if (!mounted) return;
      setState(() {
        _friendRanking = ranking;
        _friendsError = null;
        _friendsLoading = false;
      });
    } catch (e) {
      debugPrint('친구 랭킹 로드 실패: $e');
      if (!mounted) return;
      setState(() {
        _friendsError = '친구 랭킹을 불러오지 못했습니다.';
        _friendsLoading = false;
      });
    }
  }

  Future<void> _lookupFriend() async {
    final code = _friendCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _friendSearchMessage = '친구 코드를 입력해 주세요.');
      return;
    }
    setState(() {
      _friendActionLoading = true;
      _friendSearchMessage = null;
      _friendLookup = null;
    });
    try {
      final profile = await _lookupFriendCode(code);
      if (!mounted) return;
      setState(() {
        _friendLookup = profile;
        _friendSearchMessage = '${_profileName(profile)}님을 찾았습니다.';
      });
    } catch (e) {
      debugPrint('친구 코드 조회 실패: $e');
      if (!mounted) return;
      setState(() => _friendSearchMessage = '해당 코드를 찾지 못했습니다.');
    } finally {
      if (mounted) setState(() => _friendActionLoading = false);
    }
  }

  Future<void> _sendRequest() async {
    final code = _friendCodeController.text.trim();
    if (code.isEmpty) {
      setState(() => _friendSearchMessage = '친구 코드를 입력해 주세요.');
      return;
    }
    setState(() => _friendActionLoading = true);
    try {
      await _sendFriendRequest(code);
      if (!mounted) return;
      _friendCodeController.clear();
      setState(() {
        _friendLookup = null;
        _friendSearchMessage = '친구 요청을 보냈습니다.';
      });
      _showSnack('친구 요청을 보냈습니다.');
      await _loadFriends(showLoading: false);
    } catch (e) {
      debugPrint('친구 요청 실패: $e');
      if (!mounted) return;
      setState(() => _friendSearchMessage = '친구 요청을 보내지 못했습니다.');
    } finally {
      if (mounted) setState(() => _friendActionLoading = false);
    }
  }

  Future<void> _respondRequest(
    IncomingFriendRequest request,
    FriendResponse response,
  ) async {
    setState(() => _friendActionLoading = true);
    try {
      await _respondToFriendRequest(request.friendshipId, response);
      if (!mounted) return;
      _showSnack(
        response == FriendResponse.accepted
            ? '친구 요청을 수락했습니다.'
            : '친구 요청을 거절했습니다.',
      );
      await _loadFriends(showLoading: false);
    } catch (e) {
      debugPrint('친구 요청 응답 실패: $e');
      if (!mounted) return;
      _showSnack('요청을 처리하지 못했습니다.');
    } finally {
      if (mounted) setState(() => _friendActionLoading = false);
    }
  }

  Future<void> _loadCrews({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _crewsLoading = true;
        _crewsError = null;
      });
    }
    try {
      final myCrews = await _loadMyCrews();
      final publicCrews = await _searchCrews(
        query: _crewSearchController.text,
        sort: _crewSort,
        limit: 20,
      );
      final ranking = await _loadCrewRanking(
        seasonType: _crewSeasonType,
        anchorDate: _anchorDateFor(_crewRange),
        limit: 50,
      );
      if (!mounted) return;
      final selectedId = _resolveSelectedCrewId(myCrews, publicCrews);
      setState(() {
        _myCrews = myCrews;
        _publicCrews = publicCrews;
        _crewRanking = ranking;
        _selectedCrewId = selectedId;
        if (selectedId == null) {
          _crewDetail = null;
        }
        _crewsError = null;
        _crewsLoading = false;
      });
      if (selectedId != null) {
        await _selectCrew(selectedId, silent: true);
      }
    } catch (e) {
      debugPrint('크루 정보 로드 실패: $e');
      if (!mounted) return;
      setState(() {
        _crewsError = '크루 정보를 불러오지 못했습니다.';
        _crewsLoading = false;
      });
    }
  }

  Future<void> _selectCrew(String crewId, {bool silent = false}) async {
    if (!silent) {
      setState(() {
        _selectedCrewId = crewId;
        _crewDetailLoading = true;
        _crewMessage = null;
      });
    } else {
      setState(() => _crewDetailLoading = true);
    }
    try {
      final detail = await _loadCrewDetail(
        crewId,
        seasonType: _crewSeasonType,
        anchorDate: _anchorDateFor(_crewRange),
        memberLimit: 30,
      );
      if (!mounted) return;
      setState(() {
        _crewDetail = detail;
        _selectedCrewId = crewId;
        _crewDetailLoading = false;
      });
    } catch (e) {
      debugPrint('크루 상세 로드 실패: $e');
      if (!mounted) return;
      setState(() {
        _crewMessage = '크루 상세 정보를 불러오지 못했습니다.';
        _crewDetailLoading = false;
      });
    }
  }

  Future<void> _mutateCrew(
    CrewSummary crew,
    MutateCrew action,
    String successMessage,
  ) async {
    setState(() => _crewActionLoading = true);
    try {
      await action(crew.id);
      if (!mounted) return;
      _showSnack(successMessage);
      await _loadCrews(showLoading: false);
    } catch (e) {
      debugPrint('크루 작업 실패: $e');
      if (!mounted) return;
      _showSnack('크루 작업을 처리하지 못했습니다.');
    } finally {
      if (mounted) setState(() => _crewActionLoading = false);
    }
  }

  String? _firstCrewId(
    List<CrewSummary> myCrews,
    List<CrewSummary> publicCrews,
  ) {
    if (myCrews.isNotEmpty) return myCrews.first.id;
    if (publicCrews.isNotEmpty) return publicCrews.first.id;
    return null;
  }

  String? _resolveSelectedCrewId(
    List<CrewSummary> myCrews,
    List<CrewSummary> publicCrews,
  ) {
    final selectedId = _selectedCrewId;
    final visibleIds = {
      ...myCrews.map((crew) => crew.id),
      ...publicCrews.map((crew) => crew.id),
    };
    if (selectedId != null && visibleIds.contains(selectedId)) {
      return selectedId;
    }
    return _firstCrewId(myCrews, publicCrews);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _copyFriendCode() {
    final code = _friendCode;
    if (code == null || code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    _showSnack('친구 코드를 복사했습니다.');
  }

  String _profileName(FriendProfile profile) {
    return profile.nickName?.trim().isNotEmpty == true
        ? profile.nickName!.trim()
        : '익명 러너';
  }

  String _memberName(CrewMemberContribution member) {
    return member.nickName?.trim().isNotEmpty == true
        ? member.nickName!.trim()
        : '익명 러너';
  }

  String _formatPoint(double value) {
    if (value == value.toInt()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  String _formatArea(double squareMeters) {
    if (squareMeters >= 1000000) {
      return '${(squareMeters / 1000000).toStringAsFixed(2)} km²';
    }
    return '${squareMeters.toStringAsFixed(0)} m²';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '소셜',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: RefreshIndicator(
        onRefresh: _tab == _SocialTab.friends ? _loadFriends : _loadCrews,
        child: ListView(
          padding: AppSpacing.page,
          children: [
            AppSegmentedControl<_SocialTab>(
              value: _tab,
              onChanged: (value) => setState(() => _tab = value),
              options: const [
                AppSegmentOption(value: _SocialTab.friends, label: '친구'),
                AppSegmentOption(value: _SocialTab.crews, label: '크루'),
              ],
            ),
            const SizedBox(height: 16),
            if (_tab == _SocialTab.friends) _buildFriendsTab(),
            if (_tab == _SocialTab.crews) _buildCrewsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTab() {
    if (_friendsLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_friendsError != null) ...[
          _buildErrorCard(_friendsError!, _loadFriends),
          const SizedBox(height: 12),
        ],
        _buildFriendCodeCard(),
        const SizedBox(height: 12),
        _buildFriendSearchCard(),
        const SizedBox(height: 18),
        _buildFriendRequestsSection(),
        const SizedBox(height: 18),
        _buildFriendListSection(),
        const SizedBox(height: 18),
        _buildFriendRankingSection(),
      ],
    );
  }

  Widget _buildFriendCodeCard() {
    return AppSurface(
      padding: AppSpacing.cardDense,
      child: Row(
        children: [
          _buildIconBox(Icons.badge_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('내 친구 코드', style: AppTextStyles.label),
                const SizedBox(height: 3),
                SelectableText(
                  _friendCode?.isNotEmpty == true ? _friendCode! : '발급 전',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '복사',
            onPressed: _friendCode?.isNotEmpty == true ? _copyFriendCode : null,
            icon: const Icon(Icons.copy_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendSearchCard() {
    return AppSurface(
      padding: AppSpacing.cardDense,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('친구 코드 검색', Icons.person_add_alt_1_rounded),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _friendCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _inputDecoration('친구 코드 입력'),
                  onSubmitted: (_) => _lookupFriend(),
                ),
              ),
              const SizedBox(width: 8),
              _smallButton('조회', _friendActionLoading ? null : _lookupFriend),
              const SizedBox(width: 6),
              _smallButton('요청', _friendActionLoading ? null : _sendRequest),
            ],
          ),
          if (_friendSearchMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _friendSearchMessage!,
              style: const TextStyle(color: AppColors.secondaryText),
            ),
          ],
          if (_friendLookup != null) ...[
            const SizedBox(height: 10),
            _buildFriendTile(_friendLookup!, trailing: const Text('조회됨')),
          ],
        ],
      ),
    );
  }

  Widget _buildFriendRequestsSection() {
    return _buildSection(
      title: '받은 친구 요청',
      icon: Icons.mark_email_unread_rounded,
      emptyText: '받은 친구 요청이 없습니다.',
      isEmpty: _incomingRequests.isEmpty,
      children: _incomingRequests
          .map((request) {
            return _buildFriendTile(
              request.requester,
              subtitle: request.createdAt == null
                  ? null
                  : '${request.createdAt!.year}.${request.createdAt!.month.toString().padLeft(2, '0')}.${request.createdAt!.day.toString().padLeft(2, '0')} 요청',
              trailing: Wrap(
                spacing: 6,
                children: [
                  _tinyTextButton(
                    '수락',
                    _friendActionLoading
                        ? null
                        : () =>
                              _respondRequest(request, FriendResponse.accepted),
                  ),
                  _tinyTextButton(
                    '거절',
                    _friendActionLoading
                        ? null
                        : () =>
                              _respondRequest(request, FriendResponse.rejected),
                    destructive: true,
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildFriendListSection() {
    return _buildSection(
      title: '친구 목록',
      icon: Icons.group_rounded,
      emptyText: '아직 친구가 없습니다.',
      isEmpty: _friends.isEmpty,
      children: _friends.map(_buildFriendTile).toList(growable: false),
    );
  }

  Widget _buildFriendRankingSection() {
    final ranking = _friendRanking?.results ?? const <FriendRankingItem>[];
    return AppSurface(
      padding: AppSpacing.cardDense,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('친구 랭킹', Icons.leaderboard_rounded),
          const SizedBox(height: 10),
          AppSegmentedControl<_SocialRange>(
            value: _friendRange,
            onChanged: (value) {
              setState(() => _friendRange = value);
              _loadFriendRankingOnly();
            },
            options: const [
              AppSegmentOption(value: _SocialRange.week, label: '주간'),
              AppSegmentOption(value: _SocialRange.month, label: '월간'),
              AppSegmentOption(value: _SocialRange.all, label: '전체'),
            ],
          ),
          const SizedBox(height: 10),
          if (ranking.isEmpty)
            _emptyText('친구 랭킹 데이터가 없습니다.')
          else
            ...ranking.map(_buildFriendRankingRow),
        ],
      ),
    );
  }

  Widget _buildCrewsTab() {
    if (_crewsLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 80),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_crewsError != null) ...[
          _buildErrorCard(_crewsError!, _loadCrews),
          const SizedBox(height: 12),
        ],
        _buildMyCrewsSection(),
        const SizedBox(height: 18),
        _buildCrewSearchSection(),
        const SizedBox(height: 18),
        _buildCrewRankingSection(),
        const SizedBox(height: 18),
        _buildCrewDetailSection(),
      ],
    );
  }

  Widget _buildMyCrewsSection() {
    return _buildSection(
      title: '내 크루',
      icon: Icons.shield_rounded,
      emptyText: '참여 중인 크루가 없습니다.',
      isEmpty: _myCrews.isEmpty,
      children: _myCrews
          .map(
            (crew) => _buildCrewTile(
              crew,
              actions: [
                if (!crew.isDefaultContribution)
                  _tinyTextButton(
                    '기본 설정',
                    _crewActionLoading
                        ? null
                        : () => _mutateCrew(
                            crew,
                            _setDefaultCrew,
                            '기본 크루를 설정했습니다.',
                          ),
                  )
                else
                  _badge('기본'),
                _tinyTextButton(
                  '나가기',
                  _crewActionLoading
                      ? null
                      : () => _mutateCrew(crew, _leaveCrew, '크루에서 나갔습니다.'),
                  destructive: true,
                ),
              ],
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildCrewSearchSection() {
    return AppSurface(
      padding: AppSpacing.cardDense,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('공개 크루 찾기', Icons.search_rounded),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _crewSearchController,
                  decoration: _inputDecoration('크루명 또는 지역'),
                  onSubmitted: (_) => _loadCrews(showLoading: false),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<CrewSort>(
                value: _crewSort,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: CrewSort.score, child: Text('점수')),
                  DropdownMenuItem(value: CrewSort.members, child: Text('인원')),
                  DropdownMenuItem(value: CrewSort.activity, child: Text('활동')),
                  DropdownMenuItem(value: CrewSort.newest, child: Text('신규')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _crewSort = value);
                  _loadCrews(showLoading: false);
                },
              ),
              IconButton(
                tooltip: '검색',
                onPressed: () => _loadCrews(showLoading: false),
                icon: const Icon(Icons.search_rounded),
              ),
            ],
          ),
          if (_crewMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _crewMessage!,
              style: const TextStyle(color: AppColors.secondaryText),
            ),
          ],
          const SizedBox(height: 10),
          if (_publicCrews.isEmpty)
            _emptyText('검색된 공개 크루가 없습니다.')
          else
            ..._publicCrews.map(
              (crew) => _buildCrewTile(
                crew,
                actions: [
                  if (crew.isJoined)
                    _badge('참여 중')
                  else
                    _tinyTextButton(
                      '가입',
                      _crewActionLoading
                          ? null
                          : () => _mutateCrew(crew, _joinCrew, '크루에 가입했습니다.'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCrewRankingSection() {
    final crews = _crewRanking?.crews ?? const <CrewSummary>[];
    return AppSurface(
      padding: AppSpacing.cardDense,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('크루 랭킹', Icons.emoji_events_rounded),
          const SizedBox(height: 10),
          AppSegmentedControl<_SocialRange>(
            value: _crewRange,
            onChanged: (value) {
              setState(() => _crewRange = value);
              _loadCrews(showLoading: false);
            },
            options: const [
              AppSegmentOption(value: _SocialRange.week, label: '주간'),
              AppSegmentOption(value: _SocialRange.month, label: '월간'),
              AppSegmentOption(value: _SocialRange.all, label: '전체'),
            ],
          ),
          const SizedBox(height: 10),
          if (crews.isEmpty)
            _emptyText('크루 랭킹 데이터가 없습니다.')
          else
            ...crews.take(10).map(_buildCrewRankingRow),
        ],
      ),
    );
  }

  Widget _buildCrewDetailSection() {
    final detail = _crewDetail;
    return AppSurface(
      padding: AppSpacing.cardDense,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('크루 상세', Icons.groups_2_rounded),
          const SizedBox(height: 10),
          if (_crewDetailLoading)
            const Center(child: CircularProgressIndicator())
          else if (detail == null)
            _emptyText('크루를 선택하면 상세 정보가 표시됩니다.')
          else ...[
            _buildCrewTile(detail.crew),
            const SizedBox(height: 10),
            if (!detail.canViewMembers)
              _emptyText('가입한 크루의 멤버 랭킹만 볼 수 있습니다.')
            else if (detail.members.isEmpty)
              _emptyText('멤버 기여 데이터가 없습니다.')
            else
              ...detail.members.map(_buildCrewMemberRow),
          ],
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required bool isEmpty,
    required String emptyText,
    required List<Widget> children,
  }) {
    return AppSurface(
      padding: AppSpacing.cardDense,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(title, icon),
          const SizedBox(height: 10),
          if (isEmpty) _emptyText(emptyText) else ...children,
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(title, style: AppTextStyles.sectionTitle),
      ],
    );
  }

  Widget _buildFriendTile(
    FriendProfile profile, {
    String? subtitle,
    Widget? trailing,
  }) {
    return _rowShell(
      child: Row(
        children: [
          _buildAvatar(_profileName(profile), profile.colorHex),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _profileName(profile),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null || profile.friendCode != null)
                  Text(
                    subtitle ?? profile.friendCode!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _buildFriendRankingRow(FriendRankingItem item) {
    return _rowShell(
      child: Row(
        children: [
          _rankBox(item.displayRank),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.nickName?.isNotEmpty == true ? item.nickName! : '익명 러너',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (item.isSelf) ...[const SizedBox(width: 8), _badge('나')],
          const SizedBox(width: 8),
          Text(
            '${_formatPoint(item.totalPoints)} P',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrewTile(CrewSummary crew, {List<Widget> actions = const []}) {
    return InkWell(
      onTap: () => _selectCrew(crew.id),
      borderRadius: BorderRadius.circular(12),
      child: _rowShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildAvatar(crew.name, crew.colorHex),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              crew.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (crew.isDefaultContribution) _badge('기본'),
                        ],
                      ),
                      Text(
                        [
                          if (crew.region?.isNotEmpty == true) crew.region,
                          '${crew.memberCount}명',
                          '${_formatPoint(crew.seasonScore)}점',
                        ].whereType<String>().join(' · '),
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (crew.description?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                crew.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.secondaryText),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '누적 ${_formatArea(crew.cumulativeAreaM2)}',
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Wrap(spacing: 6, children: actions),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrewRankingRow(CrewSummary crew) {
    return _rowShell(
      child: Row(
        children: [
          _rankBox(crew.displayRank ?? 0),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              crew.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_formatPoint(crew.seasonScore)}점',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrewMemberRow(CrewMemberContribution member) {
    return _rowShell(
      child: Row(
        children: [
          _rankBox(member.displayRank),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _memberName(member),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '${_formatPoint(member.contributionScore)}점',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message, Future<void> Function() retry) {
    return AppSurface(
      padding: AppSpacing.cardDense,
      color: AppColors.destructiveSoft,
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.destructive),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.text)),
          ),
          _smallButton('재시도', retry),
        ],
      ),
    );
  }

  Widget _rowShell({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _buildIconBox(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: AppColors.primary, size: 21),
    );
  }

  Widget _buildAvatar(String label, String? colorHex) {
    final color = _colorFromHex(colorHex) ?? AppColors.primary;
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        label.isEmpty ? '?' : label.characters.first,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _rankBox(int rank) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        rank > 0 ? rank.toString() : '-',
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _emptyText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.secondaryText),
        ),
      ),
    );
  }

  Widget _smallButton(String label, VoidCallback? onPressed) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(54, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(label, maxLines: 1),
    );
  }

  Widget _tinyTextButton(
    String label,
    VoidCallback? onPressed, {
    bool destructive = false,
  }) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: destructive
            ? AppColors.destructive
            : AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(40, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: AppColors.surfaceSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
    );
  }

  Color? _colorFromHex(String? hex) {
    final value = hex?.replaceFirst('#', '').trim();
    if (value == null || value.length != 6) return null;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    return Color(0xFF000000 | parsed);
  }
}
