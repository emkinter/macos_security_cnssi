// =============================================================================
// mSCP CNSSI-1253 Baseline Generator — Swift Implementation
// =============================================================================
//
// Implements the full workflow described in the macos_security_cnssi README:
//
//   1. Parse CNSSI-1253 → 800-53r5 mapping CSV files
//   2. Scan mSCP rule YAML files and match them to 800-53r5 controls
//   3. Identify duplicate rules across confidentiality/integrity/availability
//   4. Merge per-objective baselines into combined cnssi-1253_{high,moderate,low}
//   5. Write merged baseline YAML files
//   6. Tag individual rule YAML files with cnssi-1253 baseline markers
//   7. Organize build output between the two repositories
//
// Prerequisites:
//   - Clone both repos into the same parent directory:
//       macos_security/          (https://github.com/usnistgov/macos_security)
//       macos_security_cnssi/    (https://github.com/emkinter/macos_security_cnssi)
//
// Usage:
//   swift cnssi-baseline-generator.swift <command> [options]
//   See --help for full details.
// =============================================================================

import Foundation

// MARK: - Models

/// A single row from a CNSSI-1253 mapping CSV: one CNSSI impact tag ↔ one 800-53r5 control.
struct ControlMapping: Hashable {
    let cnssiLevel: String   // e.g. "IH", "MH", "LH"
    let nistControl: String  // e.g. "AC-1", "AC-2(1)"
}

/// Security-impact level used by CNSSI-1253.
enum ImpactLevel: String, CaseIterable {
    case high, moderate, low
}

/// One of the three security objectives in CNSSI-1253.
enum SecurityObjective: String, CaseIterable {
    case confidentiality, integrity, availability
}

/// An mSCP rule parsed from a YAML file in the rules/ directory tree.
struct MSCPRule {
    let id: String
    let filePath: String
    let nistControls: Set<String>   // uppercased 800-53r5 identifiers
    let section: String             // parent directory name
    var baselineTags: [String]
}

/// A baseline: a named collection of rule IDs grouped by section.
struct Baseline {
    let name: String
    let level: ImpactLevel
    var rules: [String]                    // sorted rule IDs
    var sections: [String: [String]]       // section → sorted rule IDs
}

/// Errors surfaced by the tool.
enum MSCPError: Error, CustomStringConvertible {
    case directoryNotFound(String)
    case fileNotFound(String)
    case invalidConfiguration(String)
    case missingArgument(String)

    var description: String {
        switch self {
        case .directoryNotFound(let p): return "Directory not found: \(p)"
        case .fileNotFound(let p):      return "File not found: \(p)"
        case .invalidConfiguration(let m): return "Invalid configuration: \(m)"
        case .missingArgument(let m):   return "Missing argument: \(m)"
        }
    }
}

// MARK: - CSV Parser

struct CSVParser {

    /// Reads a two-column CSV (cnssi_level, 800-53r5_control) and returns the mappings.
    static func parse(at path: String) throws -> [ControlMapping] {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        var mappings: [ControlMapping] = []
        for (index, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            // Skip header row
            if index == 0 && line.lowercased().contains("800-53") { continue }

            let cols = line.components(separatedBy: ",")
            guard cols.count >= 2 else {
                print("  ⚠ Skipping malformed line \(index + 1): \(line)")
                continue
            }

            let level   = cols[0].trimmingCharacters(in: .whitespaces)
            let control = cols[1].trimmingCharacters(in: .whitespaces)
            guard !level.isEmpty, !control.isEmpty else { continue }

            mappings.append(ControlMapping(cnssiLevel: level,
                                           nistControl: control))
        }
        return mappings
    }
}

// MARK: - YAML Rule Scanner

struct RuleScanner {

    /// Walks the mSCP rules/ directory and returns every rule it can parse.
    static func scanRules(in rulesDirectory: String) throws -> [MSCPRule] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: rulesDirectory) else {
            throw MSCPError.directoryNotFound(rulesDirectory)
        }

        var rules: [MSCPRule] = []
        let sectionDirs = try fm.contentsOfDirectory(atPath: rulesDirectory)

        for section in sectionDirs {
            let sectionPath = (rulesDirectory as NSString).appendingPathComponent(section)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: sectionPath, isDirectory: &isDir),
                  isDir.boolValue else { continue }

            let files = try fm.contentsOfDirectory(atPath: sectionPath)
            for file in files where file.hasSuffix(".yaml") || file.hasSuffix(".yml") {
                let filePath = (sectionPath as NSString).appendingPathComponent(file)
                if let rule = try? parseRuleYAML(at: filePath, section: section) {
                    rules.append(rule)
                }
            }
        }
        print("  Found \(rules.count) rules across "
              + "\(Set(rules.map(\.section)).count) sections")
        return rules
    }

    /// Extracts the rule ID, 800-53r5 references, and existing tags from one YAML file.
    static func parseRuleYAML(at path: String,
                              section: String) throws -> MSCPRule {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        let lines  = content.components(separatedBy: .newlines)

        var ruleID = ((path as NSString).lastPathComponent as NSString)
                        .deletingPathExtension
        var nistControls: Set<String> = []
        var baselineTags: [String] = []
        var inNistSection = false
        var inTagsSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // ---- id field --------------------------------------------------
            if trimmed.hasPrefix("id:") {
                ruleID = trimmed
                    .replacingOccurrences(of: "id:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }

            // ---- section transitions ---------------------------------------
            if trimmed.hasPrefix("800-53r5:") || trimmed.hasPrefix("\"800-53r5\":") {
                inNistSection = true; inTagsSection = false; continue
            }
            if trimmed == "tags:" || trimmed.hasPrefix("tags:") {
                inTagsSection = true; inNistSection = false; continue
            }
            // A new top-level key ends the current subsection
            if !trimmed.hasPrefix("-") && !trimmed.hasPrefix("#") && !trimmed.isEmpty
               && !line.hasPrefix(" ") && !line.hasPrefix("\t") && trimmed.contains(":") {
                inNistSection = false; inTagsSection = false
            }

            // ---- collect list items ----------------------------------------
            if inNistSection && trimmed.hasPrefix("-") {
                let ctrl = trimmed.dropFirst()
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !ctrl.isEmpty { nistControls.insert(ctrl.uppercased()) }
            }
            if inTagsSection && trimmed.hasPrefix("-") {
                let tag = trimmed.dropFirst()
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !tag.isEmpty { baselineTags.append(tag) }
            }
        }

        return MSCPRule(id: ruleID,
                        filePath: path,
                        nistControls: nistControls,
                        section: section,
                        baselineTags: baselineTags)
    }
}

// MARK: - Mapping Generator (Step 1)

struct MappingGenerator {

    /// Reads one CSV, finds every mSCP rule that implements at least one of
    /// the listed 800-53r5 controls, and returns them as a Baseline.
    static func generateBaseline(from csvPath: String,
                                 rules: [MSCPRule],
                                 baselineName: String) throws -> Baseline {
        print("\n  Processing: \(baselineName)")
        print("  CSV file : \((csvPath as NSString).lastPathComponent)")

        let mappings        = try CSVParser.parse(at: csvPath)
        let requiredControls = Set(mappings.map { $0.nistControl.uppercased() })
        print("  Mappings : \(mappings.count)  |  "
              + "Unique 800-53r5 controls: \(requiredControls.count)")

        var matchedIDs       = Set<String>()
        var sections         = [String: [String]]()
        var unmatchedControls = requiredControls

        for rule in rules {
            let hits = rule.nistControls.intersection(requiredControls)
            guard !hits.isEmpty else { continue }
            matchedIDs.insert(rule.id)
            unmatchedControls.subtract(hits)
            sections[rule.section, default: []].append(rule.id)
        }

        // Determine impact level from the baseline name
        let level: ImpactLevel
        if      baselineName.contains("high")     { level = .high }
        else if baselineName.contains("moderate")  { level = .moderate }
        else                                       { level = .low }

        print("  Matched  : \(matchedIDs.count) rules")
        if !unmatchedControls.isEmpty {
            print("  ⚠ \(unmatchedControls.count) controls had no matching rules:")
            for c in unmatchedControls.sorted() { print("      \(c)") }
        }

        // Sort within each section
        for key in sections.keys { sections[key]?.sort() }

        return Baseline(name: baselineName,
                        level: level,
                        rules: matchedIDs.sorted(),
                        sections: sections)
    }
}

// MARK: - Duplicate Curator (Step 2)

struct DuplicateCurator {

    /// Returns rules that appear in more than one of the given baselines.
    static func findCrossBaselineDuplicates(
        in baselines: [Baseline]
    ) -> [String: [String]] {
        var map = [String: [String]]()
        for bl in baselines {
            for rule in bl.rules { map[rule, default: []].append(bl.name) }
        }
        return map.filter { $0.value.count > 1 }
    }

    /// Finds rules whose names contain "high", "moderate", or "low" that share
    /// a common base — a strong hint the user should curate them.
    static func findLevelKeywordDuplicates(
        rules: [String]
    ) -> [String: [String]] {
        let keywords = ["high", "moderate", "low"]
        var groups = [String: [String]]()
        for rule in rules {
            var base = rule
            for kw in keywords {
                base = base.replacingOccurrences(of: "_\(kw)", with: "")
                base = base.replacingOccurrences(of: "\(kw)_", with: "")
            }
            if base != rule { groups[base, default: []].append(rule) }
        }
        return groups.filter { $0.value.count > 1 }
    }
}

// MARK: - Baseline Merger (Step 4 — combines C + I + A into one per level)

struct BaselineMerger {

    /// Union of the three per-objective baselines at a given impact level.
    static func merge(confidentiality: Baseline,
                      integrity: Baseline,
                      availability: Baseline,
                      level: ImpactLevel) -> Baseline {
        let name = "cnssi-1253_\(level.rawValue)"

        var allRules = Set(confidentiality.rules)
        allRules.formUnion(integrity.rules)
        allRules.formUnion(availability.rules)

        var merged = [String: Set<String>]()
        for bl in [confidentiality, integrity, availability] {
            for (sec, ids) in bl.sections {
                merged[sec, default: []].formUnion(ids)
            }
        }
        let sortedSections = merged.mapValues { $0.sorted() }

        print("\n  Merged → \(name)")
        print("    Confidentiality : \(confidentiality.rules.count) rules")
        print("    Integrity       : \(integrity.rules.count) rules")
        print("    Availability    : \(availability.rules.count) rules")
        print("    Combined unique : \(allRules.count) rules")

        return Baseline(name: name,
                        level: level,
                        rules: allRules.sorted(),
                        sections: sortedSections)
    }
}

// MARK: - Baseline YAML Writer (Step 5)

struct BaselineWriter {

    /// Writes a baseline profile to a YAML file consumable by the mSCP tooling.
    static func write(_ baseline: Baseline, to path: String) throws {
        var yaml = """
        title: "CNSSI 1253 \(baseline.level.rawValue.capitalized)"
        description: |
          CNSSI 1253 \(baseline.level.rawValue.capitalized) \
        Confidentiality, Integrity, and Availability baseline.
          Generated by mSCP CNSSI-1253 Baseline Generator (Swift).

        profile:

        """

        for section in baseline.sections.keys.sorted() {
            guard let ids = baseline.sections[section], !ids.isEmpty else { continue }
            yaml += "  - section: \(section)\n"
            yaml += "    rules:\n"
            for id in ids.sorted() { yaml += "      - \(id)\n" }
        }

        try yaml.write(toFile: path, atomically: true, encoding: .utf8)
        print("  Written: \(path)")
    }
}

// MARK: - Rule Tagger — cnssi-merge equivalent (Step 6)

struct RuleTagger {

    /// Inserts (or replaces) cnssi-1253 baseline tags in every matched rule file.
    /// Returns the number of files updated.
    @discardableResult
    static func tagRules(mergedBaselines: [Baseline],
                         rulesDirectory: String,
                         dryRun: Bool = false) throws -> Int {
        // Build rule-ID → {baseline names} map
        var tagMap = [String: Set<String>]()
        for bl in mergedBaselines {
            for rule in bl.rules { tagMap[rule, default: []].insert(bl.name) }
        }
        print("\n  Tagging \(tagMap.count) rules with baseline information…")

        var updatedCount = 0
        let fm = FileManager.default

        for section in try fm.contentsOfDirectory(atPath: rulesDirectory) {
            let sectionPath = (rulesDirectory as NSString)
                                .appendingPathComponent(section)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: sectionPath, isDirectory: &isDir),
                  isDir.boolValue else { continue }

            for file in try fm.contentsOfDirectory(atPath: sectionPath)
                where file.hasSuffix(".yaml") || file.hasSuffix(".yml") {

                let ruleID  = (file as NSString).deletingPathExtension
                guard let tags = tagMap[ruleID] else { continue }

                let filePath = (sectionPath as NSString)
                                    .appendingPathComponent(file)
                if dryRun {
                    print("  [DRY RUN] Would tag \(ruleID): "
                          + "\(tags.sorted().joined(separator: ", "))")
                } else {
                    try rewriteTags(in: filePath, newCnssiTags: tags.sorted())
                }
                updatedCount += 1
            }
        }
        return updatedCount
    }

    // ---- private helpers ---------------------------------------------------

    /// Removes any existing cnssi-1253 tags from a rule file, then appends the
    /// new ones inside the `tags:` block.
    private static func rewriteTags(in path: String,
                                    newCnssiTags: [String]) throws {
        var lines = try String(contentsOfFile: path, encoding: .utf8)
                          .components(separatedBy: "\n")

        // 1. Locate the tags: section
        var tagsLineIdx: Int?
        var inTags = false
        var indicesToRemove = IndexSet()

        for (i, raw) in lines.enumerated() {
            let t = raw.trimmingCharacters(in: .whitespaces)
            if t == "tags:" || t.hasPrefix("tags:") {
                tagsLineIdx = i; inTags = true; continue
            }
            if inTags {
                if t.hasPrefix("-") {
                    let tag = t.dropFirst()
                        .trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    if tag.hasPrefix("cnssi-1253") {
                        indicesToRemove.insert(i)
                    }
                } else if !t.isEmpty && !t.hasPrefix("#") {
                    inTags = false
                }
            }
        }

        // 2. Strip old cnssi tags (iterate in reverse so indices stay valid)
        for i in indicesToRemove.sorted().reversed() { lines.remove(at: i) }

        // 3. Insert new tags right after the last existing tag in the block
        if let start = tagsLineIdx {
            var insertAt = start + 1
            while insertAt < lines.count {
                let t = lines[insertAt].trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("-") { insertAt += 1 } else { break }
            }
            for tag in newCnssiTags.reversed() {
                lines.insert("    - \(tag)", at: insertAt)
            }
        } else {
            // No tags: block yet — create one at the end of the file
            lines.append("tags:")
            for tag in newCnssiTags { lines.append("    - \(tag)") }
        }

        try lines.joined(separator: "\n")
                 .write(toFile: path, atomically: true, encoding: .utf8)
    }
}

// MARK: - Build Organizer (Step 3)

struct BuildOrganizer {

    /// Copies cnssi-1253_{high,moderate,low} from macos_security/build/
    /// into macos_security_cnssi/builds/<osName>_cnssi-1253/rules/.
    static func organize(from macosSecurityPath: String,
                         to cnssiPath: String,
                         osName: String) throws {
        let fm = FileManager.default
        let srcBuild = (macosSecurityPath as NSString)
                            .appendingPathComponent("build")
        let dstRules = (cnssiPath as NSString)
                            .appendingPathComponent("builds/\(osName)_cnssi-1253/rules")

        if !fm.fileExists(atPath: dstRules) {
            try fm.createDirectory(atPath: dstRules,
                                   withIntermediateDirectories: true)
            print("  Created: \(dstRules)")
        }

        for level in ImpactLevel.allCases {
            let folder = "cnssi-1253_\(level.rawValue)"
            let src = (srcBuild as NSString).appendingPathComponent(folder)
            let dst = (dstRules as NSString).appendingPathComponent(folder)

            guard fm.fileExists(atPath: src) else {
                print("  ⚠ Source not found, skipping: \(src)"); continue
            }
            if fm.fileExists(atPath: dst) { try fm.removeItem(atPath: dst) }
            try fm.copyItem(atPath: src, toPath: dst)
            print("  Copied: \(folder) → \(dst)")
        }
    }
}

// MARK: - Orchestrator

struct CNSSIBaselineGenerator {
    let macosSecurityPath: String
    let cnssiPath: String

    var csvDataDir: String {
        (cnssiPath as NSString)
            .appendingPathComponent("data/cnssi-1253_2022.12.22_csv")
    }
    var rulesDir: String {
        (macosSecurityPath as NSString).appendingPathComponent("rules")
    }

    /// Runs the full six-step workflow from the README.
    func run(osName: String, dryRun: Bool = false) throws {
        printBanner()
        try validatePaths()

        // ------ Step 1: Scan rules -----------------------------------------
        print("\n══ Step 1: Scanning mSCP Rules ══")
        let rules = try RuleScanner.scanRules(in: rulesDir)

        // ------ Step 2: Generate per-objective baselines from the 9 CSVs ----
        print("\n══ Step 2: Generating Mappings from CSV Files ══")
        var store = [String: Baseline]()   // "objective_level" → Baseline
        for obj in SecurityObjective.allCases {
            for lvl in ImpactLevel.allCases {
                let csv  = "cnssi-1253_\(obj.rawValue)_\(lvl.rawValue).csv"
                let path = (csvDataDir as NSString).appendingPathComponent(csv)
                let key  = "\(obj.rawValue)_\(lvl.rawValue)"
                let name = "cnssi-1253_\(key)"

                guard FileManager.default.fileExists(atPath: path) else {
                    print("  ⚠ CSV not found: \(path)"); continue
                }
                store[key] = try MappingGenerator.generateBaseline(
                    from: path, rules: rules, baselineName: name)
            }
        }

        // ------ Step 3: Identify duplicates --------------------------------
        print("\n══ Step 3: Identifying Duplicate Rules ══")
        for lvl in ImpactLevel.allCases {
            let group = SecurityObjective.allCases.compactMap {
                store["\($0.rawValue)_\(lvl.rawValue)"]
            }
            let crossDupes = DuplicateCurator.findCrossBaselineDuplicates(in: group)
            if !crossDupes.isEmpty {
                print("\n  Cross-objective duplicates (\(lvl.rawValue)):")
                for (rule, srcs) in crossDupes.sorted(by: { $0.key < $1.key }) {
                    print("    \(rule)  ← \(srcs.joined(separator: ", "))")
                }
            }
            let kwDupes = DuplicateCurator.findLevelKeywordDuplicates(
                rules: group.flatMap(\.rules))
            if !kwDupes.isEmpty {
                print("\n  Level-keyword duplicates to curate (\(lvl.rawValue)):")
                for (base, variants) in kwDupes.sorted(by: { $0.key < $1.key }) {
                    print("    \(base): \(variants.joined(separator: ", "))")
                }
            }
        }

        // ------ Step 4: Merge C + I + A into combined baselines ------------
        print("\n══ Step 4: Merging Baselines ══")
        var merged = [Baseline]()
        for lvl in ImpactLevel.allCases {
            guard let c = store["confidentiality_\(lvl.rawValue)"],
                  let i = store["integrity_\(lvl.rawValue)"],
                  let a = store["availability_\(lvl.rawValue)"] else {
                print("  ⚠ Incomplete data for \(lvl.rawValue), skipping merge")
                continue
            }
            merged.append(BaselineMerger.merge(
                confidentiality: c, integrity: i, availability: a, level: lvl))
        }

        // ------ Step 5: Write baseline YAML files --------------------------
        print("\n══ Step 5: Writing Baseline Files ══")
        let buildDir = (cnssiPath as NSString)
                           .appendingPathComponent("builds/\(osName)_cnssi-1253")
        let baselinesDir = (buildDir as NSString)
                               .appendingPathComponent("baselines")
        try FileManager.default.createDirectory(
            atPath: baselinesDir, withIntermediateDirectories: true)

        for bl in merged {
            let out = (baselinesDir as NSString)
                          .appendingPathComponent("\(bl.name).yaml")
            if dryRun {
                print("  [DRY RUN] Would write \(out)  (\(bl.rules.count) rules)")
            } else {
                try BaselineWriter.write(bl, to: out)
            }
        }

        // ------ Step 6: Tag rule files (cnssi-merge) -----------------------
        print("\n══ Step 6: Tagging Rules (cnssi-merge) ══")
        let count = try RuleTagger.tagRules(mergedBaselines: merged,
                                            rulesDirectory: rulesDir,
                                            dryRun: dryRun)
        print("  Updated \(count) rule files")

        printSummary(merged, osName: osName)
    }

    // ---- helpers -----------------------------------------------------------

    private func validatePaths() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: macosSecurityPath) else {
            throw MSCPError.directoryNotFound(
                "macos_security: \(macosSecurityPath)")
        }
        guard fm.fileExists(atPath: cnssiPath) else {
            throw MSCPError.directoryNotFound(
                "macos_security_cnssi: \(cnssiPath)")
        }
        guard fm.fileExists(atPath: rulesDir) else {
            throw MSCPError.directoryNotFound("rules: \(rulesDir)")
        }
        guard fm.fileExists(atPath: csvDataDir) else {
            throw MSCPError.directoryNotFound("CSV data: \(csvDataDir)")
        }
        print("  Paths validated ✓")
        print("    macos_security      : \(macosSecurityPath)")
        print("    macos_security_cnssi: \(cnssiPath)")
        print("    rules               : \(rulesDir)")
        print("    CSV data            : \(csvDataDir)")
    }

    private func printBanner() {
        print("""
        ╔══════════════════════════════════════════════════════════════╗
        ║   mSCP CNSSI-1253 Baseline Generator  (Swift Edition)      ║
        ╚══════════════════════════════════════════════════════════════╝
        """)
    }

    private func printSummary(_ baselines: [Baseline], osName: String) {
        print("""
        \n╔══════════════════════════════════════════════════════════════╗
        ║                         Summary                            ║
        ╠══════════════════════════════════════════════════════════════╣
        """)
        for bl in baselines {
            let n = bl.name.padding(toLength: 22, withPad: " ", startingAt: 0)
            print("  ║  \(n)  │  \(bl.rules.count) rules  "
                  + "│  \(bl.sections.count) sections")
        }
        let os = osName.padding(toLength: 52, withPad: " ", startingAt: 0)
        print("""
        ╠══════════════════════════════════════════════════════════════╣
        ║  OS: \(os)  ║
        ╚══════════════════════════════════════════════════════════════╝
        """)
    }
}

// MARK: - CLI

func printUsage() {
    let prog = (CommandLine.arguments.first ?? "cnssi-baseline-generator")
    print("""
    Usage: \(prog) <command> [options]

    Commands:
      generate     Full workflow (steps 1–6)
      mapping      Generate mapping from a single CSV file
      merge        Re-run the cnssi-merge tagging step only
      duplicates   Report duplicate rules across baselines
      organize     Copy build folders between repos

    Options:
      --macos-security <path>        Path to the macos_security clone
      --macos-security-cnssi <path>  Path to the macos_security_cnssi clone
      --os-name <name>               Target OS  (e.g. sequoia, sonoma)
      --csv <path>                   Single CSV for the 'mapping' command
      --dry-run                      Preview without writing any files
      --help                         Show this message

    Examples:

      # Full baseline generation
      swift \(prog) generate \\
        --macos-security ~/repos/macos_security \\
        --macos-security-cnssi ~/repos/macos_security_cnssi \\
        --os-name sequoia

      # Single CSV mapping
      swift \(prog) mapping \\
        --macos-security ~/repos/macos_security \\
        --csv ~/repos/macos_security_cnssi/data/cnssi-1253_2022.12.22_csv/cnssi-1253_confidentiality_high.csv

      # Dry run
      swift \(prog) generate \\
        --macos-security ~/repos/macos_security \\
        --macos-security-cnssi ~/repos/macos_security_cnssi \\
        --os-name sequoia --dry-run
    """)
}

func parseArgs() -> (cmd: String, opts: [String: String], flags: Set<String>) {
    let args = CommandLine.arguments
    guard args.count > 1 else { return ("", [:], []) }

    let cmd = args[1]
    var opts  = [String: String]()
    var flags = Set<String>()
    var i = 2
    while i < args.count {
        let a = args[i]
        if a == "--dry-run" || a == "--help" {
            flags.insert(a)
        } else if a.hasPrefix("--"), i + 1 < args.count {
            opts[a] = args[i + 1]; i += 1
        }
        i += 1
    }
    return (cmd, opts, flags)
}

// MARK: - Entry Point

let (cmd, opts, flags) = parseArgs()

if flags.contains("--help") || cmd.isEmpty { printUsage(); exit(0) }

do {
    switch cmd {

    // ── Full workflow ───────────────────────────────────────────────────
    case "generate":
        guard let ms   = opts["--macos-security"],
              let cn   = opts["--macos-security-cnssi"],
              let os   = opts["--os-name"] else {
            print("Error: 'generate' needs --macos-security, "
                  + "--macos-security-cnssi, and --os-name")
            printUsage(); exit(1)
        }
        let gen = CNSSIBaselineGenerator(macosSecurityPath: ms,
                                         cnssiPath: cn)
        try gen.run(osName: os, dryRun: flags.contains("--dry-run"))

    // ── Single CSV mapping ─────────────────────────────────────────────
    case "mapping":
        guard let ms  = opts["--macos-security"],
              let csv = opts["--csv"] else {
            print("Error: 'mapping' needs --macos-security and --csv")
            printUsage(); exit(1)
        }
        let rulesDir = (ms as NSString).appendingPathComponent("rules")
        let rules    = try RuleScanner.scanRules(in: rulesDir)
        let bl = try MappingGenerator.generateBaseline(
            from: csv, rules: rules,
            baselineName: (csv as NSString).lastPathComponent)
        print("\nMatched rules (\(bl.rules.count)):")
        bl.rules.forEach { print("  - \($0)") }

    // ── Re-tag only (cnssi-merge) ──────────────────────────────────────
    case "merge":
        guard let ms = opts["--macos-security"],
              let cn = opts["--macos-security-cnssi"],
              let os = opts["--os-name"] else {
            print("Error: 'merge' needs --macos-security, "
                  + "--macos-security-cnssi, and --os-name")
            exit(1)
        }
        let buildDir     = (cn as NSString)
                              .appendingPathComponent("builds/\(os)_cnssi-1253")
        let baselinesDir = (buildDir as NSString)
                              .appendingPathComponent("baselines")
        let rulesDir     = (ms as NSString).appendingPathComponent("rules")
        var baselines = [Baseline]()

        for lvl in ImpactLevel.allCases {
            let p = (baselinesDir as NSString)
                        .appendingPathComponent("cnssi-1253_\(lvl.rawValue).yaml")
            guard FileManager.default.fileExists(atPath: p) else { continue }
            let content = try String(contentsOfFile: p, encoding: .utf8)
            let ids = content.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix("- ") }
                .compactMap { line -> String? in
                    let v = String(line.dropFirst(2))
                                .trimmingCharacters(in: .whitespaces)
                    return v.isEmpty || v.contains(":") ? nil : v
                }
            baselines.append(Baseline(name: "cnssi-1253_\(lvl.rawValue)",
                                      level: lvl, rules: ids, sections: [:]))
        }

        let n = try RuleTagger.tagRules(mergedBaselines: baselines,
                                        rulesDirectory: rulesDir,
                                        dryRun: flags.contains("--dry-run"))
        print("Tagged \(n) rule files")

    // ── Duplicate report ───────────────────────────────────────────────
    case "duplicates":
        guard let ms = opts["--macos-security"],
              let cn = opts["--macos-security-cnssi"] else {
            print("Error: 'duplicates' needs --macos-security "
                  + "and --macos-security-cnssi")
            exit(1)
        }
        let rulesDir = (ms as NSString).appendingPathComponent("rules")
        let csvDir   = (cn as NSString)
            .appendingPathComponent("data/cnssi-1253_2022.12.22_csv")
        let rules = try RuleScanner.scanRules(in: rulesDir)

        for lvl in ImpactLevel.allCases {
            var group = [Baseline]()
            for obj in SecurityObjective.allCases {
                let csv = (csvDir as NSString).appendingPathComponent(
                    "cnssi-1253_\(obj.rawValue)_\(lvl.rawValue).csv")
                guard FileManager.default.fileExists(atPath: csv) else { continue }
                group.append(try MappingGenerator.generateBaseline(
                    from: csv, rules: rules,
                    baselineName: "cnssi-1253_\(obj.rawValue)_\(lvl.rawValue)"))
            }
            let d = DuplicateCurator.findCrossBaselineDuplicates(in: group)
            print("\n\(lvl.rawValue.uppercased()) duplicates: \(d.count)")
            for (r, s) in d.sorted(by: { $0.key < $1.key }) {
                print("  \(r) ← \(s.joined(separator: ", "))")
            }
        }

    // ── Move build folders ─────────────────────────────────────────────
    case "organize":
        guard let ms = opts["--macos-security"],
              let cn = opts["--macos-security-cnssi"],
              let os = opts["--os-name"] else {
            print("Error: 'organize' needs --macos-security, "
                  + "--macos-security-cnssi, and --os-name")
            exit(1)
        }
        try BuildOrganizer.organize(from: ms, to: cn, osName: os)

    default:
        print("Unknown command: \(cmd)"); printUsage(); exit(1)
    }

    print("\nDone ✓")

} catch {
    print("\nError: \(error)")
    exit(1)
}
