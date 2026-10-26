import Foundation
import ComplianceKitCore

/// CNSSI policy is owned by this consumer; generic parsing and generation live in ComplianceKit.
public actor CNSSIWorkflow {
    public init() {}

    public func plan(repositoryURL: URL, dataDirectory: URL, targetVersion: MacOSVersion,
                     profile: ImpactProfile, exclusions: [String: String] = [:]) async throws -> CNSSIPlan {
        let sources: [BaselineGenerationRequest.MappingSource] = [
            .init(id: "confidentiality", url: dataDirectory.appendingPathComponent("cnssi-1253_confidentiality_\(profile.confidentiality.rawValue).csv")),
            .init(id: "integrity", url: dataDirectory.appendingPathComponent("cnssi-1253_integrity_\(profile.integrity.rawValue).csv")),
            .init(id: "availability", url: dataDirectory.appendingPathComponent("cnssi-1253_availability_\(profile.availability.rawValue).csv"))
        ]
        let tag = "cnssi-1253_" + profile.name
        let plan = try await BaselineWorkflow().plan(BaselineGenerationRequest(
            repositoryURL: repositoryURL, targetVersion: targetVersion,
            baselineID: "\(tag)_macos_\(targetVersion.major).\(targetVersion.minor)", baselineTag: tag,
            framework: "cnssi-1253", title: "CNSSI-1253 \(profile.name) — macOS \(targetVersion.major).\(targetVersion.minor)",
            description: "Confidentiality: \(profile.confidentiality.rawValue); integrity: \(profile.integrity.rawValue); availability: \(profile.availability.rawValue). Generated from recorded CNSSI mappings; unmapped controls require separate assessment.",
            mappingSources: sources, exclusions: exclusions))
        return CNSSIPlan(generation: plan, conflictingVariants: Self.conflicts(plan.baseline.rules))
    }

    private static func conflicts(_ ids: [String]) -> [[String]] {
        let groups = Dictionary(grouping: ids) { id in
            id.replacingOccurrences(of: "(^|_)(high|moderate|low)(?=_|$)", with: "_", options: .regularExpression)
        }
        return groups.values.filter { $0.count > 1 }.map { $0.sorted() }.sorted { $0[0] < $1[0] }
    }
}

public enum ImpactLevel: String, Codable, Sendable, CaseIterable { case low, moderate, high }

public struct ImpactProfile: Sendable {
    public var confidentiality: ImpactLevel
    public var integrity: ImpactLevel
    public var availability: ImpactLevel
    public init(confidentiality: ImpactLevel, integrity: ImpactLevel, availability: ImpactLevel) {
        self.confidentiality = confidentiality; self.integrity = integrity; self.availability = availability
    }
    public static func uniform(_ level: ImpactLevel) -> ImpactProfile {
        ImpactProfile(confidentiality: level, integrity: level, availability: level)
    }
    public var name: String {
        if confidentiality == integrity, integrity == availability { return confidentiality.rawValue }
        return "c-\(confidentiality.rawValue)_i-\(integrity.rawValue)_a-\(availability.rawValue)"
    }
}

public struct CNSSIPlan: Sendable {
    public var generation: BaselineGenerationPlan
    public var conflictingVariants: [[String]]
    public func write(to destination: URL) throws {
        guard conflictingVariants.isEmpty else {
            throw BaselineWorkflowError.invalidRequest("Curate conflicting rule variants before writing: " + conflictingVariants.map { $0.joined(separator: ", ") }.joined(separator: "; "))
        }
        try generation.write(to: destination)
    }
}
