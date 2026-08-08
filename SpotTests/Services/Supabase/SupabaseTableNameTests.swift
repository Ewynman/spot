import Foundation
import Testing
@testable import Spot

struct SupabaseTableNameTests {
    @Test
    func usersPublicViewName_isStable() {
        #expect(SupabaseTableName.usersPublic == "users_public")
        #expect(SupabaseTableName.users == "users")
    }
}
