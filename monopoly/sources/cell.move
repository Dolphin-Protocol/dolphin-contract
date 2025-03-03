module monopoly::cell;
use std::string::{Self, String};
use std::type_name::{Self, TypeName};

use sui::bag::Bag;

use monopoly::action::{Self, Action};
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

// === View Functions ===

// === Admin Functions ===

// === Package Functions ===
public fun execute_buy<CoinType>(
    request: &mut ActionRequest,
    amount: u64,
    purchased_amount: u64
){
    assert!(request.action_request_action() == action::buyAction(), ENotBuyAction);

    let state = BuyState {
        type_name: type_name::get<CoinType>(),
        amount,
        purchased_amount,
    };

    request.action_request_add_state(action::buyAction(), state);
}

// public fun execute_pay<CoinType>(
    // request: &mut ActionRequest,
    // amount: u64,
    // purchased_amount: u64
// ){
//     todo!()
// }

// public fun execute_jail<CoinType>(
    // request: &mut ActionRequest,
    // amount: u64,
    // purchased_amount: u64
// ){
//     todo!()
// }

public fun settle(
    game: &mut Game,
    mut request: ActionRequest,
){
    let action = request.action_request_action();
    
    let buy_action = action::buyAction();
    let pay_action = action::payAction();
    let jail_action = action::jailAction();
    let chance_action = action::changeAction();

    match(action){
        buy_action => {
            let BuyState{
                type_name,
                amount,
                purchased_amount
            } = request.action_request_remove_state(buy_action);
        },
        pay_action => {
            let PayState{
                // type_name,
                // amount,
                // purchased_amount
            } = request.action_request_remove_state(pay_action);
        },
        jail_action => {
            let JailState{
                // type_name,
                // amount,
                // purchased_amount
            } = request.action_request_remove_state(jail_action);
        },
        chance_action => {
            let JailState{
                // type_name,
                // amount,
                // purchased_amount
            } = request.action_request_remove_state(jail_action);
        },
    };

    request.drop_action_request();
}

// === Private Functions ===

// === Test Functions ===
