import Combine
import Foundation

@MainActor
final class StatusStore: ObservableObject {
    @Published var snapshot = VeilSnapshot.placeholder
    @Published var taskStatus = TaskStatusSnapshot.inactive
    @Published var modelGrowth: ModelGrowthCompactStatus?
    @Published var powerKeepAlive = PowerKeepAliveSnapshot.inactive

    var renderedSnapshot: VeilSnapshot {
        var rendered = snapshot
        rendered.taskStatus = taskStatus
        rendered.modelGrowth = modelGrowth
        rendered.powerKeepAlive = powerKeepAlive
        return rendered
    }
}
