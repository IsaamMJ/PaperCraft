import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../authentication/domain/repositories/tenant_repository.dart';
import '../../domain/usecases/seed_tenant_usecase.dart';
import 'onboarding_event.dart';
import 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  final SeedTenantUseCase _seedTenantUseCase;
  final TenantRepository _tenantRepository;
  final ILogger _logger;

  OnboardingBloc({
    required SeedTenantUseCase seedTenantUseCase,
    required TenantRepository tenantRepository,
    required ILogger logger,
  })  : _seedTenantUseCase = seedTenantUseCase,
        _tenantRepository = tenantRepository,
        _logger = logger,
        super(OnboardingInitial()) {
    on<StartSeeding>(_onStartSeeding);
  }

  Future<void> _onStartSeeding(
      StartSeeding event,
      Emitter<OnboardingState> emit,
      ) async {
    try {
      _logger.info('Starting tenant seeding', category: LogCategory.auth, context: {
        'schoolType': event.schoolType.name,
      });

      final result = await _seedTenantUseCase(
        schoolType: event.schoolType,
        onProgress: (progress, currentItem) {
          emit(OnboardingSeeding(
            progress: progress,
            currentItem: currentItem,
          ));
        },
      );

      await result.fold(
            (failure) {
          _logger.error('Tenant seeding failed',
            category: LogCategory.auth,
            error: Exception(failure.message),
          );
          emit(OnboardingError(failure.message));
        },
            (tenantId) async {
          // Mark tenant as initialized
          final markResult = await _tenantRepository.markAsInitialized(tenantId);

          await markResult.fold(
                (failure) {
              _logger.warning('Failed to mark tenant as initialized',
                category: LogCategory.auth,
                context: {'tenantId': tenantId},
              );
              // Still emit success since data was created
              emit(OnboardingSuccess());
            },
                (_) {
              _logger.info('Tenant onboarding completed', category: LogCategory.auth, context: {
                'tenantId': tenantId,
                'schoolType': event.schoolType.name,
              });
              emit(OnboardingSuccess());
            },
          );
        },
      );
    } catch (e, stackTrace) {
      _logger.error('Unexpected error during onboarding',
        category: LogCategory.auth,
        error: e,
        stackTrace: stackTrace,
      );
      emit(OnboardingError('An unexpected error occurred: ${e.toString()}'));
    }
  }
}