import OrderedMap "mo:base/OrderedMap";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Debug "mo:base/Debug";
import Nat "mo:base/Nat";

actor {
    // ** Authorization **
    var adminPrincipal : ?Principal = null;

    // First principal that calls this function becomes admin, all other principals do not have admin permission
    public shared ({ caller }) func initializeAuth() : async () {
        if (Principal.isAnonymous(caller)) {
            Debug.trap("Anonymous principals cannot be admin");
        };

        switch (adminPrincipal) {
            case (?_) { () };
            case null {
                adminPrincipal := ?caller;
            };
        };
    };

    private func hasAdminPermission(caller : Principal) : Bool {
        switch (adminPrincipal) {
            case (?admin) { caller == admin };
            case null { false };
        };
    };

    public query ({ caller }) func isCurrentUserAdmin() : async Bool {
        hasAdminPermission(caller);
    };
    // ** END OF Authorization **

    // ** User profiles **
    type UserProfile = {
        name : Text;
        // other user's metadata if needed
    };

    transient let userProfilesMap = OrderedMap.Make<Principal>(Principal.compare);
    var userProfiles : OrderedMap.Map<Principal, UserProfile> = userProfilesMap.empty<UserProfile>();

    public query ({ caller }) func getUserProfile() : async ?UserProfile {
        userProfilesMap.get(userProfiles, caller);
    };

    public shared ({ caller }) func saveUserProfile(profile : UserProfile) : async () {
        userProfiles := userProfilesMap.put(userProfiles, caller, profile);
    };

    // ** END OF User profiles **

    // ** High scores **
    type HighScore = {
        moves : Nat;
        timestamp : Int;
    };

    transient let highScoresMap = OrderedMap.Make<Principal>(Principal.compare);
    var highScores : OrderedMap.Map<Principal, HighScore> = highScoresMap.empty<HighScore>();

    // Minimum moves for a valid game completion (8 pairs = 8 moves minimum)
    private let MIN_VALID_MOVES : Nat = 8;

    public shared ({ caller }) func saveHighScore(moves : Nat) : async () {
        // Validate the submitted score
        if (moves < MIN_VALID_MOVES) {
            Debug.trap("Invalid score: minimum moves required is " # Nat.toText(MIN_VALID_MOVES));
        };

        let newScore : HighScore = {
            moves = moves;
            timestamp = 0; // TODO: Set timestamp
        };

        switch (highScoresMap.get(highScores, caller)) {
            case (?existingScore) {
                if (moves < existingScore.moves) {
                    highScores := highScoresMap.put(highScores, caller, newScore);
                };
            };
            case null {
                highScores := highScoresMap.put(highScores, caller, newScore);
            };
        };
    };

    public query ({ caller }) func getMyHighScore() : async ?HighScore {
        highScoresMap.get(highScores, caller);
    };

    public query func getLeaderboard() : async [(Principal, HighScore)] {
        let entries = Iter.toArray(highScoresMap.entries(highScores));
        Array.sort<(Principal, HighScore)>(
            entries,
            func(a, b) {
                if (a.1.moves < b.1.moves) { #less } else if (a.1.moves > b.1.moves) {
                    #greater;
                } else { #equal };
            },
        );
    };
};
