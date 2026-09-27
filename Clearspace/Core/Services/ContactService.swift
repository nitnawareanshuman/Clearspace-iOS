import Contacts
import Foundation

struct ContactRecord: Identifiable {
    let contact: CNContact
    var id: String { contact.identifier }
    var name: String { CNContactFormatter.string(from: contact, style: .fullName) ?? "Unnamed contact" }
    var candidate: ContactCandidate {
        ContactCandidate(id: id, givenName: contact.givenName, familyName: contact.familyName,
            phones: contact.phoneNumbers.map { $0.value.stringValue }, emails: contact.emailAddresses.map { $0.value as String })
    }
}

struct ContactGroup: Identifiable {
    let records: [ContactRecord]
    var id: String { records.first?.id ?? "" }
}

struct ContactDraft: Identifiable {
    let id = UUID()
    let epoch: Int
    let records: [ContactRecord]
    let kept: [ContactRecord]
}

enum ContactError: LocalizedError {
    case stale, noAccess
    case mergeConflict(String)
    case differentAccounts
    var errorDescription: String? {
        switch self {
        case .stale: return "Contacts changed or the selection is no longer valid. Scan again and keep at least one contact in every group."
        case .noAccess: return "Contacts access is unavailable. Check access in Settings."
        case .differentAccounts: return "These cards belong to different contact accounts. Merge them in Contacts so account-specific details stay under your control."
        case .mergeConflict(let field): return "These cards have different \(field) details. Resolve the difference in Contacts before merging; nothing has been changed."
        }
    }
}

/// Contacts enumeration and writes are serialized away from the main actor.
actor ContactService {
    private let database = CNContactStore()
    // Do not request CNContactNoteKey: it requires a special entitlement.
    private let keys: [CNKeyDescriptor] = [
        CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
        CNContactIdentifierKey as CNKeyDescriptor, CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor, CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor, CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactJobTitleKey as CNKeyDescriptor, CNContactPostalAddressesKey as CNKeyDescriptor,
        CNContactUrlAddressesKey as CNKeyDescriptor, CNContactBirthdayKey as CNKeyDescriptor,
        CNContactMiddleNameKey as CNKeyDescriptor, CNContactNamePrefixKey as CNKeyDescriptor,
        CNContactNameSuffixKey as CNKeyDescriptor, CNContactNicknameKey as CNKeyDescriptor,
        CNContactPreviousFamilyNameKey as CNKeyDescriptor, CNContactDepartmentNameKey as CNKeyDescriptor,
        CNContactPhoneticGivenNameKey as CNKeyDescriptor, CNContactPhoneticMiddleNameKey as CNKeyDescriptor,
        CNContactPhoneticFamilyNameKey as CNKeyDescriptor, CNContactPhoneticOrganizationNameKey as CNKeyDescriptor,
        CNContactTypeKey as CNKeyDescriptor, CNContactNonGregorianBirthdayKey as CNKeyDescriptor,
        CNContactImageDataKey as CNKeyDescriptor, CNContactDatesKey as CNKeyDescriptor,
        CNContactRelationsKey as CNKeyDescriptor, CNContactSocialProfilesKey as CNKeyDescriptor,
        CNContactInstantMessageAddressesKey as CNKeyDescriptor
    ]

    static var hasAccess: Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if #available(iOS 18.0, *), status == .limited { return true }
        return status == .authorized
    }

    func requestAccess() async throws -> Bool { try await database.requestAccess(for: .contacts) }

    private func fetch(ids: [String]? = nil) throws -> [ContactRecord] {
        guard Self.hasAccess else { throw ContactError.noAccess }
        let request = CNContactFetchRequest(keysToFetch: keys)
        // Show individual records. Deleting a unified contact can affect multiple linked cards.
        request.unifyResults = false
        if let ids { request.predicate = CNContact.predicateForContacts(withIdentifiers: ids) }
        var records: [ContactRecord] = []
        try database.enumerateContacts(with: request) { contact, stop in
            if Task.isCancelled { stop.pointee = true; return }
            records.append(ContactRecord(contact: contact))
        }
        try Task.checkCancellation()
        return records
    }

    func scan() throws -> [ContactGroup] {
        let records = try fetch()
        let byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        return ContactPolicy.groups(records.map(\.candidate)).map { ids in
            ContactGroup(records: ids.compactMap { byID[$0] })
        }
    }

    func delete(_ draft: ContactDraft) throws {
        let expected = draft.records + draft.kept
        let current = try fetch(ids: expected.map(\.id))
        let byID = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        guard current.count == expected.count,
              expected.allSatisfy({ byID[$0.id]?.contact.isEqual($0.contact) == true }) else { throw ContactError.stale }
        let request = CNSaveRequest()
        for record in draft.records {
            guard let mutable = byID[record.id]?.contact.mutableCopy() as? CNMutableContact else { throw ContactError.stale }
            request.delete(mutable)
        }
        try commit(request)
    }

    func merge(_ draft: ContactMergeDraft) throws {
        let current = try fetch(ids: draft.records.map(\.id))
        let byID = Dictionary(uniqueKeysWithValues: current.map { ($0.id, $0) })
        guard current.count == draft.records.count,
              draft.records.allSatisfy({ byID[$0.id]?.contact.isEqual($0.contact) == true }) else { throw ContactError.stale }
        let containers = try current.map { record in
            try database.containers(matching: CNContainer.predicateForContainerOfContact(withIdentifier: record.id)).map(\.identifier)
        }
        guard let first = containers.first, first.count == 1,
              containers.allSatisfy({ $0 == first }) else { throw ContactError.differentAccounts }
        let combined = try ContactMerger.merged(current, keeping: draft.keeperID)
        let request = CNSaveRequest()
        request.update(combined)
        for record in current where record.id != draft.keeperID {
            guard let card = record.contact.mutableCopy() as? CNMutableContact else { throw ContactError.stale }
            request.delete(card)
        }
        // One save request contains the keeper update and removal of the source cards.
        try commit(request)
    }

    private func commit(_ request: CNSaveRequest) throws {
        try Task.checkCancellation()
        guard Self.hasAccess else { throw ContactError.noAccess }
        // All Contacts mutations go through this final-confirmation-only site.
        try database.execute(request)
    }
}


struct ContactMergeDraft: Identifiable {
    let id = UUID()
    let epoch: Int
    let records: [ContactRecord]
    let keeperID: String
}

/// Build exactly the card shown in the merge review. Never silently overwrite
/// conflicting single-value details; the user can resolve those in Contacts.
enum ContactMerger {
    static func merged(_ records: [ContactRecord], keeping keeperID: String) throws -> CNMutableContact {
        guard records.count > 1, Set(records.map(\.id)).count == records.count,
              let keeper = records.first(where: { $0.id == keeperID }),
              let result = keeper.contact.mutableCopy() as? CNMutableContact else { throw ContactError.stale }
        let strings: [(String, ReferenceWritableKeyPath<CNMutableContact, String>)] = [
            ("given name", \.givenName), ("middle name", \.middleName), ("family name", \.familyName),
            ("name prefix", \.namePrefix), ("name suffix", \.nameSuffix), ("nickname", \.nickname),
            ("previous family name", \.previousFamilyName), ("organization", \.organizationName),
            ("department", \.departmentName), ("job title", \.jobTitle),
            ("phonetic given name", \.phoneticGivenName), ("phonetic middle name", \.phoneticMiddleName),
            ("phonetic family name", \.phoneticFamilyName), ("phonetic organization", \.phoneticOrganizationName)
        ]
        for record in records where record.id != keeperID {
            guard let source = record.contact.mutableCopy() as? CNMutableContact else { throw ContactError.stale }
            guard source.contactType == result.contactType else { throw ContactError.mergeConflict("contact type") }
            for (label, path) in strings {
                let incoming = source[keyPath: path], existing = result[keyPath: path]
                if existing.isEmpty { result[keyPath: path] = incoming }
                else if !incoming.isEmpty && existing != incoming { throw ContactError.mergeConflict(label) }
            }
            if let birthday = source.birthday {
                if let existing = result.birthday, existing != birthday { throw ContactError.mergeConflict("birthday") }
                result.birthday = birthday
            }
            if let birthday = source.nonGregorianBirthday {
                if let existing = result.nonGregorianBirthday, existing != birthday { throw ContactError.mergeConflict("other-calendar birthday") }
                result.nonGregorianBirthday = birthday
            }
            if let photo = source.imageData {
                if let existing = result.imageData, existing != photo { throw ContactError.mergeConflict("contact photo") }
                result.imageData = photo
            }
            result.phoneNumbers = union(result.phoneNumbers, source.phoneNumbers)
            result.emailAddresses = union(result.emailAddresses, source.emailAddresses)
            result.postalAddresses = union(result.postalAddresses, source.postalAddresses)
            result.urlAddresses = union(result.urlAddresses, source.urlAddresses)
            result.dates = union(result.dates, source.dates)
            result.contactRelations = union(result.contactRelations, source.contactRelations)
            result.socialProfiles = union(result.socialProfiles, source.socialProfiles)
            result.instantMessageAddresses = union(result.instantMessageAddresses, source.instantMessageAddresses)
        }
        return result
    }

    private static func union<Value: NSObject & NSCopying & NSSecureCoding>(
        _ existing: [CNLabeledValue<Value>], _ incoming: [CNLabeledValue<Value>]
    ) -> [CNLabeledValue<Value>] {
        var combined = existing
        for entry in incoming where !combined.contains(where: { $0.label == entry.label && $0.value.isEqual(entry.value) }) {
            combined.append(CNLabeledValue(label: entry.label, value: entry.value))
        }
        return combined
    }
}
