import Foundation

/// Pure matching rules. Shared details suggest a review; they never imply safe deletion.
struct ContactCandidate: Identifiable {
    let id: String
    let givenName: String
    let familyName: String
    let phones: [String]
    let emails: [String]
}

enum ContactPolicy {
    static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func keys(_ contact: ContactCandidate) -> Set<String> {
        var keys = Set<String>()
        for phone in contact.phones {
            let digits = phone.filter(\.isNumber)
            // Avoid matching short extensions or missing values. No guessed country codes.
            if digits.count >= 7 { keys.insert("phone:" + digits) }
        }
        for email in contact.emails {
            let value = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !value.isEmpty { keys.insert("email:" + value) }
        }
        let given = normalized(contact.givenName), family = normalized(contact.familyName)
        if !given.isEmpty && !family.isEmpty { keys.insert("name:" + given + "|" + family) }
        return keys
    }

    static func groups(_ contacts: [ContactCandidate]) -> [[String]] {
        let contacts = contacts.sorted { $0.id < $1.id }
        var parent = Array(contacts.indices)
        func root(_ index: Int) -> Int {
            var current = index
            while parent[current] != current {
                parent[current] = parent[parent[current]]
                current = parent[current]
            }
            return current
        }
        var owners: [String: Int] = [:]
        for (index, contact) in contacts.enumerated() {
            for key in keys(contact) {
                if let previous = owners[key] {
                    let left = root(index), right = root(previous)
                    parent[left] = right
                }
                else { owners[key] = index }
            }
        }
        var groups: [Int: [String]] = [:]
        for index in contacts.indices { groups[root(index), default: []].append(contacts[index].id) }
        return groups.values.filter { $0.count > 1 }.sorted { $0[0] < $1[0] }
    }

    static func allows(_ selection: Set<String>, groups: [[String]]) -> Bool {
        let known = Set(groups.flatMap { $0 })
        return !selection.isEmpty && selection.isSubset(of: known)
            && groups.allSatisfy { group in group.contains { !selection.contains($0) } }
    }
}
