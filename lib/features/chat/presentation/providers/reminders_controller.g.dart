// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminders_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reloj inyectable (tests lo sobreescriben).

@ProviderFor(reminderClock)
final reminderClockProvider = ReminderClockProvider._();

/// Reloj inyectable (tests lo sobreescriben).

final class ReminderClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  /// Reloj inyectable (tests lo sobreescriben).
  ReminderClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reminderClockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reminderClockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return reminderClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$reminderClockHash() => r'487cf70baca1d734c2674f9fafa77f1f394b1bcf';

/// Recordatorios pendientes de un chat. Si la carga falla, el estado es error
/// (la UI reintenta con `ref.invalidate`); si una acción falla, la lista queda
/// sin cambios y la acción devuelve false.

@ProviderFor(RemindersController)
final remindersControllerProvider = RemindersControllerFamily._();

/// Recordatorios pendientes de un chat. Si la carga falla, el estado es error
/// (la UI reintenta con `ref.invalidate`); si una acción falla, la lista queda
/// sin cambios y la acción devuelve false.
final class RemindersControllerProvider
    extends $AsyncNotifierProvider<RemindersController, List<Reminder>> {
  /// Recordatorios pendientes de un chat. Si la carga falla, el estado es error
  /// (la UI reintenta con `ref.invalidate`); si una acción falla, la lista queda
  /// sin cambios y la acción devuelve false.
  RemindersControllerProvider._({
    required RemindersControllerFamily super.from,
    required ChatKey super.argument,
  }) : super(
         retry: null,
         name: r'remindersControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$remindersControllerHash();

  @override
  String toString() {
    return r'remindersControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  RemindersController create() => RemindersController();

  @override
  bool operator ==(Object other) {
    return other is RemindersControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$remindersControllerHash() =>
    r'e8596c34813025df755db76d3c7a4df9dc21bfc0';

/// Recordatorios pendientes de un chat. Si la carga falla, el estado es error
/// (la UI reintenta con `ref.invalidate`); si una acción falla, la lista queda
/// sin cambios y la acción devuelve false.

final class RemindersControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          RemindersController,
          AsyncValue<List<Reminder>>,
          List<Reminder>,
          FutureOr<List<Reminder>>,
          ChatKey
        > {
  RemindersControllerFamily._()
    : super(
        retry: null,
        name: r'remindersControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Recordatorios pendientes de un chat. Si la carga falla, el estado es error
  /// (la UI reintenta con `ref.invalidate`); si una acción falla, la lista queda
  /// sin cambios y la acción devuelve false.

  RemindersControllerProvider call(ChatKey chatKey) =>
      RemindersControllerProvider._(argument: chatKey, from: this);

  @override
  String toString() => r'remindersControllerProvider';
}

/// Recordatorios pendientes de un chat. Si la carga falla, el estado es error
/// (la UI reintenta con `ref.invalidate`); si una acción falla, la lista queda
/// sin cambios y la acción devuelve false.

abstract class _$RemindersController extends $AsyncNotifier<List<Reminder>> {
  late final _$args = ref.$arg as ChatKey;
  ChatKey get chatKey => _$args;

  FutureOr<List<Reminder>> build(ChatKey chatKey);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Reminder>>, List<Reminder>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Reminder>>, List<Reminder>>,
              AsyncValue<List<Reminder>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
