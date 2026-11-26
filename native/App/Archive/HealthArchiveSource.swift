//  Story 270: one Health sample type as an archive stream, read with an anchored query. The anchor is the stream's
//  cursor: Health answers everything since it, deletions included, and a nil anchor is the whole history, paged.
//  A record carries what the mirror reads of a sample (when, how much in the app's unit, which source), never
//  Health's free-form metadata.

import ContextCore
import HealthKit

struct HealthArchiveSource: ArchiveSource {
  let store: HKHealthStore
  let type: HKSampleType
  var stream: String { ArchiveStream.health(type.identifier) }

  /// A stored anchor this build cannot read.
  struct UnreadableAnchor: Error {}

  func page(after cursor: String?, limit: Int) async throws -> ArchivePage {
    // An anchor this build cannot read (an OS upgrade, a restored database) starts the stream over from nothing:
    // the archive dedupes a re-read of the history, and a stream stuck on it would never archive again.
    let anchor = cursor.flatMap { try? Self.anchor(from: $0) }
    let descriptor = HKAnchoredObjectQueryDescriptor(predicates: [.sample(type: type)], anchor: anchor, limit: limit)
    let result = try await descriptor.result(for: store)
    var records = await Self.records(result.addedSamples, store: store)
    records += result.deletedObjects.map { ["guid": ArchiveGUID.deleted($0.uuid), "deleted": true] }
    let count = result.addedSamples.count + result.deletedObjects.count
    let newAnchor: HKQueryAnchor? = result.newAnchor
    return ArchivePage(
      records: records, cursor: try newAnchor.map(Self.string), more: count >= limit,
      restarted: cursor != nil && anchor == nil)
  }

  /// Each sample's record, and after a stored series of separate readings (a workout's heart rate: one sample
  /// holding a reading every few seconds) a record for each of them (story 270, context-grabber-kseb). A running
  /// total's series (steps, energy, distance) keeps its one record, so a day's sum counts it once.
  static func records(_ samples: [HKSample], store: HKHealthStore) async -> [[String: Any]] {
    var records: [[String: Any]] = []
    for sample in samples {
      let record = Self.record(sample)
      records.append(record)
      guard let quantity = sample as? HKDiscreteQuantitySample, quantity.count > 1,
        let kind = QuantityKind.allCases.first(where: { HealthKitSource.type($0) == quantity.quantityType })
      else { continue }
      let readings = await Self.readings(of: quantity, unit: HealthKitSource.fallbackUnit(kind), store: store)
      records += ArchiveSeries.records(parent: record, readings: readings)
    }
    return records
  }

  /// The readings a stored series holds; none when Health will not say (the sample's own record still goes).
  static func readings(of sample: HKQuantitySample, unit: HKUnit, store: HKHealthStore) async
    -> [ArchiveSeries.Reading]
  {
    await withCheckedContinuation { continuation in
      var readings: [ArchiveSeries.Reading] = []
      var resumed = false
      let query = HKQuantitySeriesSampleQuery(
        quantityType: sample.quantityType, predicate: HKQuery.predicateForObject(with: sample.uuid)
      ) { _, quantity, interval, _, done, error in
        if let quantity, let interval {
          readings.append(
            ArchiveSeries.Reading(start: interval.start, end: interval.end, value: quantity.doubleValue(for: unit)))
        }
        if (done || error != nil) && !resumed {
          resumed = true
          continuation.resume(returning: readings)
        }
      }
      store.execute(query)
    }
  }

  static func string(_ anchor: HKQueryAnchor) throws -> String {
    try NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true).base64EncodedString()
  }

  static func anchor(from cursor: String) throws -> HKQueryAnchor {
    guard let data = Data(base64Encoded: cursor),
      let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    else { throw UnreadableAnchor() }
    return anchor
  }

  /// The sample as the archive keeps it: its uuid as the guid, instants as UTC milliseconds, a quantity in the
  /// app's unit for its kind (HealthKitSource.fallbackUnit) with the unit named, a category's value, a workout's
  /// totals as the mirror reads them.
  static func record(_ sample: HKSample) -> [String: Any] {
    var record: [String: Any] = [
      "guid": ArchiveGUID.sample(sample.uuid), "type": sample.sampleType.identifier,
      "start": jsMillis(sample.startDate), "end": jsMillis(sample.endDate),
      "source": sample.sourceRevision.source.name, "source_bundle": sample.sourceRevision.source.bundleIdentifier,
    ]
    if let device = sample.device?.name { record["device"] = device }
    switch sample {
    case let quantity as HKQuantitySample:
      if let series = quantity as? HKDiscreteQuantitySample, series.count > 1 { record["count"] = series.count }
      if let kind = QuantityKind.allCases.first(where: { HealthKitSource.type($0) == quantity.quantityType }) {
        let unit = HealthKitSource.fallbackUnit(kind)
        record["value"] = quantity.quantity.doubleValue(for: unit)
        record["unit"] = unit.unitString
      }
    case let category as HKCategorySample:
      record["value"] = category.value
    case let workout as HKWorkout:
      record["activity_type"] = Int(workout.workoutActivityType.rawValue)
      record["duration_s"] = workout.duration
      if let kcal = HealthKitSource.total(workout, .activeEnergyBurned, .kilocalorie()) { record["energy_kcal"] = kcal }
      if let m = HealthKitSource.total(workout, .distanceWalkingRunning, .meter()) { record["distance_m"] = m }
    default:
      break
    }
    return record
  }
}

/// Story 270's second pass over a dense Health type (RecentSweep.denseTypes): its last 400 days newest-first, then
/// what is new, into the same stream as the anchored history, so a phone restored from a backup has its last year
/// archived within a few runs instead of after years of old history.
struct HealthRecentSource: ArchiveSource {
  let store: HKHealthStore
  let type: HKSampleType
  var stream: String { ArchiveStream.health(type.identifier) }
  var cursorKey: String { RecentSweep.cursorKey(stream) }

  func page(after cursor: String?, limit: Int) async throws -> ArchivePage {
    let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
    let sweep = RecentSweep(json: cursor) ?? .start(now: nowMs)
    let query = sweep.next(now: nowMs)
    let key = HKPredicateKeyPathStartDate
    let predicate: NSPredicate
    let order: SortOrder
    switch query {
    case .back(let from, let through):
      predicate = NSPredicate(
        format: "%K >= %@ AND %K <= %@", key, Self.date(from) as NSDate, key, Self.date(through) as NSDate)
      order = .reverse
    case .forward(let from):
      predicate = NSPredicate(format: "%K >= %@", key, Self.date(from) as NSDate)
      order = .forward
    }
    let descriptor = HKSampleQueryDescriptor(
      predicates: [.sample(type: type, predicate: predicate)],
      sortDescriptors: [SortDescriptor(\.startDate, order: order)],
      limit: limit)
    let samples = try await descriptor.result(for: store)
    let starts = samples.map { Int64(($0.startDate.timeIntervalSince1970 * 1000).rounded()) }
    let (next, more) = sweep.after(query, starts: starts, limit: limit)
    let records = await HealthArchiveSource.records(samples, store: store)
    return ArchivePage(records: records, cursor: next.json, more: more)
  }

  static func date(_ ms: Int64) -> Date { Date(timeIntervalSince1970: Double(ms) / 1000) }
}
