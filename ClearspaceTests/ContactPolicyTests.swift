import XCTest
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
