import Foundation

/// The schema version the app reads and writes.
///
/// Change this typealias and add a stage to ``ThoughtMigrationPlan`` to move the store forward;
/// nothing else in `Persistence` names a version.
typealias ThoughtEntity = ThoughtSchemaV2.ThoughtEntity
