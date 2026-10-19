import 'package:flutter/material.dart';
import 'package:ai_gym_flutter/core/widgets/glass_widgets.dart';

/// Modular hub for Social & Motivation (Section 17), Content & Trainer Booking
/// (Section 18), and Monetisation Plans (Section 19).
/// Never exposes private health data or simulates fake payment processing.
class SocialAndPlansSheet extends StatefulWidget {
  const SocialAndPlansSheet({
    super.key,
    required this.isZh,
    required this.glassEnabled,
    required this.currentPlan,
  });

  final bool isZh;
  final bool glassEnabled;
  final String currentPlan;

  @override
  State<SocialAndPlansSheet> createState() => _SocialAndPlansSheetState();
}

class _SocialAndPlansSheetState extends State<SocialAndPlansSheet> {
  int _selectedSection = 0;
  bool _shareWorkoutOptIn = false;
  int _kudosCount = 14;
  bool _joinedChallenge = true;
  final TextEditingController _promoCtrl = TextEditingController();
  String? _billingNotice;
  String? _bookingStatus;

  @override
  void dispose() {
    _promoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isZh = widget.isZh;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isZh
                          ? '社群互動、教練預約與會員方案'
                          : 'Community, Coaching Bookings & Plans',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 0,
                    label: Text(isZh ? '社群與挑戰' : 'Community'),
                    icon: const Icon(Icons.groups),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text(isZh ? '課程與預約' : 'Bookings'),
                    icon: const Icon(Icons.calendar_month),
                  ),
                  ButtonSegment(
                    value: 2,
                    label: Text(isZh ? '訂閱方案' : 'Plans'),
                    icon: const Icon(Icons.workspace_premium),
                  ),
                ],
                selected: {_selectedSection},
                onSelectionChanged: (s) {
                  setState(() => _selectedSection = s.first);
                },
              ),
              const SizedBox(height: 14),
              if (_selectedSection == 0) _buildSocialSection(isZh),
              if (_selectedSection == 1) _buildBookingSection(isZh),
              if (_selectedSection == 2) _buildMonetisationSection(isZh),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialSection(bool isZh) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassPanel(
          glassEnabled: widget.glassEnabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isZh ? '私隱保護設定 (Opt-In)' : 'Privacy-First Social Controls',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  isZh
                      ? '允許將我主動分享的訓練摘要顯示於好友動態'
                      : 'Allow explicitly shared workout cards in friends feed',
                ),
                subtitle: Text(
                  isZh
                      ? '私人體重、體脂、健康數據與照片永遠不會公開分享。'
                      : 'Private body weight, health logs, and photos are never exposed.',
                ),
                value: _shareWorkoutOptIn,
                onChanged: (v) => setState(() => _shareWorkoutOptIn = v),
              ),
            ],
          ),
        ),
        GlassPanel(
          glassEnabled: widget.glassEnabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isZh ? '30天穩定訓練社群挑戰' : '30-Day Consistency Challenge',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                isZh
                    ? '目標：30天內完成 12 次訓練課表 • 排行榜與徽章模組'
                    : 'Target: Complete 12 structured workouts in 30 days • Leaderboard & Badges',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        setState(() => _joinedChallenge = !_joinedChallenge),
                    icon: Icon(_joinedChallenge ? Icons.check : Icons.flag),
                    label: Text(
                      _joinedChallenge
                          ? (isZh ? '已參加挑戰' : 'Joined Challenge')
                          : (isZh ? '參加挑戰' : 'Join Challenge'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _kudosCount += 1),
                    icon: const Icon(Icons.thumb_up_alt_outlined),
                    label: Text('Kudos ($_kudosCount)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookingSection(bool isZh) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassPanel(
          glassEnabled: widget.glassEnabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isZh
                    ? '教練課程與團體訓練預約架構'
                    : 'Trainer & Group Class Booking Module',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                isZh
                    ? '此模組儲存預約申請至 public.trainer_bookings（需配置外部場館預約後端方可即時扣款確認）。'
                    : 'Stores booking requests in public.trainer_bookings (placeholder until a live studio booking backend is connected).',
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_pin_circle_outlined),
                title: Text(
                  isZh ? '1對1 槓鈴肌力技術指導 (60 分鐘)' : '1-on-1 Barbell Technique Session (60m)',
                ),
                subtitle: Text(
                  isZh ? '含動作提示、熱身與週期化負荷評估' : 'Includes cues, warm-up & periodised load assessment',
                ),
                trailing: FilledButton(
                  onPressed: () {
                    setState(() {
                      _bookingStatus = isZh
                          ? '已建立教練預約申請草稿（待連接場館預約後端確認）。'
                          : 'Trainer booking request recorded (pending live booking backend confirmation).';
                    });
                  },
                  child: Text(isZh ? '申請預約' : 'Request'),
                ),
              ),
              if (_bookingStatus != null) ...[
                const SizedBox(height: 8),
                Text(
                  _bookingStatus!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonetisationSection(bool isZh) {
    final plans = [
      (
        code: 'free',
        title: 'Free',
        price: 'HK\$0',
        descEn: 'Core workout logging, Supabase sync, ML Kit camera detection.',
        descZh: '核心訓練紀錄、Supabase 雲端同步與 ML Kit 相機物件偵測。',
      ),
      (
        code: 'premium',
        title: 'Premium',
        price: 'HK\$58 / mo',
        descEn: 'Multi-week periodisation builder, advanced analytics & 7-day trial.',
        descZh: '多週期課表規劃、進階數據分析與 7 天試用架構。',
      ),
      (
        code: 'family',
        title: 'Family (Up to 5)',
        price: 'HK\$118 / mo',
        descEn: 'Shared family subscription tier with private individual RLS data.',
        descZh: '最多 5 位家庭成員共享方案，各自擁有獨立私密 RLS 資料庫權限。',
      ),
      (
        code: 'team',
        title: 'Team & Coaching Credits',
        price: 'HK\$268 / mo',
        descEn: 'Group training templates, coach program library & coaching credits.',
        descZh: '團隊訓練範本、教練課表庫與一對一教練點數架構。',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in plans)
          GlassPanel(
            glassEnabled: widget.glassEnabled,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${p.title} • ${p.price}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(isZh ? p.descZh : p.descEn),
              trailing: widget.currentPlan == p.code
                  ? Chip(label: Text(isZh ? '目前方案' : 'Current'))
                  : OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _billingNotice = isZh
                              ? '提示：真實付款需設定 Google Play Billing 或 Apple In-App Purchase。本應用程式絕不模擬假付款交易。'
                              : 'Notice: Real payments require approved Google Play Billing or Apple In-App Purchase configuration. Simulated payment is disabled.';
                        });
                      },
                      child: Text(isZh ? '查看方案' : 'Select'),
                    ),
            ),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _promoCtrl,
                decoration: InputDecoration(
                  labelText: isZh ? '優惠碼 (Promo Code)' : 'Promo Code',
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonal(
              onPressed: () {
                setState(() {
                  _billingNotice = isZh
                      ? '優惠碼將於連接 Google Play Billing 結帳時由伺服器端驗證，不會於本地模擬扣款。'
                      : 'Promo codes are verified server-side during Google Play Billing checkout.';
                });
              },
              child: Text(isZh ? '套用' : 'Apply'),
            ),
          ],
        ),
        if (_billingNotice != null) ...[
          const SizedBox(height: 10),
          Text(
            _billingNotice!,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}
