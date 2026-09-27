import XCTest
import Contacts
@testable import Clearspace

final class ContactPolicyTests: XCTestCase {
    private func contact(_ id: String, given: String = "", family: String = "", phone: String = "", email: String = "") -> ContactCandidate {
        ContactCandidate(id: id, givenName: given, familyName: family, phones: [phone], emails: [email])
    }
    func testEmptyContactsAndShortExtensionsDoNotMatch() {
        XCTAssertTrue(ContactPolicy.groups([contact("a"), contact("b"), contact("c", phone: "123"), contact("d", phone: "123")]).isEmpty)
    }
    func testPhoneFormattingAndEmailCaseAreNormalized() {
        let groups = ContactPolicy.groups([
            contact("a", phone: "+91 98765-43210"), contact("b", phone: "919876543210"),
            contact("c", email: " Person@Example.com "), contact("d", email: "person@example.com")
        ])
        XCTAssertEqual(groups, [["a", "b"], ["c", "d"]])
    }
    func testNoCountryCodeIsGuessed() {
        XCTAssertTrue(ContactPolicy.groups([contact("a", phone: "+91 9876543210"), contact("b", phone: "9876543210")]).isEmpty)
    }
    func testFullNameMatchesButSingleNamesDoNot() {
        XCTAssertEqual(ContactPolicy.groups([contact("a", given: " José ", family: " Silva"), contact("b", given: "jose", family: "silva")]), [["a", "b"]])
        XCTAssertTrue(ContactPolicy.groups([contact("a", given: "Alex"), contact("b", given: "Alex")]).isEmpty)
    }
    func testOverlappingMatchesProduceOneReviewGroup() {
        let records = [contact("c", email: "shared@example.com"),
            contact("b", phone: "1234567890", email: "shared@example.com"), contact("a", phone: "1234567890")]
        XCTAssertEqual(ContactPolicy.groups(records), [["a", "b", "c"]])
    }
    func testCannotDeleteWholeGroupOrUnknownRecords() {
        let groups = [["a", "b"], ["c", "d"]]
        XCTAssertFalse(ContactPolicy.allows([], groups: groups))
        XCTAssertFalse(ContactPolicy.allows(["a", "b"], groups: groups))
        XCTAssertFalse(ContactPolicy.allows(["a", "unknown"], groups: groups))
        XCTAssertTrue(ContactPolicy.allows(["a", "c"], groups: groups))
    }
}


final class ContactMergeTests: XCTestCase {
    private func card(email: String? = nil) -> CNMutableContact {
        let contact = CNMutableContact()
        contact.givenName = "Clearspace"
        contact.familyName = "Test"
        contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "2025550101"))]
        if let email { contact.emailAddresses = [CNLabeledValue(label: CNLabelHome, value: email as NSString)] }
        return contact
    }
    func testMergeKeepsIdentifierAndCombinesDetailsWithoutMutatingOriginals() throws {
        let a = card(), b = card(email: "test@example.com")
        let merged = try ContactMerger.merged([ContactRecord(contact: a), ContactRecord(contact: b)], keeping: a.identifier)
        XCTAssertEqual(merged.identifier, a.identifier)
        XCTAssertEqual(merged.phoneNumbers.count, 1)
        XCTAssertEqual(merged.emailAddresses.map { $0.value as String }, ["test@example.com"])
        XCTAssertTrue(a.emailAddresses.isEmpty)
        XCTAssertEqual(b.emailAddresses.count, 1)
    }
    func testCanKeepEitherOriginalCard() throws {
        let a = card(), b = card(email: "test@example.com")
        let merged = try ContactMerger.merged([ContactRecord(contact: a), ContactRecord(contact: b)], keeping: b.identifier)
        XCTAssertEqual(merged.identifier, b.identifier)
        XCTAssertEqual(merged.emailAddresses.count, 1)
    }
    func testConflictingSingleValueDetailsBlockMerge() {
        let a = card(), b = card()
        a.organizationName = "One"
        b.organizationName = "Two"
        XCTAssertThrowsError(try ContactMerger.merged([ContactRecord(contact: a), ContactRecord(contact: b)], keeping: a.identifier))
        XCTAssertEqual(a.organizationName, "One")
        XCTAssertEqual(b.organizationName, "Two")
    }
    func testPostalDetailsAndBirthdayArePreserved() throws {
        let a = card(), b = card()
        let address = CNMutablePostalAddress()
        address.street = "123 Test Street"
        b.postalAddresses = [CNLabeledValue(label: CNLabelHome, value: address)]
        b.birthday = DateComponents(year: 2000, month: 1, day: 2)
        let merged = try ContactMerger.merged([ContactRecord(contact: a), ContactRecord(contact: b)], keeping: a.identifier)
        XCTAssertEqual(merged.postalAddresses.first?.value.street, address.street)
        XCTAssertEqual(merged.birthday, b.birthday)
    }
    func testMissingKeeperOrRepeatedRecordCannotMerge() {
        let a = card(), b = card()
        XCTAssertThrowsError(try ContactMerger.merged([ContactRecord(contact: a), ContactRecord(contact: b)], keeping: "missing"))
        XCTAssertThrowsError(try ContactMerger.merged([ContactRecord(contact: a), ContactRecord(contact: a)], keeping: a.identifier))
    }
}
