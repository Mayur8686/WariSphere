import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../models/lost_person.dart';
import '../../../state/auth_provider.dart';
import '../../../state/lost_provider.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/status_chip.dart';

/// Lost & found: two tabs — report someone / browse active reports.
class LostPersonScreen extends StatelessWidget {
  const LostPersonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final LostProvider provider = context.watch<LostProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lost & Found'),
          bottom: TabBar(
            labelColor: AppColors.maroon,
            unselectedLabelColor: AppColors.inkSoft,
            indicatorColor: AppColors.saffron,
            dividerColor: AppColors.border,
            tabs: <Tab>[
              const Tab(text: 'Report'),
              Tab(text: 'Active reports (${provider.activeReports.length})'),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            _ReportForm(),
            _ReportsList(),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Tab 1 — report a lost (or found) person
// =============================================================================
class _ReportForm extends StatefulWidget {
  const _ReportForm();

  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _personName = TextEditingController();
  final TextEditingController _age = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _place = TextEditingController();
  final TextEditingController _reporterPhone = TextEditingController();

  LostReportType _type = LostReportType.lost;
  String _gender = AppConstants.genders.first;
  DateTime _lastSeen = DateTime.now().subtract(const Duration(hours: 1));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String? phone = context.read<AuthProvider>().user?.phone;
      if (phone != null && _reporterPhone.text.isEmpty) {
        _reporterPhone.text = phone;
      }
    });
  }

  @override
  void dispose() {
    _personName.dispose();
    _age.dispose();
    _description.dispose();
    _place.dispose();
    _reporterPhone.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_lastSeen),
    );
    if (picked == null) return;
    final DateTime now = DateTime.now();
    setState(() {
      _lastSeen = DateTime(
          now.year, now.month, now.day, picked.hour, picked.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final AuthProvider auth = context.read<AuthProvider>();
    final LostProvider provider = context.read<LostProvider>();

    final LostPersonReport? report = await provider.submit(
      type: _type,
      personName: _personName.text.trim(),
      age: int.parse(_age.text.trim()),
      gender: _gender,
      description: _description.text.trim(),
      lastSeenPlace: _place.text.trim(),
      lastSeenTime: _lastSeen,
      reporterName: auth.user?.fullName ?? 'Warkari',
      reporterPhone: _reporterPhone.text.trim(),
    );
    if (!mounted) return;
    if (report != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Report ${report.id} saved on this device — volunteers see it after sync (Phase 3).'),
        ),
      );
      DefaultTabController.of(context).animateTo(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final LostProvider provider = context.watch<LostProvider>();
    final TextTheme text = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: <Widget>[
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.info, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Reports are saved offline first and shared with help desks & volunteers once synced.',
                  style: text.bodySmall?.copyWith(height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SegmentedButton<LostReportType>(
                segments: const <ButtonSegment<LostReportType>>[
                  ButtonSegment<LostReportType>(
                    value: LostReportType.lost,
                    icon: Icon(Icons.person_off_rounded, size: 18),
                    label: Text('Lost person'),
                  ),
                  ButtonSegment<LostReportType>(
                    value: LostReportType.found,
                    icon: Icon(Icons.person_pin_circle_rounded, size: 18),
                    label: Text('Found a person'),
                  ),
                ],
                selected: <LostReportType>{_type},
                onSelectionChanged: (Set<LostReportType> s) =>
                    setState(() => _type = s.first),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: _type == LostReportType.lost
                    ? 'Name of the lost person'
                    : 'Name (or "Unknown")',
                controller: _personName,
                prefixIcon: Icons.person_outline_rounded,
                validator: (String? v) =>
                    (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      label: 'Approx. age',
                      controller: _age,
                      keyboardType: TextInputType.number,
                      prefixIcon: Icons.cake_outlined,
                      validator: Validators.age,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Gender',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _gender,
                          isExpanded: true,
                          items: AppConstants.genders
                              .map((String g) => DropdownMenuItem<String>(
                                    value: g,
                                    child: Text(g),
                                  ))
                              .toList(),
                          onChanged: (String? v) =>
                              setState(() => _gender = v ?? _gender),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Description',
                hint: 'Clothes, build, marks, language they speak…',
                controller: _description,
                maxLines: 3,
                prefixIcon: Icons.description_outlined,
                validator: (String? v) => (v == null || v.trim().length < 10)
                    ? 'Add a short description (min 10 chars)'
                    : null,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Last seen place',
                hint: 'e.g. Near Yavat medical camp',
                controller: _place,
                prefixIcon: Icons.place_outlined,
                validator: (String? v) =>
                    (v == null || v.trim().isEmpty) ? 'Please enter a place' : null,
              ),
              const SizedBox(height: 14),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                onTap: _pickTime,
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.schedule_rounded,
                        size: 20, color: AppColors.inkSoft),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Last seen around ${Formatters.timeOnly(_lastSeen)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Text(
                      'Tap to change',
                      style: TextStyle(fontSize: 12, color: AppColors.saffronDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Your contact number',
                controller: _reporterPhone,
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_in_talk_rounded,
                validator: Validators.phone,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Submit report',
                busy: provider.submitting,
                icon: Icons.campaign_outlined,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Tab 2 — active reports list
// =============================================================================
class _ReportsList extends StatelessWidget {
  const _ReportsList();

  @override
  Widget build(BuildContext context) {
    final LostProvider provider = context.watch<LostProvider>();
    final List<LostPersonReport> reports = provider.reports;

    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (reports.isEmpty) {
      return const EmptyState(
        icon: Icons.person_search_rounded,
        title: 'No reports yet',
        message: 'Lost or found someone on the wari? Report it here.',
      );
    }
    return RefreshIndicator(
      onRefresh: provider.load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        itemCount: reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (BuildContext ctx, int i) => _ReportTile(report: reports[i]),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report});

  final LostPersonReport report;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool isLost = report.type == LostReportType.lost;
    final bool active = report.status == LostReportStatus.active;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 22,
                backgroundColor: (isLost ? AppColors.info : AppColors.success)
                    .withValues(alpha: 0.14),
                child: Text(
                  report.personName.isEmpty
                      ? '?'
                      : String.fromCharCode(report.personName.runes.first)
                          .toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: isLost ? AppColors.info : AppColors.success,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      report.personName,
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${report.age} yrs • ${report.gender} • ${report.lastSeenPlace}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  StatusChip(
                    label: isLost ? 'LOST' : 'FOUND',
                    color: isLost ? AppColors.info : AppColors.success,
                  ),
                  const SizedBox(height: 4),
                  if (!active)
                    const StatusChip(
                      label: 'REUNITED 🙏',
                      color: AppColors.success,
                      softBackground: AppColors.successSoft,
                    )
                  else if (report.syncPending)
                    const StatusChip(
                      label: 'offline',
                      color: AppColors.warning,
                      softBackground: AppColors.warningSoft,
                      icon: Icons.cloud_off_rounded,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            report.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Icon(Icons.schedule_rounded, size: 14, color: AppColors.inkSoft),
              const SizedBox(width: 4),
              Text(
                'Last seen ${Formatters.timeAgo(report.lastSeenTime)} • reported ${Formatters.timeAgo(report.createdAt)}',
                style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
              ),
              const Spacer(),
              if (active)
                TextButton(
                  onPressed: () async {
                    await context.read<LostProvider>().markReunited(report.id);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Wonderful news! Marked as reunited.')),
                    );
                  },
                  child: const Text('Mark reunited'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
