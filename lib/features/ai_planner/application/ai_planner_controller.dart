// Tracks plan generation, selected blocks, and saving decisions for the UI.

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/models.dart';
import '../../../core/network/mento_ai_client.dart';
import '../../ai_assistant/application/ai_assistant_controller.dart';
import 'ai_planner_service.dart';

class AiPlannerState {
  const AiPlannerState({
    this.result,
    this.selectedBlockIds = const {},
    this.generating = false,
    this.error,
  });

  final PlanGenerationResult? result;
  final Set<String> selectedBlockIds;
  final bool generating;
  final String? error;

  AiPlannerState copyWith({
    PlanGenerationResult? result,
    Set<String>? selectedBlockIds,
    bool? generating,
    String? error,
    bool clearError = false,
  }) => AiPlannerState(
    result: result ?? this.result,
    selectedBlockIds: selectedBlockIds ?? this.selectedBlockIds,
    generating: generating ?? this.generating,
    error: clearError ? null : error ?? this.error,
  );
}

final aiPlannerProvider = NotifierProvider<AiPlannerController, AiPlannerState>(
  AiPlannerController.new,
);

class AiPlannerController extends Notifier<AiPlannerState> {
  CancelToken? _cancelToken;

  @override
  AiPlannerState build() {
    ref.onDispose(() => _cancelToken?.cancel('disposed'));
    return const AiPlannerState();
  }

  Future<void> generate(StudyPlannerInput input) async {
    if (state.generating) return;
    state = state.copyWith(generating: true, clearError: true);
    _cancelToken = CancelToken();
    try {
      final result = await AiPlannerService(
        ref.read(aiClientProvider),
      ).generate(input, cancelToken: _cancelToken);
      state = AiPlannerState(
        result: result,
        selectedBlockIds: result.plan.blocks.map((block) => block.id).toSet(),
      );
    } catch (error) {
      final message =
          error is AiClientFailure ? error.message : error.toString();
      state = state.copyWith(generating: false, error: message);
    } finally {
      _cancelToken = null;
    }
  }

  void cancel() {
    _cancelToken?.cancel('user-cancelled');
    state = state.copyWith(
      generating: false,
      error: 'Plan generation cancelled.',
    );
  }

  void toggleBlock(String id) {
    final selected = {...state.selectedBlockIds};
    selected.contains(id) ? selected.remove(id) : selected.add(id);
    state = state.copyWith(selectedBlockIds: selected);
  }

  void selectAll() {
    state = state.copyWith(
      selectedBlockIds:
          state.result?.plan.blocks.map((block) => block.id).toSet() ?? {},
    );
  }

  void rejectAll() => state = state.copyWith(selectedBlockIds: const {});

  void updateBlock(
    String id, {
    required DateTime startAt,
    required DateTime endAt,
  }) {
    final result = state.result;
    if (result == null || !endAt.isAfter(startAt)) return;
    final blocks = [
      for (final block in result.plan.blocks)
        if (block.id == id)
          block.copyWith(startAt: startAt, endAt: endAt)
        else
          block,
    ]..sort((a, b) => a.startAt.compareTo(b.startAt));
    final plan = _copyPlan(result.plan, blocks: blocks);
    state = state.copyWith(
      result: PlanGenerationResult(
        plan: plan,
        usedFallback: result.usedFallback,
        message: result.message,
      ),
    );
  }

  StudyPlan? acceptedSelection() {
    final result = state.result;
    if (result == null || state.selectedBlockIds.isEmpty) return null;
    final selected =
        result.plan.blocks
            .where((block) => state.selectedBlockIds.contains(block.id))
            .map((block) => block.copyWith(status: PlanBlockStatus.accepted))
            .toList();
    return _copyPlan(result.plan, blocks: selected, accepted: true);
  }

  StudyPlan _copyPlan(
    StudyPlan plan, {
    required List<PlanBlock> blocks,
    bool? accepted,
  }) => StudyPlan(
    id: plan.id,
    userId: plan.userId,
    generatedAt: plan.generatedAt,
    rangeStart: plan.rangeStart,
    rangeEnd: plan.rangeEnd,
    source: plan.source,
    blocks: blocks,
    maxDailyMinutes: plan.maxDailyMinutes,
    isAccepted: accepted ?? plan.isAccepted,
    rationale: plan.rationale,
    unplannedMinutes: plan.unplannedMinutes,
    schemaVersion: plan.schemaVersion,
  );
}
