import Error "mo:base/Error";
import Hash "mo:base/Hash";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import T "dip721_types";
import Debug "mo:base/Debug";
import Time "mo:base/Time";

actor class DRC721(_name : Text, _symbol : Text, _tags: [Text]) {

    //Using DIP721 standard, adapted from https://github.com/SuddenlyHazel/DIP721/blob/main/src/DIP721/DIP721.mo
    private stable var tokenPk : Nat = 0;

    public type CollectionMetadata = {
        name: Text;
        logo: Text;
        symbol: Text;
        tags: [Text];
        custodians: [Principal];
        created_at: Nat64;
        upgraded_at: Nat64;
        max_items: Nat64;
    };

    public type Stats = {
        total_transactions: Nat;
        total_supply: Nat;
        cycles: Nat;
        total_unique_holders: Nat;
    };

    public type GenericValue = {
        #boolContent: Bool;
        #textContent: Text;
        #blobContent: [Nat8];
        #principal: Principal;
        #nat8Content: Nat8;
        #nat16Content: Nat16;
        #nat32Content: Nat32;
        #nat64Content: Nat64;
        #natContent: Nat;
        #int8Content: Int8;
        #int16Content: Int16;
        #int32Content: Int32;
        #int64Content: Int64;
        #intContent: Int;
        #floatContent: Float;
        #nestedContent: [(Text, GenericValue)];
    };
    
    public type TokenMetadata = {
        token_identifier: Nat;
        owner: ?Principal;
        operator_: ?Principal;
        is_burned: Bool;
        properties: [(Text, GenericValue)];
        minted_at: Int;
        minted_by: Principal;
        transferred_at: ?Int;
        transferred_by: ?Principal;
        approved_at: ?Nat64;
        approved_by: ?Principal;
        burned_at: ?Nat64;
        burned_by: ?Principal;
        collection: ?CollectionMetadata;
    };

    func toTokenMetadata(tid: Nat, _owner: Principal) : TokenMetadata{
        var gv: GenericValue =     #textContent "Testing Session";
        var output : TokenMetadata = {
            token_identifier = tid;
            owner = ?(_owner);
            operator_ = null;
            is_burned = false;
            properties = [("Purpose",gv)];
            minted_at = Time.now();
            minted_by = _owner;
            transferred_at = null;
            transferred_by = null;
            approved_at = null;
            approved_by = null;
            burned_at = null;
            burned_by = null;
            collection = null;
        };
        return output;
    };

    public type TxEvent = {
        time: Nat64;
        caller: Principal;
        operation: Text;
        details: [(Text, GenericValue)];
    };

    
    public type SupportedInterface = {
        #approval;
        #mint;
        #burn;
        #transactionHistory;
    };
    
    public type NftError = {
        #unauthorizedOwner;
        #unauthorizedOperator;
        #ownerNotFound;
        #operatorNotFound;
        #tokenNotFound;
        #existedNFT;
        #selfApprove;
        #selfTransfer;
        #txNotFound;
        #other;
    };

    

    private stable var tokenURIEntries : [(T.TokenId, Text)] = [];
    private stable var tokenMetadataEntries : [(Text, TokenMetadata)] = [];
    private stable var ownersEntries : [(T.TokenId, Principal)] = [];
    private stable var balancesEntries : [(Principal, Nat)] = [];
    private stable var tokenApprovalsEntries : [(T.TokenId, Principal)] = [];
    private stable var operatorApprovalsEntries : [(Principal, [Principal])] = [];
    private stable var activeAuctionEntries : [(T.TokenId, Nat)] = [];
    private stable var auctionApplicationEntries : [(Text, Nat)] = [];  

    private let tokenURIs : HashMap.HashMap<T.TokenId, Text> = HashMap.fromIter<T.TokenId, Text>(tokenURIEntries.vals(), 10, Nat.equal, Hash.hash);
    private let tokenMetadataHash : HashMap.HashMap<Text, TokenMetadata> = HashMap.fromIter<Text, TokenMetadata>(tokenMetadataEntries.vals(), 10, Text.equal, Text.hash);
    private let owners : HashMap.HashMap<T.TokenId, Principal> = HashMap.fromIter<T.TokenId, Principal>(ownersEntries.vals(), 10, Nat.equal, Hash.hash);
    private let balances : HashMap.HashMap<Principal, Nat> = HashMap.fromIter<Principal, Nat>(balancesEntries.vals(), 10, Principal.equal, Principal.hash);
    private let tokenApprovals : HashMap.HashMap<T.TokenId, Principal> = HashMap.fromIter<T.TokenId, Principal>(tokenApprovalsEntries.vals(), 10, Nat.equal, Hash.hash);
    private let operatorApprovals : HashMap.HashMap<Principal, [Principal]> = HashMap.fromIter<Principal, [Principal]>(operatorApprovalsEntries.vals(), 10, Principal.equal, Principal.hash);
    private let activeAuctions : HashMap.HashMap<T.TokenId, Nat> = HashMap.fromIter<T.TokenId, Nat>(activeAuctionEntries.vals(), 10, Nat.equal, Hash.hash);
    private let auctionApplications : HashMap.HashMap<Text, Nat> = HashMap.fromIter<Text, Nat>(auctionApplicationEntries.vals(), 10, Text.equal, Text.hash);
    
    
    func textToNat(t : Text) : ?Nat{
        let s = t.size();
        if (s == 0){
            return null;
        };
        var num : Nat = 0;
        var i = 0;
        for (c in t.chars()){
            if (c != '0' and c != '1' and c != '2' and c != '3' and c != '4' and c != '5' and c != '6' and c != '7' and c != '8' and c != '9'){
                return null;                
            }
            else {
                var dig : Nat = 0;
                switch (c) {
                    case '0' {
                        dig := 0;
                    };
                    case '1' {
                        dig := 1;
                    };
                    case '2' {
                        dig := 2;
                    };
                    case '3' {
                        dig := 3;
                    };
                    case '4' {
                        dig := 4;
                    };
                    case '5' {
                        dig := 5;
                    };
                    case '6' {
                        dig := 6;
                    };
                    case '7' {
                        dig := 7;
                    };
                    case '8' {
                        dig := 8;
                    };
                    case default {
                        dig := 9;
                    };
                };
                num := num + dig * (10**(s - i - 1));
            };
            i += 1;
        };
        return (?num);
    };
    
    public shared func balanceOf(p : Principal) : async ?Nat {
        return balances.get(p);
    };

    public shared func ownerOf(tokenId : T.TokenId) : async ?Principal {
        return _ownerOf(tokenId);
    };

    public shared query func tokenURI(tokenId : T.TokenId) : async ?Text {
        return _tokenURI(tokenId);
    };

    public shared query func name() : async Text {
        return _name;
    };

    public shared query func symbol() : async Text {
        return _symbol;
    };

    public shared query func tags() : async [Text] {
        return _tags;
    };

    public shared func isApprovedForAll(owner : Principal, opperator : Principal) : async Bool {
        return _isApprovedForAll(owner, opperator);
    };

    public shared(msg) func approve(to : Principal, tokenId : T.TokenId) : async () {
        switch(_ownerOf(tokenId)) {
            case (?owner) {
                 assert to != owner;
                 assert msg.caller == owner or _isApprovedForAll(owner, msg.caller);
                 _approve(to, tokenId);
            };
            case (null) {
                throw Error.reject("No owner for token")
            };
        }
    };

    public shared func getApproved(tokenId : Nat) : async Principal {
        switch(_getApproved(tokenId)) {
            case (?v) { return v };
            case null { throw Error.reject("None approved")}
        }
    };

    public shared(msg) func setApprovalForAll(op : Principal, isApproved : Bool) : () {
        assert msg.caller != op;

        switch (isApproved) {
            case true {
                switch (operatorApprovals.get(msg.caller)) {
                    case (?opList) {
                        var array = Array.filter<Principal>(opList,func (p) { p != op });
                        array := Array.append<Principal>(array, [op]);
                        operatorApprovals.put(msg.caller, array);
                    };
                    case null {
                        operatorApprovals.put(msg.caller, [op]);
                    };
                };
            };
            case false {
                switch (operatorApprovals.get(msg.caller)) {
                    case (?opList) {
                        let array = Array.filter<Principal>(opList, func(p) { p != op });
                        operatorApprovals.put(msg.caller, array);
                    };
                    case null {
                        operatorApprovals.put(msg.caller, []);
                    };
                };
            };
        };
        
    };

    public shared(msg) func transferFrom(from : Principal, to : Principal, tokenId : Nat) : () {
        Debug.print(debug_show 1111);
        assert _isApprovedOrOwner(msg.caller, tokenId);
        Debug.print(debug_show "hi");
        _transfer(from, to, tokenId);
    };

    // Mint without authentication
    public func mint_principal(uri : Text, meta : TokenMetadata, principal : Principal) : async Nat {
        tokenPk += 1;
        _mint(principal, tokenPk, uri, meta);
        return tokenPk;
    };

    // Mint requires authentication in the frontend as we are using caller.
     public shared ({caller}) func mint(uri : Text, meta : TokenMetadata) : async Nat {
        tokenPk += 1;
        _mint(caller, tokenPk, uri, meta);
        return tokenPk;
    };

    //Mint requires authentication in the frontend, but metadata is self created at runtime.
    public shared ({caller}) func mintFromParameters(uri: Text, tid: Nat) : async Nat{
        tokenPk += 1;
        let meta: TokenMetadata = toTokenMetadata(tid, caller);
        _mint(caller, tokenPk, uri, meta);
        return tokenPk;
    };

    //To hold an auction for owned NFT
    public shared ({caller}) func auctionStart(t : T.TokenId, minSale : Nat) : async Bool {
        let tokenOwner = owners.get(t);
        switch (tokenOwner) {
            case null {
                return false;
            };
            case (?principal) {
                if (principal != caller){
                    return false;
                } 
                else {
                    activeAuctions.put(t,minSale);
                    return true;
                };
            };
        };
    };

    //To participate in an auction for an NFT
    public shared({caller}) func auctionBid(t: T.TokenId, bid: Nat) : async Bool {
        let tokenOwner = owners.get(t);
        switch (tokenOwner) {
            case null {
                return false;
            };
            case default {
                var i = 0;
            };
        };
        let minBid = activeAuctions.get(t);
        switch (minBid) {
            case null {
                return false;
            };
            case (?nat) {
                if (nat > bid) {
                    return false;
                }
                else {
                    let bid_identifier : Text = Nat.toText(t) # "<<<>>>" # Principal.toText(caller);
                    auctionApplications.put(bid_identifier,bid);
                    return true;
                }; 
            };
        };
    };

    //To end an auction for owned NFT
    public shared({caller}) func auctionEnd(t : T.TokenId) : async Bool {
        let tokenOwner = owners.get(t);
        switch (tokenOwner) {
            case null {
                return false;
            };
            case (?principal) {
                if (principal != caller){
                    return false;
                } 
                else {
                    var winningBidder : Principal = Principal.fromText("");
                    var winningBid : Nat = 0;
                    for ((key,item) in auctionApplications.entries()){
                        let iter = Text.split(key,#text("<<<>>>"));
                        let iterArray = Iter.toArray<Text>(iter);
                        let tID  = textToNat(iterArray[0]);
                        var tid : Nat = 0;
                        switch (tID){
                            case null {
                                tid := 0;
                            };
                            case (?nat) {
                                tid := nat;
                            };
                        };
                        if (tid == t){
                            let bidder : Principal = Principal.fromText(iterArray[1]);
                            let bid = item;
                            if (bid > winningBid){
                                winningBid := bid;
                                winningBidder := bidder;
                            };
                        };
                        auctionApplications.delete(key);
                    };
                    activeAuctions.delete(t);
                    if (winningBid != 0){
                        _transfer(caller, winningBidder, t);
                        return true;
                    }
                    else {
                        return false;
                    };
                };
            };
        };
    };

    //Edit a dynamic NFT
    public shared ({caller}) func updateDNFT(tokenId: T.TokenId, uri: Text, meta: TokenMetadata): async Bool{
        let owner = owners.get(tokenId);
        switch (owner){
            case null {
                return false;
            };
            case (?principal){
                if (principal != caller){
                    return false;
                }
                else {
                    let newUri = tokenURIs.replace(tokenId, uri);
                    let newMeta = tokenMetadataHash.replace(uri,meta);
                    return true;
                };
            
            };
        };
    };

    // Internal

    private func _ownerOf(tokenId : T.TokenId) : ?Principal {
        return owners.get(tokenId);
    };

    private func _tokenURI(tokenId : T.TokenId) : ?Text {
        return tokenURIs.get(tokenId);
    };

    private func _tokenMetadata(uri: Text) : ?TokenMetadata {
        return tokenMetadataHash.get(uri);
    };

    private func _isApprovedForAll(owner : Principal, opperator : Principal) : Bool {
        switch (operatorApprovals.get(owner)) {
            case(?whiteList) {
                for (allow in whiteList.vals()) {
                    if (allow == opperator) {
                        return true;
                    };
                };
            };
            case null {return false;};
        };
        return false;
    };

    private func _approve(to : Principal, tokenId : Nat) : () {
        tokenApprovals.put(tokenId, to);
    };

    private func _removeApprove(tokenId : Nat) : () {
        let _ = tokenApprovals.remove(tokenId);
    };

    private func _exists(tokenId : Nat) : Bool {
        return Option.isSome(owners.get(tokenId));
    };

    private func _getApproved(tokenId : Nat) : ?Principal {
        assert _exists(tokenId) == true;
        switch(tokenApprovals.get(tokenId)) {
            case (?v) { return ?v };
            case null {
                return null;
            };
        }
    };

    private func _hasApprovedAndSame(tokenId : Nat, spender : Principal) : Bool {
        switch(_getApproved(tokenId)) {
            case (?v) {
                return v == spender;
            };
            case null { return false}
        }
    };

    private func _isApprovedOrOwner(spender : Principal, tokenId : Nat) : Bool {
        assert _exists(tokenId);
        let owner_ = _ownerOf(tokenId);
        var owner : Principal = Principal.fromText("2vxsx-fae");
        switch (owner_){
            case null {
                owner := Principal.fromText("2vxsx-fae");
                
            };
            case (?principal){
                owner := principal;
            };
            
        };
        
        return spender == owner or _hasApprovedAndSame(tokenId, spender) or _isApprovedForAll(owner, spender);
    };

    private func _transfer(from : Principal, to : Principal, tokenId : Nat) : () {
        assert _exists(tokenId);
        var owner = Principal.fromText("2vxsx-fae");
        switch (_ownerOf(tokenId)){
            case null {
                owner := Principal.fromText("2vxsx-fae");
            };
            case (?principal){
                owner := principal;
            };
        };
        assert owner == from;

        // Bug in HashMap https://github.com/dfinity/motoko-base/pull/253/files
        // this will throw unless you patch your file
        _removeApprove(tokenId);

        _decrementBalance(from);
        _incrementBalance(to);
        owners.put(tokenId, to);
    };

    private func _incrementBalance(address : Principal) {
        switch (balances.get(address)) {
            case (?v) {
                balances.put(address, v + 1);
            };
            case null {
                balances.put(address, 1);
            }
        }
    };

    private func _decrementBalance(address : Principal) {
        switch (balances.get(address)) {
            case (?v) {
                balances.put(address, v - 1);
            };
            case null {
                balances.put(address, 0);
            }
        }
    };

    private func _mint(to : Principal, tokenId : Nat, uri : Text, meta : TokenMetadata) : () {
        assert not _exists(tokenId);

        _incrementBalance(to);
        owners.put(tokenId, to);
        tokenURIs.put(tokenId,uri);
        tokenMetadataHash.put(uri,meta);
    };

    private func _burn(tokenId : Nat) {
        var owner = Principal.fromText("2vxsx-fae");
        switch (_ownerOf(tokenId)){
            case null {
                owner := Principal.fromText("2vxsx-fae");
            };
            case (?principal){
                owner := principal;
            };
        };
        assert Principal.toText(owner) != "2vxsx-fae";

        _removeApprove(tokenId);
        _decrementBalance(owner);

        ignore owners.remove(tokenId);
    };

    system func preupgrade() {
        tokenURIEntries := Iter.toArray(tokenURIs.entries());
        tokenMetadataEntries := Iter.toArray(tokenMetadataHash.entries());
        ownersEntries := Iter.toArray(owners.entries());
        balancesEntries := Iter.toArray(balances.entries());
        tokenApprovalsEntries := Iter.toArray(tokenApprovals.entries());
        operatorApprovalsEntries := Iter.toArray(operatorApprovals.entries());
        activeAuctionEntries := Iter.toArray(activeAuctions.entries());
        auctionApplicationEntries := Iter.toArray(auctionApplications.entries());
        
    };

    system func postupgrade() {
        tokenURIEntries := [];
        tokenMetadataEntries := [];
        ownersEntries := [];
        balancesEntries := [];
        tokenApprovalsEntries := [];
        operatorApprovalsEntries := [];
        auctionApplicationEntries := [];
        activeAuctionEntries := [];
    };
};
