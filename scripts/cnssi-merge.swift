#!/usr/bin/env swift
// =============================================================================
// cnssi-merge.swift
// Swift conversion of cnssi-merge.py
//
// Merges CNSSI-1253 baseline tags from custom CNSSI rule files into the
// corresponding mSCP project rule YAML files.
//
// Usage:
//   swift cnssi-merge.swift <pathToProject> <pathToCNSSICustoms>
//
//   pathToProject     – path to the macos_security project root
//                       (must contain a rules/ directory)
//   pathToCNSSICustoms – path to the macos_security_cnssi project root
//                        (contains builds like */rules/*/* )
//
// Example:
//   swift cnssi-merge.swift ~/repos/macos_security/ ~/repos/macos_security_cnssi/builds/
// =============================================================================

import Foundation

// MARK: - Helpers

/// Minimal YAML value extractor.
/// Returns the list items under a given top-level key, e.g. `tags:`.
func yamlListValues(forKey key: String, in content: String) -> [String] {
    let lines = content.components(separatedBy: .newlines)
    var capturing = false
    var values: [String] = []

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Start capturing when we hit the target key
        if trimmed == "\(key):" || trimmed.hasPrefix("\(key):") {
            // Inline value after the colon (single-value form)
            let afterColon = trimmed
                .dropFirst(key.count + 1)
                .trimmingCharacters(in: .whitespaces)
            if !afterColon.isEmpty && !afterColon.hasPrefix("[") {
                // Single scalar value (e.g.  tags: cnssi-1253_high)
                values.append(
                    afterColon.trimmingCharacters(
                        in: CharacterSet(charactersIn: "\"'"))
                )
                return values
            }
            // Inline list form:  tags: [a, b, c]
            if afterColon.hasPrefix("[") && afterColon.hasSuffix("]") {
                let inner = afterColon.dropFirst().dropLast()
                return inner.components(separatedBy: ",")
                    .map {
                        $0.trimmingCharacters(in: .whitespaces)
                          .trimmingCharacters(
                              in: CharacterSet(charactersIn: "\"'"))
                    }
                    .filter { !$0.isEmpty }
            }
            capturing = true
            continue
        }

        if capturing {
            if trimmed.hasPrefix("- ") {
                let val = String(trimmed.dropFirst(2))
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                if !val.isEmpty { values.append(val) }
            } else if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                // We've left the list block
                break
            }
        }
    }
    return values
}

/// Checks whether a top-level key exists in the YAML content.
func yamlHasKey(_ key: String, in content: String) -> Bool {
    let lines = content.components(separatedBy: .newlines)
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed == "\(key):" || trimmed.hasPrefix("\(key):") {
            // Make sure it's a real key, not a substring match inside a value
            if !line.hasPrefix(" ") && !line.hasPrefix("\t") {
                return true
            }
            // Accept indented keys too (the Python script checks the parsed dict)
            return true
        }
    }
    return false
}

/// Recursively finds all files matching a pattern like:
///   <basePath>/*/rules/*/*
/// This replicates `glob.glob(pathToCNSSICustoms + '/*/rules/*/*')`.
func globCNSSIRules(in basePath: String) -> [String] {
    let fm = FileManager.default
    var results: [String] = []

    // Level 1: basePath/*  (e.g. sequoia_cnssi1253)
    guard let level1 = try? fm.contentsOfDirectory(atPath: basePath) else {
        return results
    }

    for dir1 in level1 {
        let dir1Path = (basePath as NSString).appendingPathComponent(dir1)
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: dir1Path, isDirectory: &isDir),
              isDir.boolValue else { continue }

        // Level 2: must be "rules"
        let rulesPath = (dir1Path as NSString).appendingPathComponent("rules")
        guard fm.fileExists(atPath: rulesPath, isDirectory: &isDir),
              isDir.boolValue else { continue }

        // Level 3: rules/*  (section directories)
        guard let sections = try? fm.contentsOfDirectory(atPath: rulesPath) else {
            continue
        }
        for section in sections {
            let sectionPath = (rulesPath as NSString)
                                  .appendingPathComponent(section)
            guard fm.fileExists(atPath: sectionPath, isDirectory: &isDir),
                  isDir.boolValue else { continue }

            // Level 4: rules/section/*  (individual rule files)
            guard let files = try? fm.contentsOfDirectory(
                atPath: sectionPath) else { continue }
            for file in files {
                let filePath = (sectionPath as NSString)
                                   .appendingPathComponent(file)
                results.append(filePath)
            }
        }
    }
    return results
}

// MARK: - Main

guard CommandLine.arguments.count == 3 else {
    let prog = (CommandLine.arguments.first as NSString?)?.lastPathComponent
               ?? "cnssi-merge.swift"
    print("Usage: \(prog) <pathToProject> <pathToCNSSICustoms>")
    exit(1)
}

let pathToProject      = CommandLine.arguments[1]
let pathToCNSSICustoms = CommandLine.arguments[2]
let fm                 = FileManager.default

// Replicate:  glob.glob(pathToCNSSICustoms + '/*/rules/*/*')
let cnssiRuleFiles = globCNSSIRules(in: pathToCNSSICustoms)

for ruleCNSSI in cnssiRuleFiles {

    // Skip supplemental rules
    if ruleCNSSI.contains("supplemental") { continue }

    // Build the corresponding project rule path.
    // Python: Path(pathToProject + "rules" + ruleCNSSI.split("rules")[1])
    guard let rulesRange = ruleCNSSI.range(of: "rules") else {
        print("Skipping (no 'rules' in path): \(ruleCNSSI)")
        continue
    }
    let suffix = String(ruleCNSSI[rulesRange.lowerBound...])  // "rules/section/file.yaml"
    var projectRulePath = (pathToProject as NSString)
                              .appendingPathComponent(suffix)
    // Normalize double slashes
    while projectRulePath.contains("//") {
        projectRulePath = projectRulePath.replacingOccurrences(of: "//",
                                                               with: "/")
    }

    guard fm.fileExists(atPath: projectRulePath) else {
        print("File: \(projectRulePath) not found")
        continue
    }

    // ---- Read the CNSSI rule to get its tags ------------------------------
    guard let cnssiContent = try? String(contentsOfFile: ruleCNSSI,
                                         encoding: .utf8) else {
        print("Could not read CNSSI rule: \(ruleCNSSI)")
        continue
    }

    let tags = yamlListValues(forKey: "tags", in: cnssiContent)
    guard let firstTag = tags.first, !firstTag.isEmpty else {
        print("No tags found in: \(ruleCNSSI)")
        continue
    }

    print(projectRulePath)
    print(tags)

    // ---- Read the project rule --------------------------------------------
    guard var ruleContent = try? String(contentsOfFile: projectRulePath,
                                        encoding: .utf8) else {
        print("Could not read project rule: \(projectRulePath)")
        continue
    }

    // ---- Inject the CNSSI tag into the project rule -----------------------
    // Python logic:
    //   if 'severity' in rule_yaml:
    //       replace "\nseverity:" with "\n- <tag>\nseverity:"
    //   else:
    //       replace "\nmobileconfig:" with "\n- <tag>\nmobileconfig:"
    if yamlHasKey("severity", in: ruleContent) {
        let cnssiTag = "\n- \(firstTag)\nseverity:"
        print(cnssiTag)
        ruleContent = ruleContent.replacingOccurrences(of: "\nseverity:",
                                                       with: cnssiTag)
    } else {
        let cnssiTag = "\n- \(firstTag)\nmobileconfig:"
        print(cnssiTag)
        ruleContent = ruleContent.replacingOccurrences(of: "\nmobileconfig:",
                                                       with: cnssiTag)
    }

    // ---- Write back -------------------------------------------------------
    do {
        try ruleContent.write(toFile: projectRulePath,
                              atomically: true,
                              encoding: .utf8)
        print(ruleContent)
    } catch {
        print("Error writing \(projectRulePath): \(error)")
    }
}
