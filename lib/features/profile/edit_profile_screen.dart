import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_date_field.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/auth/otp/contact_badges.dart';
import 'package:homizi/features/profile/avatar_actions.dart';
import 'package:homizi/features/profile/domain/profile_contact.dart';
import 'package:homizi/features/profile/occupation_picker.dart';
import 'package:homizi/features/profile/profile_dashboard_model.dart';
import 'package:homizi/features/profile/profile_photo_viewer.dart';
import 'package:homizi/features/profile/profile_section_page.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/ui/kit/kit.dart';

/// Instagram-style editor for the signed-in profile.
///
/// Done returns the updated draft. The caller saves it the same way the
/// section editors used to, and shows the saved confirmation.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({
    required this.draft,
    required this.name,
    required this.onPhotoSaved,
    this.photoBytes,
    this.photoRef,
    this.verified = false,
    super.key,
  });

  final ProfileCreateDraft draft;
  final String name;
  final Uint8List? photoBytes;
  final String? photoRef;
  final bool verified;
  final ValueChanged<String?> onPhotoSaved;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late String _nickname;
  late String _surname;
  late String _firstName;
  late String _lastName;
  late String _about;
  late String _company;
  late String _city;
  String? _occupation;
  String? _gender;
  int? _birthDay;
  int? _birthMonth;
  int? _birthYear;
  late List<String> _languages;
  String? _smoking;
  String? _drinking;
  String? _food;
  String? _cooking;
  String? _cleaning;
  String? _pets;
  late List<String> _tags;
  late List<String> _documents;
  Uint8List? _bytes;
  String? _photoRef;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _nickname = draft.nickname;
    _surname = draft.surname;
    _firstName = draft.firstName;
    _lastName = draft.lastName;
    _about = draft.about;
    _company = draft.companyName;
    _city = draft.city;
    _occupation = draft.occupation;
    _gender = draft.gender;
    _birthDay = draft.birthDay;
    _birthMonth = draft.birthMonth;
    _birthYear = draft.birthYear;
    _languages = [...draft.languages];
    _smoking = draft.smoking;
    _drinking = draft.drinking;
    _food = draft.food;
    _cooking = draft.cooking;
    _cleaning = draft.cleaning;
    _pets = draft.pets;
    _tags = [...draft.tags];
    _documents = [...draft.documents];
    _bytes = widget.photoBytes;
    _photoRef = widget.photoRef;
  }

  ProfileCreateDraft _result() {
    return widget.draft.copyWith(
      nickname: _nickname.trim(),
      surname: _surname.trim(),
      firstName: _firstName.trim(),
      lastName: _lastName.trim(),
      about: _about.trim(),
      companyName: _company.trim(),
      city: _city.trim(),
      occupation: _occupation,
      gender: _gender,
      birthDay: _birthDay,
      birthMonth: _birthMonth,
      birthYear: _birthYear,
      languages: _languages,
      smoking: _smoking,
      drinking: _drinking,
      food: _food,
      cooking: _cooking,
      cleaning: _cleaning,
      pets: _pets,
      tags: _tags,
      documents: _documents,
    );
  }

  String get _fullName {
    return [
      _firstName.trim(),
      _lastName.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
  }

  String _birthLabel() {
    return profileBirthLabel(
          widget.draft.copyWith(
            birthDay: _birthDay,
            birthMonth: _birthMonth,
            birthYear: _birthYear,
          ),
        ) ??
        '';
  }

  Future<void> _changePhoto() async {
    await chooseProfilePhoto(
      context: context,
      gateway: ref.read(accountGatewayProvider),
      photoRef: _photoRef,
      onSaved: (next) {
        widget.onPhotoSaved(next);
        if (!mounted) {
          return;
        }
        setState(() {
          _photoRef = next;
          _bytes = _bytesFrom(next);
        });
      },
    );
  }

  Uint8List? _bytesFrom(String? ref) {
    final path = ref?.trim() ?? '';
    if (!path.startsWith('data:')) {
      return null;
    }
    final comma = path.indexOf(',');
    if (comma < 0) {
      return null;
    }
    try {
      return base64Decode(path.substring(comma + 1));
    } on Object {
      return null;
    }
  }

  void _openViewer() {
    openProfilePhotoViewer(
      context: context,
      heroTag: editProfilePhotoHero,
      name: widget.name,
      bytes: _bytes,
      photoRef: _photoRef,
      onChangePhoto: () => unawaited(_changePhoto()),
    );
  }

  Future<void> _editText({
    required String title,
    required String initial,
    required ValueChanged<String> apply,
    int maxLines = 1,
    Key? fieldKey,
    String? helper,
    TextCapitalization capitalization = TextCapitalization.none,
  }) async {
    final next = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => _TextFieldPage(
          title: title,
          initial: initial,
          maxLines: maxLines,
          fieldKey: fieldKey,
          helper: helper,
          capitalization: capitalization,
        ),
      ),
    );
    if (next == null || !mounted) {
      return;
    }
    setState(() => apply(next.trim()));
  }

  Future<void> _editFullName() async {
    final next = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => _TextFieldPage(
          title: 'Full name',
          initial: _fullName,
          fieldKey: const Key('profile-edit-full-name-field'),
          helper: 'Stays private. It is not part of your public name.',
          capitalization: TextCapitalization.words,
        ),
      ),
    );
    if (next == null || !mounted) {
      return;
    }
    final legal = splitProfileLegalName(next);
    if (legal.$1.isEmpty) {
      return;
    }
    setState(() {
      _firstName = legal.$1;
      _lastName = legal.$2;
    });
  }

  Future<void> _editOccupation() async {
    final next = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => _OccupationPage(selected: _occupation),
      ),
    );
    if (next == null || !mounted) {
      return;
    }
    setState(() => _occupation = next);
  }

  Future<void> _editChoice({
    required String title,
    required List<String> options,
    required String? selected,
    required ValueChanged<String> apply,
  }) async {
    final next = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) =>
            _ChoicePage(title: title, options: options, selected: selected),
      ),
    );
    if (next == null || !mounted) {
      return;
    }
    setState(() => apply(next));
  }

  Future<void> _editLanguages() async {
    final next = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute<List<String>>(
        builder: (context) => _LanguagesPage(selected: _languages),
      ),
    );
    if (next == null || !mounted) {
      return;
    }
    setState(() => _languages = next);
  }

  Future<void> _editBirth() async {
    final now = DateTime.now();
    final picked = await pickHomiziDate(
      context,
      initial: _birthYear == null
          ? null
          : DateTime(_birthYear!, _birthMonth ?? 1, _birthDay ?? 1),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _birthDay = picked.day;
      _birthMonth = picked.month;
      _birthYear = picked.year;
    });
  }

  Future<void> _editCity() async {
    final next = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => _CityPage(initial: _city),
      ),
    );
    if (next == null || !mounted) {
      return;
    }
    setState(() => _city = next.trim());
  }

  Future<void> _editTags() async {
    final next = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (context) => _TextFieldPage(
          title: 'Tags',
          initial: _tags.join(', '),
          helper: 'Separate tags with commas.',
        ),
      ),
    );
    if (next == null || !mounted) {
      return;
    }
    setState(() {
      _tags = [
        for (final tag in next.split(','))
          if (tag.trim().isNotEmpty) tag.trim(),
      ];
    });
  }

  Future<void> _addDocument() async {
    final name = TextEditingController();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => ProfileSectionPage(
          title: 'Add Document',
          child: KitTextField(
            fieldKey: const Key('profile-edit-document-field'),
            label: 'Document name',
            controller: name,
            hint: 'Rent agreement',
            icon: RealLifeIcons.document,
            textCapitalization: TextCapitalization.words,
          ),
        ),
      ),
    );
    final label = name.text.trim();
    name.dispose();
    if (saved == true && label.isNotEmpty && mounted) {
      setState(() => _documents = [..._documents, label]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = profileRoleChip(ref.watch(currentRoleProvider)?.name);
    final fullName = _fullName;
    final birth = _birthLabel();
    final gender = wizardGenderLabel(_gender);
    return ContentScaffold(
      scaffoldKey: const Key('profile-edit-screen'),
      title: 'Edit profile',
      pageId: 'edit-profile',
      onBack: () => Navigator.of(context).pop(),
      leadingKey: const Key('profile-edit-cancel'),
      primaryLabel: 'Save',
      primaryKey: const Key('profile-edit-done'),
      onPrimary: () => Navigator.of(context).pop(_result()),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              key: const Key('profile-edit-photo'),
              onTap: _openViewer,
              child: Hero(
                tag: editProfilePhotoHero,
                child: ClipOval(
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: ProfilePortrait(
                      name: widget.name,
                      bytes: _bytes,
                      photoRef: _photoRef,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: TextButton(
              key: const Key('profile-change-photo'),
              onPressed: () => unawaited(_changePhoto()),
              child: Text(
                homiziText(context, 'Change profile photo'),
                style: const TextStyle(
                  color: HomiziColors.logoOrange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: HomiziColors.line),
          _row(
            label: 'Name',
            value: _nickname,
            empty: 'Add your name',
            rowKey: const Key('profile-edit-name'),
            onTap: () => unawaited(
              _editText(
                title: 'Name',
                initial: _nickname,
                capitalization: TextCapitalization.words,
                apply: (value) => _nickname = value,
              ),
            ),
          ),
          _row(
            label: 'Surname',
            value: _surname,
            empty: 'Add your surname',
            rowKey: const Key('profile-edit-surname'),
            onTap: () => unawaited(
              _editText(
                title: 'Surname',
                initial: _surname,
                capitalization: TextCapitalization.words,
                apply: (value) => _surname = value,
              ),
            ),
          ),
          _row(
            label: 'Full name',
            value: fullName,
            empty: 'Full name stays private',
            caption: 'Stays private',
            rowKey: const Key('profile-edit-full-name'),
            onTap: () => unawaited(_editFullName()),
          ),
          _row(
            label: 'Bio',
            value: _about,
            empty: 'Add a bio',
            rowKey: const Key('profile-edit-about'),
            onTap: () => unawaited(
              _editText(
                title: 'Bio',
                initial: _about,
                maxLines: 5,
                fieldKey: const Key('profile-edit-about-field'),
                capitalization: TextCapitalization.sentences,
                apply: (value) => _about = value,
              ),
            ),
          ),
          _row(
            label: 'Occupation',
            value: _occupation ?? '',
            empty: 'Add your occupation',
            rowKey: const Key('profile-edit-occupation'),
            onTap: () => unawaited(_editOccupation()),
          ),
          _row(
            label: 'Company',
            value: _company,
            empty: 'Add your company',
            rowKey: const Key('profile-edit-company'),
            onTap: () => unawaited(
              _editText(
                title: 'Company',
                initial: _company,
                capitalization: TextCapitalization.words,
                apply: (value) => _company = value,
              ),
            ),
          ),
          _row(
            label: 'Date of birth',
            value: birth,
            empty: 'Add your date of birth',
            rowKey: const Key('profile-edit-dob'),
            onTap: () => unawaited(_editBirth()),
          ),
          _row(
            label: 'Current city',
            value: _city,
            empty: 'Add your city',
            rowKey: const Key('profile-edit-city-row'),
            onTap: () => unawaited(_editCity()),
          ),
          _row(
            label: 'Gender',
            value: gender,
            empty: 'Add your gender',
            rowKey: const Key('profile-edit-gender'),
            onTap: () => unawaited(
              _editChoice(
                title: 'Gender',
                options: profileGenderOptions,
                selected: _gender,
                apply: (value) => _gender = value,
              ),
            ),
          ),
          _row(
            label: 'Languages',
            value: _languages.join(', '),
            empty: 'Add languages',
            rowKey: const Key('profile-edit-languages'),
            onTap: () => unawaited(_editLanguages()),
          ),
          _choiceRow('Smoking', _smoking, profileSmokingOptions, (value) {
            _smoking = value;
          }),
          _choiceRow('Drinking', _drinking, profileDrinkingOptions, (value) {
            _drinking = value;
          }),
          _choiceRow('Food', _food, profileFoodOptions, (value) {
            _food = value;
          }),
          _choiceRow('Cooking', _cooking, profileCookingOptions, (value) {
            _cooking = value;
          }),
          _choiceRow('Cleaning', _cleaning, profileCleaningOptions, (value) {
            _cleaning = value;
          }),
          _choiceRow('Pets', _pets, profilePetOptions, (value) {
            _pets = value;
          }),
          _row(
            label: 'Tags',
            value: _tags.join(', '),
            empty: 'Add tags',
            rowKey: const Key('profile-edit-tags'),
            onTap: () => unawaited(_editTags()),
          ),
          _row(
            label: 'Documents',
            value: _documents.join(', '),
            empty: 'Add a document',
            rowKey: const Key('profile-edit-documents'),
            onTap: () => unawaited(_addDocument()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
            child: Text(
              homiziText(context, 'Profile information'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _link(
            label: 'Preferences',
            value: 'Priorities',
            rowKey: const Key('profile-edit-preferences'),
            onTap: () => context.push(RoutePaths.priorities),
          ),
          _link(
            label: 'Verification',
            value: widget.verified ? 'Verified' : 'Get verified',
            rowKey: const Key('profile-edit-verification'),
            onTap: () => context.push(RoutePaths.verifyIdentity),
          ),
          _link(
            label: 'Contact options',
            value: 'Email, phone',
            rowKey: const Key('profile-edit-contact'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const ProfileContactOptionsPage(),
                ),
              );
            },
          ),
          _link(
            label: 'Role',
            value: role,
            rowKey: const Key('profile-change-role'),
            onTap: () => context.push(RoutePaths.role),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _choiceRow(
    String label,
    String? value,
    List<String> options,
    ValueChanged<String> apply,
  ) {
    return _row(
      label: label,
      value: value ?? '',
      empty: 'Add',
      onTap: () => unawaited(
        _editChoice(
          title: label,
          options: options,
          selected: value,
          apply: apply,
        ),
      ),
    );
  }

  Widget _row({
    required String label,
    required String value,
    required String empty,
    required VoidCallback onTap,
    Key? rowKey,
    String? caption,
  }) {
    final missing = value.trim().isEmpty;
    return _FormRow(
      label: label,
      value: missing ? empty : value.trim(),
      placeholder: missing,
      caption: caption,
      rowKey: rowKey,
      onTap: onTap,
    );
  }

  Widget _link({
    required String label,
    required String value,
    required Key rowKey,
    required VoidCallback onTap,
  }) {
    return _FormRow(
      label: label,
      value: value,
      rowKey: rowKey,
      chevron: true,
      onTap: onTap,
    );
  }
}

class ProfileContactOptionsPage extends ConsumerWidget {
  const ProfileContactOptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final contact = shownContact(session.contact);
    return ContentScaffold(
      scaffoldKey: const Key('profile-contact-options'),
      title: 'Contact options',
      pageId: 'profile-contact',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          ContactVerifyBadges(
            email: contact.email,
            phone: profilePhoneDisplay(
              phoneE164: session.phoneE164,
              fallback: contact.phone,
            ),
            emailVerified: session.emailVerified,
            phoneVerified: session.phoneVerified,
            onVerifyEmail: session.emailVerified
                ? null
                : () =>
                      context.push('${RoutePaths.verifyContact}?channel=email'),
            onVerifyPhone: session.phoneVerified
                ? null
                : () =>
                      context.push('${RoutePaths.verifyContact}?channel=phone'),
          ),
        ],
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({
    required this.label,
    required this.value,
    required this.onTap,
    this.rowKey,
    this.caption,
    this.placeholder = false,
    this.chevron = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final Key? rowKey;
  final String? caption;
  final bool placeholder;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final captionText = caption;
    return Column(
      children: [
        InkWell(
          key: rowKey,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 12, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 112,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      homiziText(context, label),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        placeholder ? homiziText(context, value) : value,
                        style: TextStyle(
                          color: placeholder
                              ? HomiziColors.muted
                              : HomiziColors.ink,
                          fontSize: 15,
                          height: 1.35,
                        ),
                      ),
                      if (captionText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            homiziText(context, captionText),
                            style: const TextStyle(
                              color: HomiziColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (chevron)
                  const Padding(
                    padding: EdgeInsets.only(left: 4, top: 1),
                    child: Icon(
                      Icons.chevron_right,
                      color: HomiziColors.muted,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 0.5, thickness: 0.5, color: HomiziColors.line),
      ],
    );
  }
}

class _TextFieldPage extends StatefulWidget {
  const _TextFieldPage({
    required this.title,
    required this.initial,
    this.maxLines = 1,
    this.fieldKey,
    this.helper,
    this.capitalization = TextCapitalization.none,
  });

  final String title;
  final String initial;
  final int maxLines;
  final Key? fieldKey;
  final String? helper;
  final TextCapitalization capitalization;

  @override
  State<_TextFieldPage> createState() => _TextFieldPageState();
}

class _TextFieldPageState extends State<_TextFieldPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final helper = widget.helper;
    final icon = switch (widget.title) {
      'Surname' || 'Full name' || 'Name' => RealLifeIcons.person,
      'Company' => RealLifeIcons.briefcase,
      'Bio' => RealLifeIcons.lifestyle,
      'Tags' => RealLifeIcons.badge,
      _ => RealLifeIcons.person,
    };
    return ContentScaffold(
      title: widget.title,
      pageId: 'profile-text-${widget.title}',
      onBack: () => Navigator.of(context).pop(),
      primaryLabel: 'Save',
      onPrimary: () => Navigator.of(context).pop(_controller.text),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          KitTextField(
            fieldKey: widget.fieldKey,
            label: widget.title,
            controller: _controller,
            hint: widget.title,
            helper: helper,
            icon: icon,
            maxLines: widget.maxLines,
            autofocus: true,
            textCapitalization: widget.capitalization,
          ),
        ],
      ),
    );
  }
}

class _ChoicePage extends StatelessWidget {
  const _ChoicePage({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<String> options;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    var current = selected;
    return StatefulBuilder(
      builder: (context, setLocal) {
        return ContentScaffold(
          title: title,
          pageId: 'profile-choice-$title',
          onBack: () => Navigator.of(context).pop(),
          primaryLabel: 'Save',
          onPrimary: () {
            final value = current;
            if (value != null) {
              Navigator.of(context).pop(value);
            }
          },
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              KitChoiceField<String>(
                label: title,
                icon: iconForChoice(title),
                selected: current,
                options: [
                  for (final option in options)
                    KitOption(
                      value: option,
                      label: option,
                      icon: iconForChoice(option),
                    ),
                ],
                onChanged: (value) => setLocal(() => current = value),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OccupationPage extends StatelessWidget {
  const _OccupationPage({required this.selected});

  final String? selected;

  @override
  Widget build(BuildContext context) {
    var current = selected;
    return StatefulBuilder(
      builder: (context, setLocal) {
        return ContentScaffold(
          title: 'Occupation',
          pageId: 'profile-occupation',
          onBack: () => Navigator.of(context).pop(),
          primaryLabel: 'Save',
          onPrimary: () {
            final value = current;
            if (value != null && value.isNotEmpty) {
              Navigator.of(context).pop(value);
            }
          },
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              OccupationPicker(
                selected: current,
                onSelected: (value) => setLocal(() => current = value),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LanguagesPage extends StatefulWidget {
  const _LanguagesPage({required this.selected});

  final List<String> selected;

  @override
  State<_LanguagesPage> createState() => _LanguagesPageState();
}

class _LanguagesPageState extends State<_LanguagesPage> {
  late final Set<String> _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    return ContentScaffold(
      title: 'Languages',
      pageId: 'profile-languages',
      onBack: () => Navigator.of(context).pop(),
      primaryLabel: 'Save',
      onPrimary: () => Navigator.of(context).pop(_selected.toList()),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          KitMultiChoice(
            label: 'Languages you know',
            icon: RealLifeIcons.language,
            selected: _selected,
            options: [
              for (final language in profileWizardLanguages)
                KitOption(
                  value: language,
                  label: language,
                  icon: RealLifeIcons.language,
                ),
            ],
            onChanged: (next) => setState(() {
              _selected
                ..clear()
                ..addAll(next);
            }),
          ),
        ],
      ),
    );
  }
}

class _CityPage extends StatefulWidget {
  const _CityPage({required this.initial});

  final String initial;

  @override
  State<_CityPage> createState() => _CityPageState();
}

class _CityPageState extends State<_CityPage> {
  late final TextEditingController _city;
  late String _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial.trim();
    _city = TextEditingController(text: _picked);
  }

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContentScaffold(
      title: 'Current city',
      pageId: 'profile-city',
      onBack: () => Navigator.of(context).pop(),
      primaryLabel: 'Save',
      onPrimary: () => Navigator.of(context).pop(_picked),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          PlaceAutocompleteField(
            fieldKey: const Key('profile-edit-city'),
            controller: _city,
            labelText: 'Current City',
            hintText: 'Bengaluru',
            prefixIcon: const Icon(
              RealLifeIcons.pin,
              color: HomiziColors.logoOrange,
            ),
            stackedLabel: true,
            pickOnly: true,
            includedPrimaryTypes: const ['locality'],
            textCapitalization: TextCapitalization.words,
            onSelected: (place) {
              if (place.manual) {
                return;
              }
              final name = (place.city ?? place.label.split(',').first).trim();
              if (name.isEmpty) {
                return;
              }
              _picked = name;
              _city.text = name;
              if (place.hasCoordinates) {
                unawaited(
                  writeDeviceString(
                    'flutter.homizi.profile_place',
                    jsonEncode({
                      'label': place.label,
                      'latitude': place.latitude,
                      'longitude': place.longitude,
                    }),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
