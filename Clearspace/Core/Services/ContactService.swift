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
    var errorDescription: String? {
        switch self {
        case .stale: return "Contacts changed or the selection is no longer valid. Scan again and keep at least one contact in every group."
        case .noAccess: return "Contacts access is unavailable. Check access in Settings."
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
        CNContactUrlAddressesKey as CNKeyDescriptor, CNContactBirthdayKey as CNKeyDescriptor
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
        try Task.checkCancellation()
        // The only Contacts mutation site; invoked after the final destructive confirmation.
        try database.execute(request)
    }
}
