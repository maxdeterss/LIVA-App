import Testing
import Foundation
@testable import LIVA

struct NetworkReachabilityTests {

    @Test func connectivityErrorsAreRetryable() {
        for code: URLError.Code in [.notConnectedToInternet, .networkConnectionLost,
                                    .timedOut, .cannotConnectToHost, .cannotFindHost, .dataNotAllowed] {
            #expect(NetworkReachability.isConnectivityError(URLError(code)))
        }
    }

    @Test func serverErrorsAreNotConnectivity() {
        struct ServerError: LocalizedError { var errorDescription: String? { "duplicate key value" } }
        #expect(NetworkReachability.isConnectivityError(ServerError()) == false)
        // 4xx-style URLErrors that aren't connectivity should not be retried
        #expect(NetworkReachability.isConnectivityError(URLError(.badURL)) == false)
    }
}

struct PendingWriteCodingTests {
    /// The offline queue round-trips a row payload through JSON.
    @Test func payloadRoundTrips() throws {
        struct Row: Codable, Equatable { let user_id: String; let amount_ml: Int }
        let row = Row(user_id: "abc", amount_ml: 250)
        let data = try AppJSON.encoder.encode(row)
        let back = try AppJSON.decoder.decode(Row.self, from: data)
        #expect(back == row)
    }
}
