import Foundation
import ComplianceKitCore
import ComplianceKitPersistence

public enum CNSSICommandLine {
    public static func run(_ arguments: [String]) async throws {
        await CKLogger.shared.setDestinations([])
        guard let command = arguments.first, !["--help", "-h"].contains(command) else { print(help); return }
        let options = try Options(Array(arguments.dropFirst()))
        if options.help { print(help); return }
        guard ["generate", "mapping", "duplicates", "merge"].contains(command) else {
            throw BaselineWorkflowError.invalidRequest("Unknown command: \(command). Use --help. The organize step is now included in generation; historical scripts remain in scripts/.")
        }
        let repository = try options.url("--macos-security")
        if command == "merge" {
            let directory = try options.url("--overlays")
            try await applyOverlays(repository: repository, directory: directory, apply: options.apply)
            return
        }
        let aliases = ["sequoia": "15.0", "sonoma": "14.0", "tahoe": "26.0", "golden_gate": "27.0"]
        let versionText = options.values["--target-version"] ?? options.values["--branch-name"].flatMap { aliases[$0] }
        guard let versionText, let version = MacOSVersion.from(versionString: versionText) else {
            throw BaselineWorkflowError.invalidRequest("Specify --target-version, for example 27.0")
        }
        let exclusions: [String: String]
        if let path = options.values["--curation"] {
            exclusions = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        } else { exclusions = [:] }
        if command == "mapping" {
            let csv = try options.url("--csv")
            let plan = try await BaselineWorkflow().plan(BaselineGenerationRequest(
                repositoryURL: repository, targetVersion: version, baselineID: "custom_mapping_macos_\(version.major).\(version.minor)",
                framework: "cnssi-1253", title: "CNSSI custom mapping", description: "Single-objective mapping preview",
                mappingSources: [.init(id: csv.lastPathComponent, url: csv)], exclusions: exclusions))
            print("Selected \(plan.baseline.rules.count) rules; \(plan.coverage.unmatchedControls.count) unmatched controls")
            plan.baseline.rules.forEach { print($0) }
            if options.apply { try plan.write(to: options.url("--output")) }
            return
        }
        let cnssi = try options.url("--macos-security-cnssi")
        let data = options.values["--data"].map { URL(fileURLWithPath: $0) }
            ?? cnssi.appendingPathComponent("data/cnssi-1253_2022.12.22_csv")
        let levelText = options.values["--level"] ?? "high"
        let levels: [ImpactLevel]
        if levelText == "all" { levels = ImpactLevel.allCases }
        else if let level = ImpactLevel(rawValue: levelText) { levels = [level] }
        else { throw BaselineWorkflowError.invalidRequest("--level must be low, moderate, high or all") }
        var plans: [(CNSSIPlan, URL)] = []
        for level in levels {
            let plan = try await CNSSIWorkflow().plan(repositoryURL: repository, dataDirectory: data,
                targetVersion: version, profile: .uniform(level), exclusions: exclusions)
            let base = options.values["--output"].map { URL(fileURLWithPath: $0) }
                ?? cnssi.appendingPathComponent("builds/macos_\(version.major).\(version.minor)_cnssi-1253")
            let destination = base.appendingPathComponent("cnssi-1253_\(level.rawValue)")
            print("\(plan.generation.baseline.id): \(plan.generation.baseline.rules.count) rules, \(plan.generation.baseline.sections.count) sections")
            print("Unmatched controls (\(plan.generation.coverage.unmatchedControls.count)): \(plan.generation.coverage.unmatchedControls.joined(separator: ", "))")
            for group in plan.conflictingVariants { print("Curation required: " + group.joined(separator: ", ")) }
            print("Output: \(destination.path)")
            plans.append((plan, destination))
        }
        if options.apply, command != "duplicates" {
            // Preflight every level before writing any bundle.
            for (plan, destination) in plans {
                guard plan.conflictingVariants.isEmpty else {
                    throw BaselineWorkflowError.invalidRequest("Provide --curation decisions for the reported variants")
                }
                guard !FileManager.default.fileExists(atPath: destination.path) else {
                    throw BaselineWorkflowError.outputExists(destination.path)
                }
            }
            for (plan, destination) in plans {
                try plan.write(to: destination)
                let manifest = try BaselineWorkflow.json(plan.generation.manifest)
                let history = cnssi.appendingPathComponent(".compliancekit/history.store")
                try FileManager.default.createDirectory(at: history.deletingLastPathComponent(), withIntermediateDirectories: true)
                try await MainActor.run {
                    let store = try ComplianceStore(url: history)
                    try store.recordGeneration(baselineID: plan.generation.baseline.id, manifest: manifest)
                }
                print("Wrote validated bundle: \(destination.path)")
            }
        } else { print("Preview complete. Add --apply to write new bundles. Source mSCP rules remain unchanged.") }
    }

    public static func merge(_ arguments: [String]) async throws {
        await CKLogger.shared.setDestinations([])
        if arguments.isEmpty || arguments.contains("--help") {
            print("Usage: cnssi-merge <mscp-repository> <overlay-directory> [--apply]\nDefault: validate and preview changes.")
            return
        }
        guard arguments.count >= 2, arguments.count <= 3,
              arguments.count == 2 || arguments[2] == "--apply" else {
            throw BaselineWorkflowError.invalidRequest("Use cnssi-merge <mscp-repository> <overlay-directory> [--apply]")
        }
        try await applyOverlays(repository: URL(fileURLWithPath: arguments[0]),
            directory: URL(fileURLWithPath: arguments[1]), apply: arguments.contains("--apply"))
    }

    private static func applyOverlays(repository: URL, directory: URL, apply: Bool) async throws {
        let plan = try await OverlayWorkflow().plan(repositoryURL: repository, overlaysDirectory: directory)
        print("Validated \(plan.changes.count) changed rules")
        plan.changes.forEach { print($0.ruleID) }
        if apply { try plan.apply(); print("Applied overlays") }
        else { print("Preview only. Add --apply to update source rule files.") }
    }

    private struct Options {
        var values: [String: String] = [:]
        var apply = false
        var help = false
        init(_ arguments: [String]) throws {
            let known = Set(["--macos-security", "--macos-security-cnssi", "--target-version", "--branch-name", "--data", "--level", "--curation", "--output", "--csv", "--overlays"])
            var index = 0
            var dryRun = false
            while index < arguments.count {
                let argument = arguments[index]
                if argument == "--apply" { apply = true }
                else if argument == "--dry-run" { dryRun = true }
                else if ["--help", "-h"].contains(argument) { help = true }
                else {
                    guard known.contains(argument), index + 1 < arguments.count,
                          !arguments[index + 1].hasPrefix("--"), values[argument] == nil else {
                        throw BaselineWorkflowError.invalidRequest("Unknown, repeated or incomplete option: \(argument)")
                    }
                    index += 1; values[argument] = arguments[index]
                }
                index += 1
            }
            guard !(apply && dryRun) else { throw BaselineWorkflowError.invalidRequest("Choose --apply or --dry-run") }
        }
        func url(_ key: String) throws -> URL {
            guard let path = values[key], !path.isEmpty else { throw BaselineWorkflowError.invalidRequest("Missing \(key)") }
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }
    }

    private static let help = """
    CNSSI-1253 tools powered by ComplianceKit
    Usage: cnssi-baseline-generator <generate|mapping|duplicates|merge> [options]
      --macos-security <path>        mSCP input checkout
      --macos-security-cnssi <path>  CNSSI data and output repository
      --target-version <version>    Explicit target macOS version, such as 27.0
      --level <high|moderate|low|all> Impact level (default: high)
      --data <path>                 Mapping CSV directory (default: 2022.12.22 edition)
      --curation <path>             JSON object of excluded rule IDs and reasons
      --output <path>               Parent directory for new baseline bundles
      --csv <path>                  Single CSV input for mapping
      --overlays <path>             Overlay directory for merge
      --apply                       Write output; merge updates source rules
      --dry-run                     Preview (the default)
      --branch-name <name>           Legacy OS alias; does not switch Git branches
    Each bundle contains baselines/, rules/, coverage.json and manifest.json.
    Conflicting variants require explicit curation. Existing output is never overwritten.
    """
}
