module monopoly::house_cell;
// === Imports ===
use std::string::String;
use std::type_name::{ Self, TypeName };
use std::option::{Self};

use sui::event;
use sui::vec_map::{ Self, VecMap };
use sui::vec_set::{Self, VecSet};
use sui::transfer::Receiving;

use monopoly::monopoly::{ Game, ActionRequest, AdminCap };

// === Errors ===
const ENotBuyAction: u64 = 100;
const EUnMatchedCoinType: u64 = 101;
const EIncorrectPrice: u64 = 102;
const ENoParameterBody: u64 = 103;
const EPlayerNotHouseOwner: u64 = 104;
// === Constants ===
const VERSION: u64 = 1;
// === Structs ===

public struct HouseRegistry has key {
    id: UID,
    versions: VecSet<u64>,
    houses: VecMap<String,House>,
}

public struct House has store, copy{
    buy_prices: VecMap<u8, u64>,
    sell_prices: VecMap<u8, u64>,
    tolls: VecMap<u8, u64>,
}

public struct HouseCell has key, store {
    id: UID,
    owner: Option<address>,
    level: u8,
    name: String,
    house: House
}

// -- Arguments for settling response
public struct BuyArgument<phantom T> has copy, drop, store {
    type_name: TypeName,
    player_balance: u64,
    house_price: u64,
    amount: Option<u64>
}

public struct PayArgument has store {
    //TODO
}

public struct JailArgument has store {
    //TODO
}

public struct ChanceArgument has store {
    //TODO
}

// === Events ===
public struct BuyActionSettledEvent has copy, drop{
    game: ID,
    action_request: ID,
    player: address,
    pos_index: u64,
    type_name: TypeName,
    payment: u64,
    player_balance: u64,
    house_price: u64
}

// === Method Aliases === 

// === Init Function ===
fun init( ctx: &mut TxContext){
    let registry = HouseRegistry{
        id: object::new(ctx),
        versions: vec_set::singleton(VERSION),
        houses: vec_map::empty<String, House>(),
    };

    transfer::share_object(registry);
}

// === Public Functions ===
public fun buy_argument_info<T>(buy_argument: &BuyArgument<T>):(TypeName, u64, u64, Option<u64>) {
    (
        buy_argument.type_name,
        buy_argument.player_balance,
        buy_argument.house_price,
        buy_argument.amount,
    )
}

public fun buy_argument_type_name<T>(buy_argument: &BuyArgument<T>): TypeName{
    buy_argument.type_name
}
public fun buy_argument_player_balance<T>(buy_argument: &BuyArgument<T>): u64{
    buy_argument.player_balance
}
public fun buy_argument_house_price<T>(buy_argument: &BuyArgument<T>): u64{
    buy_argument.house_price
}
public fun buy_argument_amount<T>(buy_argument: &BuyArgument<T>): Option<u64>{
    buy_argument.amount
}

public fun house_cell_owner(house_cell: &HouseCell): Option<address>{
    house_cell.owner
}
public fun house_cell_house(house_cell: &HouseCell): &House{
    &house_cell.house
}

// === View Functions ===
// Get house info from house cell
public fun house(house_cell: &HouseCell): (VecMap<u8, u64>, VecMap<u8, u64>, VecMap<u8, u64>,) {
    (
        house_cell.house.buy_prices,
        house_cell.house.sell_prices,
        house_cell.house.tolls,
    )
}

// Get level from house cell
public fun level(
    self: &HouseCell,
): u8{
    self.level
}

// Get owner from house cell
public fun owner (
    self: &HouseCell,
):Option<address>{
    self.owner
}

// Get name from house cell
public fun name(
    self: &HouseCell,
): String{
    self.name
}

// === Admin Functions ===

// create a new house cell
public fun new_house_cell(
    registry: &HouseRegistry,
    name: String,
    ctx: &mut TxContext
):HouseCell{
    
    let house = registry.copy_house(name);

    HouseCell {
        id: object::new(ctx),
        owner: option::none(),
        name,
        level: 0,
        house,
    }
}

// add house to registry
public fun add_house_to_registry(
    registry: &mut HouseRegistry,
    _cap: &AdminCap,
    name: String,
    levels: vector<u8>,
    buy_prices: vector<u64>,
    sell_prices: vector<u64>,
    tolls: vector<u64>,
){
    let house = House {
        buy_prices: vec_map::from_keys_values(levels, buy_prices),
        sell_prices: vec_map::from_keys_values(levels, sell_prices),
        tolls: vec_map::from_keys_values(levels, tolls),
    };

    registry.houses.insert(name, house);
}

// update specific house in registry
public fun update_house_in_registry(
    registry: &mut HouseRegistry,
    _cap: &AdminCap,
    name: String,
    new_levels: vector<u8>,
    new_buy_prices: vector<u64>,
    new_sell_prices: vector<u64>,
    new_tolls: vector<u64>,
){
    // set house info field 
    let house = registry.houses.get_mut(&name);

    let new_buy_prices_map =  vec_map::from_keys_values(new_levels, new_buy_prices);
    let new_sell_prices_map =  vec_map::from_keys_values(new_levels, new_sell_prices);
    let new_tolls_map =  vec_map::from_keys_values(new_levels, new_tolls);
    
    house.buy_prices = new_buy_prices_map;
    house.sell_prices =new_sell_prices_map;
    house.tolls = new_tolls_map;
}

// remove house in registry
public fun remove_house_in_registry(
    registry: &mut HouseRegistry,
    _cap: &AdminCap,
    name: String,
){
    let (name, house) = registry.houses.remove(&name);
    let House{
        buy_prices: _,
        sell_prices: _,
        tolls: _,
    } = house;
}

// === Package Functions ===

// called after 'monopoly::request_player_move' to config the parameters
public fun initialize_buy_params<T>(
    action_request: &mut ActionRequest<BuyArgument<T>>,
    game: &Game
){
    // retrieve related dynamic object
    let house_cell:&HouseCell = game.borrow_cell_with_request(action_request);
    
    // retrieve house object
    let house = &house_cell.house;
    // price starts with level 1
    let house_price = house.buy_prices[&(house_cell.level)];

    // retrieve player balance
    assert!(game.balance_type_contains<T>(), EUnMatchedCoinType);
    let player_balance = game.player_balance<T>(action_request.action_request_player()).value();
    let type_name = type_name::get<T>();

    // TODO: this can be simplifed to only accept boolean value as the player only has either buy or do nothing 2 options, but we'll showcase how to customize more dynamic & complicated request body
    // request parameters
    let parameters = BuyArgument<T>{
        type_name,
        player_balance,
        house_price,
        amount: option::none(),
    };

    game.config_parameter(action_request, parameters);
}

public fun execute_buy<T>(
    // TODO: should we have immutable shared object to lookup the price?
    mut request: ActionRequest<BuyArgument<T>>,
    payment: Option<u64>
){
    // TODO: to be ignored as we use generic type to handle the constraint
    
    //TODO
    // How can we acquire House price?
    // through 1) immutable shared object or 2) ActionRequest

    // validate balance
    let type_name = type_name::get<T>();
    
    assert!(request.action_request_parameters().is_some(), ENoParameterBody);

    let parameters = request.action_request_parameters_mut().borrow_mut();

    assert!(parameters.type_name == type_name, EUnMatchedCoinType);

    // 1) skip the payment
    // 2) pay for the house
    assert!(payment.is_none() || (payment.is_some() && parameters.player_balance >= *payment.borrow()));

    // fill the required parameters
    parameters.amount = payment;

    // mark settled in action_request to promise the action is ready to be sent
    request.settle_action_request();

    // transfer action to game object
    request.finish_action();
}

/// executed by server to settle the game state
public fun settle_buy<T>(
    mut received_request: Receiving<ActionRequest<BuyArgument<T>>>,
    game: &mut Game,
    ctx: &mut TxContext
){
    let mut request = game.receive_action_request(received_request);

    let player = request.action_request_player();

    let BuyArgument<T>{
        type_name,
        player_balance: _,
        house_price: _,
        mut amount
    } = request.action_request_remove_parameters(game);

    assert!(type_name::get<T>() == type_name, EUnMatchedCoinType);
    
    let house_cell:&mut HouseCell = game.borrow_cell_mut_with_request(&mut request);
    // validate house ownersdhip
    if(house_cell.owner.is_none()){
        house_cell.owner.fill(player);
    }else{
        // this shuoldn't happen
        assert!(house_cell.owner.borrow() == player, EPlayerNotHouseOwner);
    };

    // retrieve house object
    let house = &mut house_cell.house;
    // price starts with level 1
    let price = house.buy_prices[&(house_cell.level)];

    // validate price
    if(amount.is_some()){
        let payment = amount.extract();
        assert!(payment == price, EIncorrectPrice);

        // update house state
        house_cell.level = house_cell.level + 1;

        // update player's balance
        let balance_manager = game.balance_mut<T>();
        let payment_value = balance_manager.sub_balance(request.action_request_player(), payment);
    }else{
        amount.destroy_none();
    };

    // consume ActionRequest and transfer new TurnCap to next player
    game.drop_action_request(request, ctx);
}

#[test_only]
public fun settle_buy_for_testing<T>(
    mut request: ActionRequest<BuyArgument<T>>,
    game: &mut Game,
    ctx: &mut TxContext
){
    let (game_id, player, pos_index) = request.action_request_info();

    let BuyArgument<T>{
        type_name,
        player_balance,
        house_price,
        mut amount
    } = request.action_request_remove_parameters(game);

    assert!(type_name::get<T>() == type_name, EUnMatchedCoinType);
    
    let house_cell:&mut HouseCell = game.borrow_cell_mut_with_request(&mut request);
    // validate house ownersdhip
    if(house_cell.owner.is_none()){
        house_cell.owner.fill(player);
    }else{
        // this shuoldn't happen
        assert!(house_cell.owner.borrow() == player, EPlayerNotHouseOwner);
    };

    // retrieve house object
    let house = &mut house_cell.house;
    // price starts with level 1
    let price = house.buy_prices[&(house_cell.level)];

    // validate price
    if(amount.is_some()){
        let payment = amount.extract();
        assert!(payment == price, EIncorrectPrice);

        // update house state
        house_cell.level = house_cell.level + 1;

        // update player's balance
        let balance_manager = game.balance_mut<T>();
        balance_manager.sub_balance(request.action_request_player(), payment);

        event::emit(
            BuyActionSettledEvent {
                game: game_id,
                action_request: object::id(&request),
                player,
                pos_index,
                type_name,
                payment,
                player_balance: game.player_balance<T>(player).value(),
                house_price,
            }
        );
    }else{
        amount.destroy_none();
    };

    // consume ActionRequest and transfer new TurnCap to next player
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
fun copy_house(
    self: &HouseRegistry,
    name: String,
): House{
    House{
        buy_prices: self.houses.get(&name).buy_prices,
        sell_prices: self.houses.get(&name).sell_prices,
        tolls: self.houses.get(&name).tolls,
    }
}
// === Test Functions ===
#[test_only]
public fun init_for_testing(
    ctx: &mut TxContext,
){
    init(ctx);
}
