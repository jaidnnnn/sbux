import Foundation
import HealthKit

/// Runs a HealthKit strength-training session for the duration of a workout.
/// Besides saving the workout to Apple Health, the session is what keeps the
/// app alive with the wrist down, so the rest timer can tap you.
final class HealthManager {
    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var wanted = false

    func start(at date: Date) {
        guard HKHealthStore.isHealthDataAvailable(), session == nil else { return }
        wanted = true
        let share: Set<HKSampleType> = [HKObjectType.workoutType()]
        var read: Set<HKObjectType> = []
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) { read.insert(heartRate) }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { read.insert(energy) }
        store.requestAuthorization(toShare: share, read: read) { [weak self] _, _ in
            DispatchQueue.main.async { self?.begin(at: date) }
        }
    }

    private func begin(at date: Date) {
        guard wanted, session == nil else { return }
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: configuration)
            session.startActivity(with: date)
            builder.beginCollection(withStart: date) { _, _ in }
            self.session = session
            self.builder = builder
        } catch {
            print("Could not start workout session: \(error)")
        }
    }

    func end(save: Bool, at date: Date) {
        wanted = false
        guard let session, let builder else { return }
        self.session = nil
        self.builder = nil
        session.end()
        builder.endCollection(withEnd: date) { _, _ in
            if save {
                builder.finishWorkout { _, _ in }
            } else {
                builder.discardWorkout()
            }
        }
    }
}
