import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_service.dart';
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

  // Photo picked for this report (kept in memory for upload + preview).
  Uint8List? _photoBytes;
  String? _photoPath;
  String? _photoName;
  bool _locating = false;

  final ImagePicker _imagePicker = ImagePicker();

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

  // --------------------------------------------------------------------------
  // Photo picking (image_picker: gallery, or camera on mobile)
  // --------------------------------------------------------------------------

  Future<void> _choosePhotoSource() async {
    // Flutter web only supports the gallery (file dialog) source.
    if (kIsWeb) {
      await _pickPhoto(ImageSource.gallery);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add a photo',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded,
                  color: AppColors.saffronDark),
              title: const Text('Take a photo'),
              subtitle: const Text('Photograph the person now'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.saffronDark),
              title: const Text('Choose from gallery'),
              subtitle: const Text('Use an existing picture'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _pickPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 70, // keep uploads small on the wari route
      );
      if (picked == null) return; // user cancelled
      final Uint8List bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoPath = picked.path;
        _photoName = picked.name;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Could not open the photo picker on this device.')),
      );
    }
  }

  void _removePhoto() =>
      setState(() => _photoBytes = _photoPath = _photoName = null);

  // --------------------------------------------------------------------------
  // Submit
  // --------------------------------------------------------------------------

  /// Best-effort GPS attach — only when permission is ALREADY granted, so
  /// reporting never blocks on a permission dialog. Volunteers can search
  /// around the reporter's position when the person wandered off nearby.
  Future<(double?, double?)> _attachCurrentFix() async {
    try {
      final LocationService location = context.read<LocationService>();
      if (!await location.hasPermission()) return (null, null);
      final GeoFix fix = await location.getCurrentFix();
      return (fix.latitude, fix.longitude);
    } catch (_) {
      return (null, null); // no GPS — the text place still goes through
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final AuthProvider auth = context.read<AuthProvider>();
    final LostProvider provider = context.read<LostProvider>();

    setState(() => _locating = true);
    final (double? lat, double? lng) = await _attachCurrentFix();
    if (!mounted) return;
    setState(() => _locating = false);

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
      reporterId: auth.user?.id,
      latitude: lat,
      longitude: lng,
      photoBytes: _photoBytes,
      photoFilename: _photoName,
      photoPath: _photoPath,
    );
    if (!mounted) return;
    if (report != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            report.syncPending
                ? 'Report ${report.id} saved on this device — it will reach the control-room database when online.'
                : 'Report ${report.id} saved & synced to the control-room database ✓',
          ),
        ),
      );
      _removePhoto();
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
              _PhotoPickerField(
                photoBytes: _photoBytes,
                onPick: _choosePhotoSource,
                onRemove: _removePhoto,
              ),
              const SizedBox(height: 14),
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
                label: _locating ? 'Getting location…' : 'Submit report',
                busy: provider.submitting || _locating,
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
// Photo picker field (image_picker → camera / gallery)
// =============================================================================
class _PhotoPickerField extends StatelessWidget {
  const _PhotoPickerField({
    required this.photoBytes,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? photoBytes;
  final Future<void> Function() onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (photoBytes != null) {
      return AppCard(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                photoBytes!,
                width: 76,
                height: 76,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Photo attached',
                      style: text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    'Uploaded with the report to help volunteers identify the person.',
                    style: text.bodySmall
                        ?.copyWith(color: AppColors.inkSoft, height: 1.3),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove photo',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, color: AppColors.inkSoft),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onPick,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.saffron.withValues(alpha: 0.6),
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.saffron.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_a_photo_outlined,
                  color: AppColors.saffronDark, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Add photo (optional)',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  kIsWeb
                      ? 'Choose a picture — uploaded with the report'
                      : 'Camera or gallery — uploaded with the report',
                  style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ],
        ),
      ),
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
      onRefresh: provider.refresh,
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
              _ReportAvatar(report: report, isLost: isLost),
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
                    )
                  else if (report.serverId != null)
                    const StatusChip(
                      label: 'synced',
                      color: AppColors.success,
                      softBackground: AppColors.successSoft,
                      icon: Icons.cloud_done_rounded,
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

/// Leading avatar for a report card: the person's photo when we have one
/// (uploaded URL, or the local pick), otherwise the initial-letter avatar.
class _ReportAvatar extends StatelessWidget {
  const _ReportAvatar({required this.report, required this.isLost});

  final LostPersonReport report;
  final bool isLost;

  @override
  Widget build(BuildContext context) {
    final Color tint = isLost ? AppColors.info : AppColors.success;

    final Widget fallback = CircleAvatar(
      radius: 22,
      backgroundColor: tint.withValues(alpha: 0.14),
      child: Text(
        report.personName.isEmpty
            ? '?'
            : String.fromCharCode(report.personName.runes.first).toUpperCase(),
        style: TextStyle(fontWeight: FontWeight.w900, color: tint),
      ),
    );

    final String? url = report.photoUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: tint.withValues(alpha: 0.14),
        child: ClipOval(
          child: Image.network(
            url,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, Object __, StackTrace? ___) => fallback,
          ),
        ),
      );
    }

    final String? path = report.photoPath;
    if (!kIsWeb && path != null && path.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: tint.withValues(alpha: 0.14),
        child: ClipOval(
          child: Image.file(
            File(path),
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, Object __, StackTrace? ___) => fallback,
          ),
        ),
      );
    }

    return fallback;
  }
}
