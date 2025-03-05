module monopoly::cell;
use std::string::{ Self, String };
use std::type_name::{ Self, TypeName };

use sui::vec_map::{ Self, VecMap };
use sui::transfer::Receiving;

use monopoly::action::{ Self, Action };
use monopoly::monopoly::{ Game, ActionRequest, AdminCap };

const ENotBuyAction: u64 = 100;
const ENotMatchedCoinType: u64 = 101;
const EIncorrectPrice: u64 = 102;

public struct House has store, copy{
    name: String,
    level: u8,
    prices: VecMap<u8, u64>
}

public struct HouseCell has key, store {
    id: UID,
    house: House
}

// Shared object to store all kinds of cell type
public struct CellRegistry has key{
    id: UID,
    // mapping name to house object
    houses: VecMap<String, House>
}

// -- Arguments for settling response
public struct BuyArgument<phantom T> has store {
    type_name: TypeName,
    amount: u64
}

public struct PayArgument has store {

}

public struct JailArgument has store {

}

public struct ChanceArgument has store {

}

// === Imports ===

// === Errors ===

// === Constants ===

// === Structs ===

// === Events ===

// === Method Aliases ===

// === Public Functions ===

// === View Functions ===
public fun house_info(house_cell: &HouseCell): (String, u8, VecMap<u8, u64>) {
    (
        house_cell.house.name,
        house_cell.house.level,
        house_cell.house.prices,
    )
}

// === Admin Functions ===

public fun new_house_cell(
    name: String,
    levels: vector<u8>,
    prices_: vector<u64>,
    ctx: &mut TxContext
):HouseCell{
    let house = House {
        name,
        level: 0,
        prices: vec_map::from_keys_values(levels, prices_),
    };
    HouseCell {
        id: object::new(ctx),
        house
    }
}

public fun add_house_to_registry(
    cell_registry: &mut CellRegistry,
    _cap: &AdminCap,
    name: String,
    levels: vector<u8>,
    prices: vector<u64>
){
    let house = House {
        name,
        level: 0,
        prices: vec_map::from_keys_values(levels, prices),
    };
    cell_registry.houses.insert(name, house);
}

// === Package Functions ===
public fun execute_buy<T>(
    // TODO: should we have immutable shared object to lookup the price?
    mut request: ActionRequest,
    payment: u64
){
    assert!(request.action_request_action() == action::buyAction(), ENotBuyAction);

    let arg = BuyArgument<T> {
        type_name: type_name::get<T>(),
        amount: payment,
    };

    request.action_request_add_state(action::buyAction(), arg);

    // mark settled in action_request
    request.settle_action_request();

    // transfer action to game object
    request.finish_action();
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

/// executed by server to settle the game state
public fun settle_buy<T>(
    game: &mut Game,
    received_request: Receiving<ActionRequest>,
    ctx: &mut TxContext
){
    let mut request = game.receive_action_request(received_request);
    let (player, pos_index, action) = request.action_request_info();
    assert!(request.action_request_action()== action::buyAction(), ENotBuyAction);

    let BuyArgument<T>{
        type_name,
        amount
    } = request.action_request_remove_state(action);

    assert!(type_name::get<T>() == type_name, ENotMatchedCoinType);
    
    let house_cell = game.borrow_cell_mut_with_request<HouseCell>(&mut request);
    
    // retrieve house object
    let house = &mut house_cell.house;
    let price = house.prices[&(house.level + 1)];

    // validate price
    assert!(amount == price, EIncorrectPrice);

    // update house state
    house.level = house.level + 1;

    // update player's balance
    let payment = game.player_asset_mut_with_request<T>(&request).split(amount);
    game.deposit_fund(payment);

    // consume ActionRequest and transfer new TurnCap
    game.drop_action_request(request, ctx);
}

// public fun settle(
//     game: &mut Game,
//     mut request: ActionRequest,
// ){
//     let action = request.action_request_action();
//     
//     let buy_action = action::buyAction();
//     let pay_action = action::payAction();
//     let jail_action = action::jailAction();
//     let chance_action = action::changeAction();
//
//     match(action){
//         buy_action => {
//             let BuyArgument{
//                 type_name,
//                 amount,
//             } = request.action_request_remove_state(buy_action);
//         },
//         pay_action => {
//             let PayArgument{
//                 // type_name,
//                 // amount,
//                 // purchased_amount
//             } = request.action_request_remove_state(pay_action);
//         },
//         jail_action => {
//             let JailArgument{
//                 // type_name,
//                 // amount,
//                 // purchased_amount
//             } = request.action_request_remove_state(jail_action);
//         },
//         chance_action => {
//             let ChanceArgument{
//                 // type_name,
//                 // amount,
//                 // purchased_amount
//             } = request.action_request_remove_state(jail_action);
//         },
//     };
//
//     request.drop_action_request();
// }

// === Private Functions ===

// === Test Functions ===
