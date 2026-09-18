import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants.dart';
import '../../../core/router.dart';
import '../../../shared/widgets/item_cards.dart';
import '../../notifications/notification_service.dart';
import '../../plan/data/meal_parser_service.dart';
import '../../plan/data/plan_repository.dart';
import '../../plan/models/meal_item.dart';
import '../data/onboarding_repository.dart';

enum _Speaker { nourish, user }

class _Message {
  const _Message(this.speaker, this.text);
  final _Speaker speaker;
  final String text;
}

/// Asks for breakfast, lunch, dinner and snacks in turn, parses each answer,
/// and shows the result as cards to correct before saving.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  static const _slots = [
    MealSlot.breakfast,
    MealSlot.lunch,
    MealSlot.dinner,
    MealSlot.snack,
  ];

  static const _prompts = {
    MealSlot.breakfast: 'Tell me about your usual breakfast.',
    MealSlot.lunch: 'And lunch — what do you normally have?',
    MealSlot.dinner: 'What about dinner?',
    MealSlot.snack: 'Last one: anything you snack on most days?',
  };

  final _input = TextEditingController();
  final _scroll = ScrollController();

  final List<_Message> _messages = [];
  int _slotIndex = 0;
  bool _busy = false;

  /// Items awaiting confirmation for the current slot.
  List<MealItem>? _pending;

  MealSlot get _slot => _slots[_slotIndex];

  @override
  void initState() {
    super.initState();
    _messages.add(
      const _Message(
        _Speaker.nourish,
        "Now the part that saves you time later. Describe each meal the way "
        "you'd say it out loud — \"six eggs and two bananas\" is perfect.",
      ),
    );
    _messages.add(_Message(_Speaker.nourish, _prompts[_slot]!));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;

    setState(() {
      _messages.add(_Message(_Speaker.user, text));
      _input.clear();
      _busy = true;
    });
    _scrollToEnd();

    try {
      final result =
          await ref.read(mealParserProvider).parse(text, slot: _slot);

      if (!mounted) return;
      setState(() {
        if (result.isEmpty) {
          // Never a dead end: ask one question and let them try again.
          _messages.add(_Message(_Speaker.nourish, result.question));
        } else {
          _pending = result.items;
          if (result.needsClarification && result.question.isNotEmpty) {
            _messages.add(_Message(_Speaker.nourish, result.question));
          } else {
            _messages.add(
              const _Message(
                _Speaker.nourish,
                'Here is what I got. Fix anything that looks off.',
              ),
            );
          }
        }
      });
    } on MealParseException catch (error) {
      if (mounted) {
        setState(() => _messages.add(_Message(_Speaker.nourish, error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  Future<void> _confirm() async {
    final items = _pending;
    final planRepository = ref.read(planRepositoryProvider);
    if (items == null || planRepository == null) return;

    setState(() => _busy = true);
    try {
      await planRepository.addMeal(
        slot: _slot,
        label: 'Usual ${_slot.label.toLowerCase()}',
        items: items,
      );

      if (!mounted) return;
      setState(() {
        _pending = null;
        _messages.add(
          _Message(_Speaker.nourish, 'Saved your ${_slot.label.toLowerCase()}.'),
        );
      });
      await _advance();
    } catch (_) {
      if (mounted) {
        setState(() => _messages.add(
              const _Message(
                _Speaker.nourish,
                "That didn't save. Check your connection and try again.",
              ),
            ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  Future<void> _advance() async {
    if (_slotIndex < _slots.length - 1) {
      setState(() {
        _slotIndex++;
        _messages.add(_Message(_Speaker.nourish, _prompts[_slot]!));
      });
      _scrollToEnd();
      return;
    }
    await _finish();
  }

  /// Skipping a slot is fine — plans can be filled in from My Plan later.
  Future<void> _skip() async {
    setState(() => _pending = null);
    await _advance();
  }

  Future<void> _finish() async {
    final onboarding = ref.read(onboardingRepositoryProvider);
    if (onboarding == null) return;

    // Suggest reminder times from the quiz answers rather than guessing.
    final profile = await onboarding.loadProfile();
    final suggested = NotificationService.suggestFrom(
      gymTime: profile?.gymTime,
      mealTimes: profile?.mealTimes ?? const [],
    );

    final service = NotificationService();
    if (await service.requestPermissions()) {
      await service.scheduleDaily(
        morning: suggested.morning,
        evening: suggested.evening,
      );
    }

    await onboarding.markOnboardingDone();
    if (mounted) context.go(Routes.today);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending = _pending;

    return Scaffold(
      appBar: AppBar(
        title: Text('Your usual ${_slot.label.toLowerCase()}'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _skip,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length + (pending == null ? 0 : 1),
              itemBuilder: (context, index) {
                if (index < _messages.length) {
                  return _bubble(_messages[index]);
                }
                return ConfirmItemCards(
                  items: pending!,
                  onChanged: (items) => setState(() => _pending = items),
                  onConfirm: _busy ? null : _confirm,
                );
              },
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !_busy,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: _prompts[_slot],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.arrow_upward),
                    iconSize: 22,
                    padding: const EdgeInsets.all(14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_Message message) {
    final scheme = Theme.of(context).colorScheme;
    final fromUser = message.speaker == _Speaker.user;

    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: fromUser ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: fromUser ? scheme.onPrimary : scheme.onSurface,
            fontSize: 15,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
