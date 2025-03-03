module monopoly::cell;
use std::string::{Self, String};
use std::type_name::{Self, TypeName};

use sui::bag::Bag;

use monopoly::monopoly::{ Game, ActionRequest };

const ENotBuyAction: u64 = 100;

public struct House has store{
    name: String
}


public struct Cell has key, store{
    id: UID,
    house: Option<House>
}

// ths shall be immutable shared object
public struct CellReigstry has key, store{
    id: UID,
    states: Bag
}

// -- State
public struct BuyState has store{
    type_name: TypeName,
    amount: u64,
    purchased_amount: u64
}

public struct PayState has store{

}

public struct JailState has store{

}

// === Imports ===

// === Errors ===

// === Constants ===

// === Structs ===

// === Events ===

// === Method Aliases ===

// === Public Functions ===
public fun keys():vector<vector<u8>>{
    vector[b"buy", b"pay", b"jail"]
}
// === View Functions ===

// === Admin Functions ===

// === Package Functions ===
public fun execute_buy<CoinType>(
    request: &mut ActionRequest,
    amount: u64,
    purchased_amount: u64
){
    let key = string::utf8(keys()[0]);
    assert!(request.action_request_action() == key, ENotBuyAction);

    let state = BuyState {
        type_name: type_name::get<CoinType>(),
        amount,
        purchased_amount,
    };

    request.action_request_add_state(key, state);
}

public fun execute_pay<CoinType>(
    // request: &mut ActionRequest,
    // amount: u64,
    // purchased_amount: u64
){
    todo!()
}

public fun execute_jail<CoinType>(
    // request: &mut ActionRequest,
    // amount: u64,
    // purchased_amount: u64
){
    todo!()
}

public fun settle(
    game: &mut Game,
    request: ActionRequest,
){
    let action = request.action_request_action();
    
    let keys = keys();
    // todo: refactor
    let buy_key = string::utf8(keys[0]);
    let pay_key = string::utf8(keys[1]);
    let jail_key = string::utf8(keys[2]);

    // execute respective acitons by state
    if(action == buy_key){
        // buy action
        let BuyState{
            type_name,
            amount,
            purchased_amount
        } = request.action_request_remove_state(buy_key);
    }else if(action == pay_key){
        let PayState{
            // type_name,
            // amount,
            // purchased_amount
        } = request.action_request_remove_state(pay_key);
    }else{
        let JailState{
            // type_name,
            // amount,
            // purchased_amount
        } = request.action_request_remove_state(jail_key);
    };
}

// === Private Functions ===

// === Test Functions ===
